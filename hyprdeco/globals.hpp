#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>

inline HANDLE PHANDLE = nullptr;

struct SKirraCornerVars {
    SP<Config::Values::CBoolValue>  enabled;
    SP<Config::Values::CBoolValue>  animate;
    SP<Config::Values::CBoolValue>  wsZoom;
    SP<Config::Values::CFloatValue> jumpSec;
    SP<Config::Values::CFloatValue> wsZoomScale;
    SP<Config::Values::CFloatValue> arm;
    SP<Config::Values::CFloatValue> thick;
    SP<Config::Values::CFloatValue> inset;
    SP<Config::Values::CFloatValue> lineAlpha;
    SP<Config::Values::CFloatValue> innerAlpha;
    SP<Config::Values::CColorValue> colLine;
    SP<Config::Values::CColorValue> colDim;
};

inline SKirraCornerVars vars;
