# Development

## Building

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Zwaeg.xcodeproj -scheme Zwaeg \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or open `Zwaeg.xcodeproj` in Xcode and hit Run. Regenerate the project with `xcodegen generate` whenever files are added or removed or `project.yml` changes.

## Debug launch arguments

Useful for driving the app from the CLI or Xcode scheme arguments:

| Argument | Effect |
|---|---|
| `-seed-profile` | Creates a test profile with weight history, three days of meals, water and a demo battle when no profile exists |
| `-tab <0-6>` | Opens a specific tab (0 diary, 1 battles, 2 scanner, 3 calculators, 4 profile, 5 recipes, 6 fasting) |
| `-lang <code>` | Forces an app language (`de`, `gsw`, `fr`, `it`, `rm`, `en`, `ar`, `ti`, ...) |
| `-look <name>` | Forces a look (`munch`, `midnight`, `mono`) |
| `-accent <RRGGBB>` | Forces an accent color for this launch without persisting it |
| `-onboarding-body` | Jumps onboarding straight to the age question |
| `-onboarding-buddy` | Jumps onboarding straight to the buddy picker |
| `-add-food <meal>` | Opens the add-food page (`breakfast`, `lunch`, `dinner`, `snack`) |
| `-open-calc <name>` | Opens a calculator (`bmi`, `ideal`, `needs`, `burn`, combine with `-tab 3`) |
| `-open-fasting` | Opens the fasting tab |
| `-seed-fast` | Starts a 16:8 fast that began 13 hours ago (combine with `-open-fasting`) |
| `-open-fasting-plans` | Opens the fasting plan catalog (combine with `-open-fasting`) |
| `-open-recipe <id>` | Opens a recipe detail page, first recipe if the id is unknown (combine with `-tab 5`) |
| `-open-shopping-list` | Opens the shopping list sheet, seeded with one recipe when empty (combine with `-tab 5`) |
| `-open-calendar` | Opens the calendar sheet |
| `-open-details` | Opens the day details page |
| `-open-progress` | Opens the progress screen (combine with `-tab 4`) |
| `-open-battle` | Opens the first active battle (combine with `-tab 1`) |
| `-open-buddy` | Opens the buddy editor (combine with `-tab 4`) |
| `-studio-style <id>` | Preselects a DiceBear style in the studio, e.g. `notionists` (combine with `-open-studio`) |
| `-open-challenges` | Opens the challenges page |
| `-open-language` | Opens the language picker (combine with `-tab 4`) |
| `-open-look` | Opens the look picker (combine with `-tab 4`) |
| `-demo-product` | Opens the meal detail sheet with a sample product (combine with `-tab 2`) |
| `-scroll-bottom` | Opens the diary scrolled to the bottom |

Example:

```sh
xcrun simctl launch "iPhone 17 Pro" ch.emanuell.zwaeg -seed-profile -tab 2 -demo-product
```

## Simulator notes

- The simulator has no camera; the scanner shows a manual barcode entry fallback. Verified test barcode: `7610036010305` (Villars chocolate).
- The Health store is empty in the simulator; steps and active energy read 0. Add samples in the simulator Health app to test the flow.
- Downloaded simulator runtimes may lack the color emoji font. The UI uses SF Symbols for anything meaningful.
- Screenshots: `xcrun simctl io "iPhone 17 Pro" screenshot out.png`

## Conventions

- German UI strings with Swiss spelling (Grösse, Mässig). Code, comments and docs in English.
- No en or em dashes in any text; use plain hyphens or rephrase.
- Design tokens live in `Core/Theme.swift`; do not hardcode colors in views unless they are one-off semantic colors.
- Commit each logical unit separately, right when it is done and verified.
