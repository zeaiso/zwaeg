# Zwäg

**A fresh, playful calorie tracker for iOS. Swiss to the core.**

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-purple)
![License](https://img.shields.io/badge/license-MIT-green)

Zwäg (Swiss German for feeling fit and well) tracks your calories, macros, steps, water and weight. It is local first: all personal data stays on your device.

## Screenshots

| Diary | Recipes | Recipe |
|---|---|---|
| ![Diary](docs/screenshots/diary.jpg) | ![Recipes](docs/screenshots/recipes.jpg) | ![Recipe](docs/screenshots/recipe-detail.jpg) |

| Fasting | Challenges | Buddy studio |
|---|---|---|
| ![Fasting](docs/screenshots/fasting.jpg) | ![Challenges](docs/screenshots/challenges.jpg) | ![Buddy studio](docs/screenshots/studio.jpg) |

| Progress | Battles | Scanner |
|---|---|---|
| ![Progress](docs/screenshots/progress.jpg) | ![Battles](docs/screenshots/battles.jpg) | ![Scanner](docs/screenshots/scanner.jpg) |

## Features

- **Diary**: log meals with a daily calorie budget, macros, week strip, steps from Apple Health and a water counter
- **Recipes**: 200+ healthy recipes with Swiss classics, browsable by category, calories and diet, one tap logs a portion to the diary
- **Barcode scanner**: live EAN scanning (VisionKit) with product lookup on Open Food Facts, plus the official Swiss Food Composition Database (BLV, 1220 foods) bundled for offline search
- **Calculators**: BMI, ideal weight, daily calorie needs (Mifflin-St Jeor) and calorie burn (MET based)
- **Progress**: weight trend chart, weekly calorie bars, monthly stats
- **Battles**: challenge friends over steps, active calories or calorie deficit with join codes (CloudKit ready, currently local demo opponents)
- **Apple Health**: reads steps and active energy, writes logged weight

## Getting started

Requirements: Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
brew install xcodegen
xcodegen generate
open Zwaeg.xcodeproj
```

The `.xcodeproj`, `Info.plist` and entitlements are generated from `project.yml` and not checked in. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for build commands, debug launch arguments and simulator tips.

## Documentation

- [Architecture](docs/ARCHITECTURE.md): modules, data flow and design decisions
- [Development](docs/DEVELOPMENT.md): building, testing and debug tooling

## Credits

- Nutrition data: [Swiss Food Composition Database](https://naehrwertdaten.ch) (BLV) and [Open Food Facts](https://ch.openfoodfacts.org)
- Recipe photos: [Pexels](https://www.pexels.com) (Pexels License) and [Wikimedia Commons](https://commons.wikimedia.org) (CC BY, CC BY-SA, CC0 or public domain); every image with author and license in [docs/IMAGE-CREDITS.md](docs/IMAGE-CREDITS.md) and shown in the app on the recipe page
- Avatars: generated with [DiceBear](https://dicebear.com). Styles: Avataaars and Bottts by [Pablo Stanley](https://avataaars.com) (free for personal and commercial use), Notionists by Zoish (CC0), Adventurer and Lorelei by Lisa Wischofsky (CC BY 4.0 / CC0), Big Smile by Ashley Seo (CC BY 4.0), Open Peeps by Pablo Stanley (CC0), Personas by Draftbit (CC BY 4.0), Pixel Art and Thumbs by DiceBear (CC0), Fun Emoji by Davis Uche (CC BY 4.0), Micah by Micah Lanier (CC BY 4.0)
- Font: [Fredoka](https://fonts.google.com/specimen/Fredoka) (SIL Open Font License)

## License

[MIT](LICENSE)
