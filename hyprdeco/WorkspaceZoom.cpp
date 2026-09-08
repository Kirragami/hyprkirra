#include "WorkspaceZoom.hpp"
#include "globals.hpp"

#include <algorithm>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RendererHintsPassElement.hpp>
#include <hyprland/src/render/types.hpp>
#include <hyprland/src/state/WorkspaceState.hpp>

using namespace Render;

namespace WorkspaceZoom {
    static bool           g_enabled  = true;
    static float          g_minScale = 0.55f;
    // Braces finish this far through the window zoom (0.5 = twice as fast).
    static constexpr float g_braceFrac = 0.5f;
    static CFunctionHook* g_hook     = nullptr;
    static bool           g_inHook   = false;
    static CHyprSignalListener g_tick;
    static CHyprSignalListener g_reloaded;

    static void pullConfig(bool commenced) {
        auto fl = [&](const SP<Config::Values::CFloatValue>& v, float fallback) {
            if (!v)
                return fallback;
            return commenced ? static_cast<float>(v->value()) : static_cast<float>(v->defaultVal());
        };
        auto bl = [&](const SP<Config::Values::CBoolValue>& v, bool fallback) {
            if (!v)
                return fallback;
            return commenced ? v->value() : v->defaultVal();
        };

        g_enabled  = bl(vars.wsZoom, true);
        g_minScale = std::clamp(fl(vars.wsZoomScale, 0.55f), 0.25f, 1.f);
    }

    static float ease(float t) {
        t = std::clamp(t, 0.f, 1.f);
        return t * t * (3.f - 2.f * t);
    }

    static float zoomT(PHLWORKSPACE ws) {
        if (!g_enabled || !ws || !ws->m_alpha)
            return 1.f;
        if (ws->m_renderOffset && ws->m_renderOffset->isBeingAnimated())
            return 1.f;
        if (!ws->m_alpha->isBeingAnimated())
            return 1.f;

        const float p = std::clamp(ws->m_alpha->getPercent(), 0.f, 1.f);
        if (ws->m_alpha->goal() >= 0.5f)
            return p;
        return 1.f - p;
    }

    bool inbound(PHLWORKSPACE ws) {
        if (!g_enabled || !ws || !ws->m_alpha || !ws->m_alpha->isBeingAnimated())
            return false;
        if (ws->m_renderOffset && ws->m_renderOffset->isBeingAnimated())
            return false;
        return ws->m_alpha->goal() >= 0.5f;
    }

    static float scaleFromT(float t) {
        return g_minScale + (1.f - g_minScale) * ease(t);
    }

    float scaleFor(PHLWORKSPACE ws) {
        return scaleFromT(zoomT(ws));
    }

    float braceScaleFor(PHLWORKSPACE ws) {
        const float t = zoomT(ws);
        if (t >= 0.999f)
            return 1.f;
        return scaleFromT(std::min(1.f, t / g_braceFrac));
    }

    CBox scaledBox(CBox box, float s, PHLMONITOR mon) {
        if (s >= 0.999f || !mon)
            return box;

        const Vector2D c = mon->m_position + mon->m_size * 0.5;
        box.x            = c.x + (box.x - c.x) * s;
        box.y            = c.y + (box.y - c.y) * s;
        box.w *= s;
        box.h *= s;
        return box;
    }

    static void pushScale(PHLMONITOR mon, float s) {
        if (!g_pHyprRenderer || s >= 0.999f || !mon)
            return;

        SRenderModifData mod;
        const Vector2D   c = mon->m_position + mon->m_size * 0.5;
        mod.modifs.emplace_back(SRenderModifData::RMOD_TYPE_TRANSLATE, -c);
        mod.modifs.emplace_back(SRenderModifData::RMOD_TYPE_SCALE, s);
        mod.modifs.emplace_back(SRenderModifData::RMOD_TYPE_TRANSLATE, c);
        g_pHyprRenderer->addPassElement(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{mod}));
    }

    static void popScale(float s) {
        if (!g_pHyprRenderer || s >= 0.999f)
            return;
        g_pHyprRenderer->addPassElement(makeUnique<CRendererHintsPassElement>(CRendererHintsPassElement::SData{SRenderModifData{}}));
    }

    static void hkRenderWindow(void* thisptr, PHLWINDOW pWindow, PHLMONITOR pMonitor, const Time::steady_tp& time, bool decorate, eRenderPassMode mode, bool ignorePosition,
                               bool standalone) {
        using orig_fn = void (*)(void*, PHLWINDOW, PHLMONITOR, const Time::steady_tp&, bool, eRenderPassMode, bool, bool);
        auto orig     = (orig_fn)g_hook->m_original;

        if (g_inHook || standalone || ignorePosition || !pWindow) {
            orig(thisptr, pWindow, pMonitor, time, decorate, mode, ignorePosition, standalone);
            return;
        }

        const float s = scaleFor(pWindow->m_workspace);
        g_inHook      = true;
        pushScale(pMonitor, s);
        orig(thisptr, pWindow, pMonitor, time, decorate, mode, ignorePosition, standalone);
        popScale(s);
        g_inHook = false;
    }

    void init() {
        pullConfig(false);

        g_reloaded = Event::bus()->m_events.config.reloaded.listen([] { pullConfig(true); });
        g_tick     = Event::bus()->m_events.tick.listen([] {
            if (!g_enabled || !g_pHyprRenderer)
                return;
            for (auto const& wsref : State::workspaceState()->workspaces()) {
                const auto ws = wsref.lock();
                if (scaleFor(ws) >= 0.999f)
                    continue;
                auto mon = ws->m_monitor.lock();
                if (mon)
                    g_pHyprRenderer->damageMonitor(mon);
            }
        });

        auto fns = HyprlandAPI::findFunctionsByName(PHANDLE, "renderWindow");
        void* addr = nullptr;
        for (auto const& f : fns) {
            if (f.demangled.find("IHyprRenderer") != std::string::npos && f.demangled.find("renderWindow") != std::string::npos) {
                addr = f.address;
                break;
            }
        }
        if (!addr && !fns.empty())
            addr = fns[0].address;

        if (!addr) {
            HyprlandAPI::addNotification(PHANDLE, "[kirracorners] could not hook renderWindow — workspace zoom disabled", CHyprColor{1.0, 0.4, 0.2, 1.0}, 4000);
            return;
        }

        g_hook = HyprlandAPI::createFunctionHook(PHANDLE, addr, (void*)&hkRenderWindow);
        if (!g_hook || !g_hook->hook()) {
            HyprlandAPI::addNotification(PHANDLE, "[kirracorners] workspace zoom hook failed", CHyprColor{1.0, 0.4, 0.2, 1.0}, 4000);
            g_hook = nullptr;
        }
    }

    void exit() {
        g_tick.reset();
        g_reloaded.reset();
        if (g_hook) {
            g_hook->unhook();
            g_hook = nullptr;
        }
    }
}
