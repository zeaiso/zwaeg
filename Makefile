SIMULATOR := iPhone 17 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)

# Local build switches (ZWAEG_BATTLES). Optional: without a .env the defaults
# apply and battles are compiled out, which is what a fresh clone wants.
-include .env
export

.PHONY: generate build run clean format lint

generate:
	@case "$(ZWAEG_BATTLES)" in \
		""|true|false|yes|no|TRUE|FALSE|YES|NO|1|0) ;; \
		*) echo "warning: ZWAEG_BATTLES='$(ZWAEG_BATTLES)' is not plain true/false;" \
		   "xcodegen silently treats it as false. Remove any quotes in .env." ;; \
	esac
	xcodegen generate

build: generate
	xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg \
		-destination '$(DESTINATION)' build

# The app path is resolved inside the recipe, not in a global $(shell ...)
# variable: with `export` above, make would expand a global variable (and run
# the multi-second xcodebuild) for every target, even ones that never use it.
# Asking xcodebuild beats globbing DerivedData, where a second build directory
# from an older checkout makes `find | head -1` install a stale binary.
run: build
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	open -a Simulator
	SETTINGS="$$(xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg \
		-destination '$(DESTINATION)' -showBuildSettings 2>/dev/null)" \
	&& APP="$$(echo "$$SETTINGS" | awk -F' = ' '/ TARGET_BUILD_DIR =/{d=$$2} / FULL_PRODUCT_NAME =/{n=$$2} END{print d"/"n}')" \
	&& BUNDLE="$$(echo "$$SETTINGS" | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER =/{print $$2; exit}')" \
	&& xcrun simctl install "$(SIMULATOR)" "$$APP" \
	&& xcrun simctl launch "$(SIMULATOR)" "$$BUNDLE"

clean:
	xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg clean 2>/dev/null || true
	rm -rf Zwaeg.xcodeproj

format:
	swiftformat Zwaeg

lint:
	swiftlint lint --quiet
