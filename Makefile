SIMULATOR := iPhone 17 Pro
BUNDLE_ID := ch.emanuell.znueni

.PHONY: generate build run clean format lint

generate:
	xcodegen generate

build: generate
	xcodebuild -project Znueni.xcodeproj -scheme Znueni \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' build

run: build
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIMULATOR)" "$$(find ~/Library/Developer/Xcode/DerivedData \
		-name 'Znueni.app' -path '*iphonesimulator*' -not -path '*Index.noindex*' | head -1)"
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

clean:
	xcodebuild -project Znueni.xcodeproj -scheme Znueni clean 2>/dev/null || true
	rm -rf Znueni.xcodeproj

format:
	swiftformat Znueni

lint:
	swiftlint lint --quiet
