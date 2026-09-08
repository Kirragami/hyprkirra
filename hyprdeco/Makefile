CXX      ?= g++
PKG      := hyprland hyprutils hyprlang pixman-1 libdrm
CXXFLAGS += -std=c++23 -fPIC -DWLR_USE_UNSTABLE -Wall -Wextra -Wno-unused-parameter
CXXFLAGS += $(shell pkg-config --cflags $(PKG))
LDFLAGS  += -shared $(shell pkg-config --libs $(PKG))

kirracorners.so: main.cpp FocusTrail.cpp FocusTrail.hpp HudLs.hpp globals.hpp
	$(CXX) $(CXXFLAGS) -o $@ main.cpp FocusTrail.cpp $(LDFLAGS)

.PHONY: clean
clean:
	rm -f kirracorners.so
