TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Retribution
BUNDLE_NAME = RetributionResources

Retribution_FILES = $(wildcard Sources/*.x Sources/*.xm Sources/*.m Sources/*.mm Sources/**/*.x Sources/**/*.xm Sources/**/*.m Sources/**/*.mm)
Retribution_CFLAGS = -fobjc-arc -DPACKAGE_VERSION='@"$(THEOS_PACKAGE_BASE_VERSION)"' -I$(THEOS_PROJECT_DIR)/Headers -F$(THEOS_PROJECT_DIR)
Retribution_CCFLAGS = -std=c++17 -fobjc-arc -I$(THEOS_PROJECT_DIR)/Headers -F$(THEOS_PROJECT_DIR)
Retribution_FRAMEWORKS = Foundation UIKit CoreGraphics CoreText CoreFoundation
Retribution_LDFLAGS = -undefined dynamic_lookup -F$(THEOS_PROJECT_DIR) -framework SentryObjC

RetributionResources_INSTALL_PATH = "/Library/Application\ Support/"
RetributionResources_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-all::
	$(ECHO_NOTHING)mkdir -p Resources$(ECHO_END)
	$(ECHO_NOTHING)curl -L --fail --max-time 120 -o Resources/bundle-old.js https://github.com/Retribution-Mod/retribution-bundle/releases/latest/download/retribution-old.min.js || true$(ECHO_END)
	$(ECHO_NOTHING)curl -L --fail --max-time 120 -o Resources/bundle-new.js https://github.com/Retribution-Mod/retribution-bundle/releases/latest/download/retribution-new.min.js || true$(ECHO_END)
	$(ECHO_NOTHING)sed -e 's/@PACKAGE_VERSION@/$(THEOS_PACKAGE_BASE_VERSION)/g' \
		-e 's/@TWEAK_NAME@/$(TWEAK_NAME)/g' \
		Sources/payload-base.template.js > Resources/payload-base.js$(ECHO_END)

after-stage::
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name ".DS_Store" -delete$(ECHO_END)
	$(ECHO_NOTHING)if [ -d "$(THEOS_PROJECT_DIR)/SentryObjC.framework" ]; then mkdir -p $(THEOS_STAGING_DIR)/Library/Frameworks && cp -R $(THEOS_PROJECT_DIR)/SentryObjC.framework $(THEOS_STAGING_DIR)/Library/Frameworks/; fi$(ECHO_END)

after-package::
	$(ECHO_NOTHING)rm -rf Resources$(ECHO_END)
