#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>

namespace FocusTrail {
    void init();
    void exit();
    void onFocus(PHLWINDOW window);
}
