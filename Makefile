SIMULATOR := iPhone 17 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)

# Local build switches (ZWAEG_BATTLES). Optional: without a .env the defaults
# apply and battles are compiled out, which is what a fresh clone wants.
-include .env
export

.PHONY: generate build run clean format lint github-release

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

# Publishes the current version as a GitHub release, Outline-style: tags
# v<MARKETING_VERSION>, pushes main and the tag, and creates the release
# with this version's CHANGELOG section as notes; GitHub appends the
# auto-generated commit list below. Needs `gh auth login` once.
github-release:
	@VERSION="$$(sed -n 's/.*MARKETING_VERSION: "\([^"]*\)".*/\1/p' project.yml | head -1)" \
	&& TAG="v$$VERSION" \
	&& NOTES="$$(mktemp)" \
	&& awk -v ver="$$VERSION" '$$0 ~ "^## "ver" " {on=1; next} /^## / {on=0} on' CHANGELOG.md > "$$NOTES" \
	&& test -s "$$NOTES" || { echo "error: no CHANGELOG section for $$VERSION"; exit 1; } \
	; git tag "$$TAG" 2>/dev/null || true \
	&& git push origin main "$$TAG" \
	&& gh release create "$$TAG" --title "$$TAG" --notes-file "$$NOTES" --generate-notes \
	&& rm -f "$$NOTES"
