SIMULATOR := iPhone 17 Pro
BUNDLE_ID := ch.emanuell.zwaeg

.PHONY: generate build run clean format lint

generate:
	xcodegen generate

build: generate
	xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' build

run: build
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIMULATOR)" "$$(find ~/Library/Developer/Xcode/DerivedData \
		-name 'Zwaeg.app' -path '*iphonesimulator*' -not -path '*Index.noindex*' | head -1)"
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

clean:
	xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg clean 2>/dev/null || true
	rm -rf Zwaeg.xcodeproj

format:
	swiftformat Zwaeg

lint:
	swiftlint lint --quiet
