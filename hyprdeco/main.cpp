#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/config/ConfigManager.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/event/EventBus.hpp>

#include "FocusTrail.hpp"
#include "globals.hpp"

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

static CHyprSignalListener g_focus;

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();

    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(PHANDLE, "[kirracorners] headers do not match this Hyprland build — rebuild the plugin", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[kirracorners] version mismatch");
    }

    // Defaults match geowidget/HudFrame as used by the bays: arm 14, thick 1.15, inset 3.5,
    // Theme.line #e6e6e6 @ 0.82, Theme.lineDim #5a5a5a @ 0.7
    vars.enabled    = makeShared<Config::Values::CBoolValue>("plugin:kirracorners:enabled", "Draw HUD L-corners on the focused window", true);
    vars.animate    = makeShared<Config::Values::CBoolValue>("plugin:kirracorners:animate", "Animate L-corners jumping to the newly focused window", true);
    vars.jumpSec    = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:jump_sec", "Focus jump duration in seconds", 0.28f);
    vars.arm        = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:arm", "L-brace arm length in px", 14.f);
    vars.thick      = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:thick", "L-brace stroke in px", 1.15f);
    vars.inset      = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:inset", "Inner tick inset in px", 3.5f);
    vars.lineAlpha  = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:line_alpha", "Outer L opacity", 0.82f);
    vars.innerAlpha = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:inner_alpha", "Inner tick opacity", 0.7f);
    vars.colLine    = makeShared<Config::Values::CColorValue>("plugin:kirracorners:col.line", "Outer L color", 0xffe6e6e6);
    vars.colDim     = makeShared<Config::Values::CColorValue>("plugin:kirracorners:col.dim", "Inner tick color", 0xff5a5a5a);

    HyprlandAPI::addConfigValueV2(PHANDLE, vars.enabled);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.animate);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.jumpSec);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.arm);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.thick);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.inset);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.lineAlpha);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.innerAlpha);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.colLine);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.colDim);

    FocusTrail::init();

    g_focus = Event::bus()->m_events.window.active.listen([](PHLWINDOW w, Desktop::eFocusReason) { FocusTrail::onFocus(w); });
    FocusTrail::onFocus(Desktop::focusState()->window());

    return {"kirracorners", "HUD L-corners that jump to the focused window", "kirra", "0.5"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_focus.reset();
    FocusTrail::exit();
}
