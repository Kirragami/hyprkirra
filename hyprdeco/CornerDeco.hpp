#pragma once

#define WLR_USE_UNSTABLE

#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/OpenGL.hpp>

class CKirraCornerDeco : public IHyprWindowDecoration {
  public:
    CKirraCornerDeco(PHLWINDOW pWindow);
    virtual ~CKirraCornerDeco() = default;

    virtual SDecorationPositioningInfo getPositioningInfo();
    virtual void                       onPositioningReply(const SDecorationPositioningReply& reply);
    virtual void                       draw(PHLMONITOR, float const& a);
    virtual eDecorationType            getDecorationType();
    virtual void                       updateWindow(PHLWINDOW);
    virtual void                       damageEntire();
    virtual eDecorationLayer           getDecorationLayer();
    virtual uint64_t                   getDecorationFlags();
    virtual std::string                getDisplayName();

  private:
    PHLWINDOWREF m_window;
    CBox         m_assignedGeometry = {0};
    Vector2D     m_lastPos;
    Vector2D     m_lastSize;

    CBox         assignedBoxGlobal();
    bool         shouldDraw();
    void         addRect(const CBox& box, const CHyprColor& color);
    void         drawCorner(const CBox& win, bool right, bool bottom, float scale, float a);
};
