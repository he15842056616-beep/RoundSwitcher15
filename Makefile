export THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RoundSwitcher15
RoundSwitcher15_FILES = Tweak.x
RoundSwitcher15_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
RoundSwitcher15_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
