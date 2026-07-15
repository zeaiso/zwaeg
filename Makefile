SIMULATOR := iPhone 17 Pro
BUNDLE_ID := ch.emanuell.zwaeg
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)

# Ask xcodebuild where it put the app instead of globbing DerivedData: a second
# build directory (from an older checkout or a renamed folder) makes `find | head`
# install a stale binary that looks convincingly like the current one.
app_path = $(shell xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg \
	-destination '$(DESTINATION)' -showBuildSettings 2>/dev/null \
	| awk -F' = ' '/ TARGET_BUILD_DIR =/{d=$$2} / FULL_PRODUCT_NAME =/{n=$$2} END{print d"/"n}')

# Local build switches (ZWAEG_BATTLES). Optional: without a .env the defaults
# below apply and battles are compiled out, which is what a fresh clone wants.
-include .env
export

.PHONY: generate build run clean format lint

generate:
	xcodegen generate

build: generate
	xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg \
		-destination '$(DESTINATION)' build

run: build
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIMULATOR)" "$(app_path)"
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

clean:
	xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg clean 2>/dev/null || true
	rm -rf Zwaeg.xcodeproj

format:
	swiftformat Zwaeg

lint:
	swiftlint lint --quiet
