#include "FocusTrail.hpp"
#include "HudLs.hpp"
#include "WorkspaceZoom.hpp"
#include "globals.hpp"

#include <algorithm>
#include <chrono>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/SharedDefs.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>

using namespace Desktop::View;
using Clock = std::chrono::steady_clock;

namespace FocusTrail {
    static PHLWINDOWREF         g_window;
    static CBox                 g_damaged;
    static Vector2D             g_pos, g_size, g_fromPos, g_fromSize, g_toPos, g_toSize;
    static float                g_t       = 1.f;
    static bool                 g_ready   = false;
    static bool                 g_enabled = true;
    static bool                 g_animate = true;
    static float                g_jumpSec = 0.28f;
    static SHudStyle            g_style;
    static Clock::time_point    g_lastTick = Clock::now();

    static CHyprSignalListener  g_render;
    static CHyprSignalListener  g_tick;
    static CHyprSignalListener  g_reloaded;

    static CBox windowBox(PHLWINDOW w, IGeometric::eGeometricValueType type) {
        if (!w)
            return {};

        CBox box = w->geometricBox(type);
        box.translate(w->m_floatingOffset);
        if (w->m_workspace && !w->m_pinned && w->m_workspace->m_renderOffset)
            box.translate(w->m_workspace->m_renderOffset->value());
        return box;
    }

    static bool shouldShow(PHLWINDOW w) {
        if (!validMapped(w) || w->isHidden())
            return false;
        if (w->m_X11DoesntWantBorders)
            return false;
        if (w->m_ruleApplicator && !w->m_ruleApplicator->decorate().valueOrDefault())
            return false;
        if (Fullscreen::controller() && Fullscreen::controller()->isFullscreen(w, Fullscreen::FSMODE_FULLSCREEN))
            return false;
        if (!w->m_pinned) {
            const auto ws = w->m_workspace;
            if (!ws || !ws->isVisible())
                return false;
        }
        return true;
    }

    static void damageLs(CBox win) {
        if (!g_pHyprRenderer || win.w < 1 || win.h < 1)
            return;
        win.expand(g_style.arm + 8.f);
        g_pHyprRenderer->damageBox(win);
    }

    static void damageCurrent() {
        CBox now{g_pos, g_size};
        damageLs(g_damaged);
        damageLs(now);
        g_damaged = now;
    }

    static void hide() {
        if (!g_ready && !g_window.lock())
            return;
        damageLs(g_damaged);
        damageLs({g_pos, g_size});
        g_window.reset();
        g_ready    = false;
        g_t        = 1.f;
        g_pos      = {};
        g_size     = {};
        g_fromPos  = {};
        g_fromSize = {};
        g_toPos    = {};
        g_toSize   = {};
        g_damaged  = {};
    }

    static Vector2D mix(const Vector2D& a, const Vector2D& b, float t) {
        return a + (b - a) * t;
    }

    static float ease(float t) {
        t = std::clamp(t, 0.f, 1.f);
        return t * t * (3.f - 2.f * t);
    }

    static bool followWsZoom(PHLWINDOW w) {
        return w && !w->m_pinned && WorkspaceZoom::inbound(w->m_workspace);
    }

    static void pinToZoomingWindow(PHLWINDOW w) {
        const CBox dest = windowBox(w, IGeometric::GEOMETRIC_GOAL);
        const CBox box  = WorkspaceZoom::scaledBox(dest, WorkspaceZoom::braceScaleFor(w->m_workspace), w->m_monitor.lock());
        g_pos           = box.pos();
        g_size          = box.size();
        g_toPos         = dest.pos();
        g_toSize        = dest.size();
        g_fromPos       = g_pos;
        g_fromSize      = g_size;
        g_t             = 1.f;
        g_ready         = true;
        damageCurrent();
    }

    static void pullConfig(bool commenced) {
        auto fl = [&](const SP<Config::Values::CFloatValue>& v, float fallback) {
            if (!v)
                return fallback;
            return commenced ? v->value() : v->defaultVal();
        };
        auto bl = [&](const SP<Config::Values::CBoolValue>& v, bool fallback) {
            if (!v)
                return fallback;
            return commenced ? v->value() : v->defaultVal();
        };
        auto cl = [&](const SP<Config::Values::CColorValue>& v, uint32_t fallback) {
            if (!v)
                return fallback;
            return commenced ? static_cast<uint32_t>(v->value()) : static_cast<uint32_t>(v->defaultVal());
        };

        g_style.arm        = fl(vars.arm, 14.f);
        g_style.thick      = fl(vars.thick, 1.15f);
        g_style.inset      = fl(vars.inset, 3.5f);
        g_style.lineAlpha  = fl(vars.lineAlpha, 0.82f);
        g_style.innerAlpha = fl(vars.innerAlpha, 0.7f);
        g_style.colLine    = cl(vars.colLine, 0xffff7a18);
        g_style.colDim     = cl(vars.colDim, 0xffff7a18);
        g_enabled          = bl(vars.enabled, true);
        g_animate          = bl(vars.animate, true);
        g_jumpSec          = std::clamp(fl(vars.jumpSec, 0.28f), 0.05f, 2.f);
        if (!g_enabled)
            g_ready = false;
    }

