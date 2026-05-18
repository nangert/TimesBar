APP_NAME := TimesBar
VERSION ?= 0.1.0
BUILD_DIR := build
ARCHIVE_PATH := $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_DIR := $(BUILD_DIR)/export
APP_PATH := $(EXPORT_DIR)/$(APP_NAME).app
ZIP_NAME := $(APP_NAME)-v$(VERSION).zip
ZIP_PATH := $(BUILD_DIR)/$(ZIP_NAME)
RELEASE_NOTES := release-notes/v$(VERSION).md

.PHONY: help app install zip release test clean project

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

app: $(APP_PATH)  ## Build and ad-hoc-sign TimesBar.app

$(APP_PATH): project
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR)/derived \
		-archivePath $(ARCHIVE_PATH) \
		archive
	@rm -rf $(EXPORT_DIR)
	@mkdir -p $(EXPORT_DIR)
	cp -R $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app $(EXPORT_DIR)/
	codesign --force --deep --sign - $(APP_PATH)
	@echo ""
	@echo "Built $(APP_PATH)"

install: app  ## Build then install to /Applications
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_PATH) /Applications/
	@echo ""
	@echo "Installed /Applications/$(APP_NAME).app"
	@echo "Open with: open /Applications/$(APP_NAME).app"
	@echo "If Gatekeeper blocks first launch, right-click the app in /Applications -> Open"

zip: app  ## Zip TimesBar.app for distribution
	@rm -f $(ZIP_PATH)
	cd $(EXPORT_DIR) && zip -qry ../$(ZIP_NAME) $(APP_NAME).app
	@echo "$(ZIP_PATH)"

release: zip  ## Publish a tagged GitHub release with the zipped .app
	@test -f $(RELEASE_NOTES) || (echo "Missing $(RELEASE_NOTES)"; exit 1)
	@git rev-parse v$(VERSION) >/dev/null 2>&1 || git tag -a v$(VERSION) -m "TimesBar v$(VERSION)"
	git push origin v$(VERSION)
	gh release create v$(VERSION) $(ZIP_PATH) \
		--title "TimesBar v$(VERSION)" \
		--notes-file $(RELEASE_NOTES)

test: project  ## Run the unit-test suite
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-destination 'platform=macOS' \
		test

project: $(APP_NAME).xcodeproj/project.pbxproj  ## Generate the Xcode project via xcodegen

$(APP_NAME).xcodeproj/project.pbxproj: project.yml
	@command -v xcodegen >/dev/null || { echo "xcodegen is not installed. Run: brew install xcodegen"; exit 1; }
	xcodegen generate

clean:  ## Remove build artifacts and the generated Xcode project
	rm -rf $(BUILD_DIR) $(APP_NAME).xcodeproj
