export TARGET = iphone:latest:15.0
export ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ESPBox
ESPBox_FILES = Tweak.x
ESPBox_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS)/makefiles/tweak.mk
