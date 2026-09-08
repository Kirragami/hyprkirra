#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/helpers/math/Math.hpp>

namespace WorkspaceZoom {
    void  init();
    void  exit();
    bool  inbound(PHLWORKSPACE ws);
    float scaleFor(PHLWORKSPACE ws);
    float braceScaleFor(PHLWORKSPACE ws);
    CBox  scaledBox(CBox box, float s, PHLMONITOR mon);
}