    void onFocus(PHLWINDOW window) {
        const auto last = g_window.lock();
        if (window && last && last.get() == window.get()) {
            if (followWsZoom(window))
                pinToZoomingWindow(window);
            return;
        }

        if (!shouldShow(window)) {
            // Bar / wallpaper click: keep braces on the still-visible window.
            // Empty workspace: the last window is no longer on this view — drop them.
            if (!shouldShow(last))
                hide();
            return;
        }

        g_window = window;

        if (followWsZoom(window) || (last && last->m_workspace != window->m_workspace)) {
            pinToZoomingWindow(window);
            return;
        }

        const CBox dest    = windowBox(window, IGeometric::GEOMETRIC_GOAL);
        const bool canJump = g_ready && g_animate && g_damaged.w > 1;

        g_toPos  = dest.pos();
        g_toSize = dest.size();

        if (canJump) {
            g_fromPos  = g_pos;
            g_fromSize = g_size;
            g_t        = 0.f;
            g_lastTick = Clock::now();
        } else {
            g_pos      = g_toPos;
            g_size     = g_toSize;
            g_fromPos  = g_pos;
            g_fromSize = g_size;
            g_t        = 1.f;
            damageCurrent();
        }

        g_ready = true;
    }

    static void onTick() {
        if (!g_enabled)
            return;

        const auto now = Clock::now();
        float dt       = std::chrono::duration<float>(now - g_lastTick).count();
        g_lastTick     = now;
        // After idle (typing, then a pause) Hyprland may not tick. The next
        // frame's dt would be huge and finish the jump in one shot.
        dt = std::clamp(dt, 0.f, 1.f / 30.f);

        const auto w = g_window.lock();
        if (!shouldShow(w)) {
            hide();
            return;
        }

        if (followWsZoom(w)) {
            pinToZoomingWindow(w);
            return;
        }

        const auto type = g_t < 1.f ? IGeometric::GEOMETRIC_GOAL : IGeometric::GEOMETRIC_CURRENT;
        const CBox dest = windowBox(w, type);
        g_toPos         = dest.pos();
        g_toSize        = dest.size();

        if (g_t < 1.f) {
            g_t           = std::min(1.f, g_t + dt / g_jumpSec);
            const float e = ease(g_t);
            g_pos         = mix(g_fromPos, g_toPos, e);
            g_size        = mix(g_fromSize, g_toSize, e);
            damageCurrent();
        } else {
            g_pos  = g_toPos;
            g_size = g_toSize;
        }
    }

    static void onRenderStage(eRenderStage stage) {
        if (stage != RENDER_POST_WINDOWS)
            return;
        if (!g_ready || !g_enabled || !g_pHyprRenderer)
            return;

        const auto mon = g_pHyprRenderer->m_renderData.pMonitor.lock();
        if (!mon)
            return;

        const auto w = g_window.lock();
        if (!shouldShow(w))
            return;

        CBox win{g_pos, g_size};
        win.translate(-mon->m_position).scale(mon->m_scale).round();
        hudDrawFrame(win, static_cast<float>(mon->m_scale), 1.f, g_style);
        g_damaged = CBox{g_pos, g_size};
    }

    void init() {
        pullConfig(false);

        g_reloaded = Event::bus()->m_events.config.reloaded.listen([] { pullConfig(true); });
        g_tick     = Event::bus()->m_events.tick.listen([] { onTick(); });
        g_render   = Event::bus()->m_events.render.stage.listen([](eRenderStage stage) { onRenderStage(stage); });

        g_ready    = false;
        g_t        = 1.f;
        g_window.reset();
        g_damaged = {};
        g_lastTick = Clock::now();
    }

    void exit() {
        g_render.reset();
        g_tick.reset();
        g_reloaded.reset();
        g_window.reset();
        g_ready = false;
    }
}
