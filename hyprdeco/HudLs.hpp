#pragma once

#include <cstdint>

#include <hyprland/src/helpers/Color.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>

#include <algorithm>

struct SHudStyle {
    float    arm        = 14.f;
    float    thick      = 1.15f;
    float    inset      = 3.5f;
    float    lineAlpha  = 0.82f;
    float    innerAlpha = 0.7f;
    uint32_t colLine    = 0xffff7a18;
    uint32_t colDim     = 0xff8a4210;
};

inline void hudAddRect(const CBox& box, const CHyprColor& color) {
    if (!g_pHyprRenderer || box.w < 0.2 || box.h < 0.2)
        return;

    CRectPassElement::SRectData data;
    data.box   = box;
    data.color = color;
    g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(data));
}

inline void hudDrawCorner(const CBox& win, bool right, bool bottom, float scale, float a, const SHudStyle& s) {
    const float arm      = s.arm * scale;
    const float thick    = s.thick * scale;
    const float inset    = s.inset * scale;
    const float innerLen = std::max(thick, arm - inset - 2.f * scale);

    const double ox = right ? win.x + win.w - arm : win.x;
    const double oy = bottom ? win.y + win.h - arm : win.y;

    const auto line = CHyprColor{static_cast<uint64_t>(s.colLine)}.modifyA(s.lineAlpha * a);
    const auto dim  = CHyprColor{static_cast<uint64_t>(s.colDim)}.modifyA(s.innerAlpha * a);

    hudAddRect({ox, bottom ? oy + arm - thick : oy, arm, thick}, line);
    hudAddRect({right ? ox + arm - thick : ox, oy, thick, arm}, line);

    hudAddRect({right ? ox + arm - innerLen - inset : ox + inset, bottom ? oy + arm - thick - inset : oy + inset, innerLen, thick}, dim);
    hudAddRect({right ? ox + arm - thick - inset : ox + inset, bottom ? oy + arm - innerLen - inset : oy + inset, thick, innerLen}, dim);
}

inline void hudDrawFrame(const CBox& win, float scale, float a, const SHudStyle& s) {
    if (win.w < 2 || win.h < 2)
        return;

    hudDrawCorner(win, false, false, scale, a, s);
    hudDrawCorner(win, true, false, scale, a, s);
    hudDrawCorner(win, false, true, scale, a, s);
    hudDrawCorner(win, true, true, scale, a, s);
}
