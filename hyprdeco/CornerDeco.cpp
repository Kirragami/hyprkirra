#include "CornerDeco.hpp"
#include "globals.hpp"

#include <algorithm>

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>

using namespace Desktop::View;

CKirraCornerDeco::CKirraCornerDeco(PHLWINDOW pWindow) : IHyprWindowDecoration(pWindow), m_window(pWindow) {
    m_lastPos  = pWindow->position(IGeometric::GEOMETRIC_CURRENT);
    m_lastSize = pWindow->size(IGeometric::GEOMETRIC_CURRENT);
}

SDecorationPositioningInfo CKirraCornerDeco::getPositioningInfo() {
    SDecorationPositioningInfo info;
    info.policy          = DECORATION_POSITION_STICKY;
    info.reserved        = false;
    info.priority        = 9990;
    info.edges           = DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT | DECORATION_EDGE_TOP;
    info.desiredExtents  = {{0, 0}, {0, 0}};
    return info;
}

void CKirraCornerDeco::onPositioningReply(const SDecorationPositioningReply& reply) {
    m_assignedGeometry = reply.assignedGeometry;
}

CBox CKirraCornerDeco::assignedBoxGlobal() {
    CBox box = m_assignedGeometry;
    box.translate(g_pDecorationPositioner->getEdgeDefinedPoint(DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT | DECORATION_EDGE_TOP, m_window.lock()));

    const auto PWINDOW = m_window.lock();
    if (!PWINDOW)
        return box;

    const auto PWORKSPACE     = PWINDOW->m_workspace;
    const auto WORKSPACEOFFSET = PWORKSPACE && !PWINDOW->m_pinned ? PWORKSPACE->m_renderOffset->value() : Vector2D();
    return box.translate(PWINDOW->m_floatingOffset + WORKSPACEOFFSET);
}

bool CKirraCornerDeco::shouldDraw() {
    if (!vars.enabled || !vars.enabled->value())
        return false;

    const auto PWINDOW = m_window.lock();
    if (!validMapped(PWINDOW))
        return false;
    if (PWINDOW->m_X11DoesntWantBorders)
        return false;
    if (PWINDOW->m_ruleApplicator && !PWINDOW->m_ruleApplicator->decorate().valueOrDefault())
        return false;
    if (Fullscreen::controller()->isFullscreen(PWINDOW, Fullscreen::FSMODE_FULLSCREEN))
        return false;
    const auto focused = Desktop::focusState()->window();
    if (!focused || focused.get() != PWINDOW.get())
        return false;
    return true;
}

void CKirraCornerDeco::addRect(const CBox& box, const CHyprColor& color) {
    if (box.w < 0.2 || box.h < 0.2)
        return;

    CRectPassElement::SRectData data;
    data.box   = box;
    data.color = color;
    g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(data));
}

void CKirraCornerDeco::drawCorner(const CBox& win, bool right, bool bottom, float scale, float a) {
    const float arm     = vars.arm->value() * scale;
    const float thick   = vars.thick->value() * scale;
    const float inset   = vars.inset->value() * scale;
    const float innerLen = std::max(thick, arm - inset - 2.f * scale);

    const double ox = right ? win.x + win.w - arm : win.x;
    const double oy = bottom ? win.y + win.h - arm : win.y;

    const auto line = CHyprColor{static_cast<uint64_t>(vars.colLine->value())}.modifyA(vars.lineAlpha->value() * a);
    const auto dim  = CHyprColor{static_cast<uint64_t>(vars.colDim->value())}.modifyA(vars.innerAlpha->value() * a);

    addRect({ox, bottom ? oy + arm - thick : oy, arm, thick}, line);
    addRect({right ? ox + arm - thick : ox, oy, thick, arm}, line);

    addRect({right ? ox + arm - innerLen - inset : ox + inset, bottom ? oy + arm - thick - inset : oy + inset, innerLen, thick}, dim);
    addRect({right ? ox + arm - thick - inset : ox + inset, bottom ? oy + arm - innerLen - inset : oy + inset, thick, innerLen}, dim);
}

void CKirraCornerDeco::draw(PHLMONITOR pMonitor, float const& a) {
    if (!shouldDraw())
        return;

    const auto PWINDOW = m_window.lock();
    CBox       win     = assignedBoxGlobal().translate(-pMonitor->m_position).scale(pMonitor->m_scale).round();

    if (win.w < 2 || win.h < 2)
        return;

    const float scale = static_cast<float>(pMonitor->m_scale);
    drawCorner(win, false, false, scale, a);
    drawCorner(win, true, false, scale, a);
    drawCorner(win, false, true, scale, a);
    drawCorner(win, true, true, scale, a);
}

eDecorationType CKirraCornerDeco::getDecorationType() {
    return DECORATION_CUSTOM;
}

void CKirraCornerDeco::updateWindow(PHLWINDOW pWindow) {
    m_lastPos  = pWindow->position(IGeometric::GEOMETRIC_CURRENT);
    m_lastSize = pWindow->size(IGeometric::GEOMETRIC_CURRENT);
    damageEntire();
}

void CKirraCornerDeco::damageEntire() {
    const auto PWINDOW = m_window.lock();
    if (!validMapped(PWINDOW))
        return;

    const float arm = vars.arm ? vars.arm->value() : 14.f;
    CBox        win{m_lastPos, m_lastSize};
    win.expand(2);
    g_pHyprRenderer->damageBox(win);

    CBox corners[] = {
        {m_lastPos.x, m_lastPos.y, arm, arm},
        {m_lastPos.x + m_lastSize.x - arm, m_lastPos.y, arm, arm},
        {m_lastPos.x, m_lastPos.y + m_lastSize.y - arm, arm, arm},
        {m_lastPos.x + m_lastSize.x - arm, m_lastPos.y + m_lastSize.y - arm, arm, arm},
    };
    for (auto& c : corners)
        g_pHyprRenderer->damageBox(c.expand(2));
}

eDecorationLayer CKirraCornerDeco::getDecorationLayer() {
    return DECORATION_LAYER_OVER;
}

uint64_t CKirraCornerDeco::getDecorationFlags() {
    return DECORATION_NON_SOLID;
}

std::string CKirraCornerDeco::getDisplayName() {
    return "KirraCorners";
}
