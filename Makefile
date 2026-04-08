export TARGET = iphone:latest:15.0
export ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ESPBox
ESPBox_FILES = Tweak.x
ESPBox_FRAMEWORKS = UIKit Foundation CoreGraphics
ESPBox_CFLAGS = -Wno-deprecated-declarations

include $(THEOS)/makefiles/tweak.mk
