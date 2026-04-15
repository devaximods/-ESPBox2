export TARGET = iphone:latest:15.0
export ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TestLine
TestLine_FILES = Tweak.xm
TestLine_FRAMEWORKS = UIKit

include $(THEOS)/makefiles/tweak.mk