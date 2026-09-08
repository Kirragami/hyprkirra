#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/config/ConfigManager.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/event/EventBus.hpp>

#include "FocusTrail.hpp"
#include "WorkspaceZoom.hpp"
#include "globals.hpp"

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

static CHyprSignalListener g_focus;
static CHyprSignalListener g_workspace;

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();

    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(PHANDLE, "[kirracorners] headers do not match this Hyprland build — rebuild the plugin", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[kirracorners] version mismatch");
    }

    // Defaults match widget HudFrame geometry: arm 14, thick 1.15, inset 3.5.
    // Brace color is orange (#ff7a18); widgets stay silver.
    vars.enabled     = makeShared<Config::Values::CBoolValue>("plugin:kirracorners:enabled", "Draw HUD L-corners on the focused window", true);
    vars.animate     = makeShared<Config::Values::CBoolValue>("plugin:kirracorners:animate", "Animate L-corners jumping to the newly focused window", true);
    vars.wsZoom      = makeShared<Config::Values::CBoolValue>("plugin:kirracorners:ws_zoom", "Zoom workspaces out/in while they fade", true);
    vars.jumpSec     = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:jump_sec", "Focus jump duration in seconds", 0.28f);
    vars.wsZoomScale = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:ws_zoom_scale", "Scale of a fully faded workspace", 0.55f);
    vars.arm        = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:arm", "L-brace arm length in px", 14.f);
    vars.thick      = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:thick", "L-brace stroke in px", 1.15f);
    vars.inset      = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:inset", "Inner tick inset in px", 3.5f);
    vars.lineAlpha  = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:line_alpha", "Outer L opacity", 0.82f);
    vars.innerAlpha = makeShared<Config::Values::CFloatValue>("plugin:kirracorners:inner_alpha", "Inner tick opacity", 0.7f);
    vars.colLine    = makeShared<Config::Values::CColorValue>("plugin:kirracorners:col.line", "Outer L color", 0xffff7a18);
    vars.colDim     = makeShared<Config::Values::CColorValue>("plugin:kirracorners:col.dim", "Inner tick color", 0xff8a4210);

    HyprlandAPI::addConfigValueV2(PHANDLE, vars.enabled);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.animate);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.wsZoom);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.jumpSec);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.wsZoomScale);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.arm);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.thick);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.inset);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.lineAlpha);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.innerAlpha);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.colLine);
    HyprlandAPI::addConfigValueV2(PHANDLE, vars.colDim);

    FocusTrail::init();
    WorkspaceZoom::init();

    g_focus = Event::bus()->m_events.window.active.listen([](PHLWINDOW w, Desktop::eFocusReason) { FocusTrail::onFocus(w); });
    g_workspace = Event::bus()->m_events.workspace.active.listen([](PHLWORKSPACE) {
        FocusTrail::onFocus(Desktop::focusState()->window());
    });
    FocusTrail::onFocus(Desktop::focusState()->window());

    return {"kirracorners", "HUD L-corners that jump to the focused window", "kirra", "1.1"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_focus.reset();
    g_workspace.reset();
    WorkspaceZoom::exit();
    FocusTrail::exit();
}
