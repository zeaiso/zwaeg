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

- **Diary**: meals with calorie budgets and macros, water, weight, steps, mood, streaks and a reactive buddy mascot
- **Recipes**: 890 recipes across Swiss classics and 17 international cuisines, one tap logs a portion
- **Scanner**: live EAN scanning with Open Food Facts, offline cache, a label mode that reads nutrition tables with on device OCR, and the Swiss Food Composition Database (BLV, 1220 foods) bundled offline
- **Fasting**: 16:8, 14:10 and 12:12 with a Live Activity on the lock screen
- **Battles**: challenge friends over steps, active calories or calorie deficit; share a 6-character join code, scores sync over CloudKit. Opt-in at build time, see [Getting started](#getting-started)
- **Calculators**: BMI, ideal weight, daily calorie needs (Mifflin-St Jeor) and calorie burn (MET based)
- **Apple**: HealthKit, home screen widget, Apple Watch app with complications, Siri Shortcuts
- **Personal**: 23 languages with RTL support, three looks, custom accent color

The full tour with details per screen: [FEATURES](docs/FEATURES.md)

## Getting started

Zwäg is on the App Store, and it also builds from source: the repository is the whole app, with no private components.

Requirements: Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
brew install xcodegen
xcodegen generate
open Zwaeg.xcodeproj
```

That gives you every feature except battles, and needs no Apple Developer account for the simulator.

**Battles** are opt-in, because they are the one feature with a server side: they sync over a CloudKit container that only its owner can write to. Building them for the simulator works with no account, but running them for real needs a paid Apple Developer account and your own container:

```sh
cp .env.example .env          # set ZWAEG_BATTLES=true
make generate
```

Signing for a real device or the App Store also needs your Team ID in `Config/Local.xcconfig` (copy `Config/Local.xcconfig.example`). Both files are gitignored: they are personal to a checkout, not secret.

The `.xcodeproj`, `Info.plist` and entitlements are generated from `project.yml` and not checked in. See [DEVELOPMENT](docs/DEVELOPMENT.md) for build commands, the CloudKit setup, debug launch arguments and simulator tips.

## Documentation

- [Features](docs/FEATURES.md): the full tour, screen by screen
- [Architecture](docs/ARCHITECTURE.md): modules, data flow and design decisions
- [Development](docs/DEVELOPMENT.md): building, testing and debug tooling

## Credits

- Nutrition data: [Swiss Food Composition Database](https://naehrwertdaten.ch) (BLV) and [Open Food Facts](https://ch.openfoodfacts.org)
- Recipe photos: community contributed; every published photo is credited in [IMAGE-CREDITS](docs/IMAGE-CREDITS.md) and in the app on the recipe page
- Avatars: generated with [DiceBear](https://dicebear.com). Styles: Avataaars and Bottts by [Pablo Stanley](https://avataaars.com) (free for personal and commercial use), Notionists by Zoish (CC0), Adventurer and Lorelei by Lisa Wischofsky (CC BY 4.0 / CC0), Big Smile by Ashley Seo (CC BY 4.0), Open Peeps by Pablo Stanley (CC0), Personas by Draftbit (CC BY 4.0), Pixel Art and Thumbs by DiceBear (CC0), Fun Emoji by Davis Uche (CC BY 4.0), Micah by Micah Lanier (CC BY 4.0)
- Font: [Fredoka](https://fonts.google.com/specimen/Fredoka) (SIL Open Font License)

## License

[MIT](LICENSE)
