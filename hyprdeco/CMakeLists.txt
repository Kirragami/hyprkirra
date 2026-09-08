cmake_minimum_required(VERSION 3.19)
project(kirracorners LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_compile_definitions(WLR_USE_UNSTABLE)

add_library(kirracorners SHARED
    main.cpp
    FocusTrail.cpp
)

set_target_properties(kirracorners PROPERTIES PREFIX "")

find_package(PkgConfig REQUIRED)
pkg_check_modules(deps REQUIRED IMPORTED_TARGET
    hyprland
    hyprutils
    hyprlang
    pixman-1
    libdrm
)
target_link_libraries(kirracorners PRIVATE PkgConfig::deps)
target_compile_options(kirracorners PRIVATE -Wall -Wextra -Wno-unused-parameter)
