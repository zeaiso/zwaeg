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

## Get Zwäg

**The easy way is the App Store.** The published app is built from exactly this repository, nothing added, nothing private. The code is public on purpose: an app that promises your health data never leaves the device should let you check that promise instead of asking you to trust it.

**The other way is building it yourself.** The whole app is here under the MIT license, and what you need depends on how far you want to take it:

| You want | You need | What you get |
|---|---|---|
| Try it in the simulator | A Mac with Xcode, nothing else | Every feature except battles, no Apple account at all |
| Zwäg on your own iPhone | A free Apple ID | Xcode signs it for your device; free-account installs expire after 7 days, then you build and install again |
| Everything, including battles | A paid Apple Developer membership | Battles sync over CloudKit, which Apple only grants to paid accounts, using your own container that only you control |

### Building

Requirements: Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
brew install xcodegen
xcodegen generate
open Zwaeg.xcodeproj
```

Hit Run and you have the simulator tier. For your own iPhone, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, put in your Team ID (Xcode shows it under Settings > Accounts), select your device and hit Run again.

### Battles on your own container

Battles are opt-in at build time because they are the one feature with a server side: scores sync over a CloudKit container that only its owner can write to. You cannot ship to my container, and I cannot read yours, so a fork runs its own:

```sh
cp .env.example .env          # set ZWAEG_BATTLES=true, no quotes
make generate
```

Then follow the CloudKit setup in [DEVELOPMENT](docs/DEVELOPMENT.md): one prefix in `Config/Local.xcconfig` rebrands every identifier (bundle IDs, app group, container), and the console needs about two minutes of one-time setup.

`Local.xcconfig` and `.env` are gitignored because they are personal to a checkout, not because they are secret; a Team ID ships inside every app on the store. The `.xcodeproj`, `Info.plist` and entitlements are generated from `project.yml` and not checked in. See [DEVELOPMENT](docs/DEVELOPMENT.md) for build commands, debug launch arguments and simulator tips.

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
