# Architecture

Zwäg is a native SwiftUI app, iOS 17+, built local first. There is no backend: personal data lives in SwiftData on the device, and the only network calls are barcode lookups against Open Food Facts.

## Module layout

```
Zwaeg/
  App/        Entry point, root navigation, custom tab bar, debug launch args
  Core/       UI-free logic and shared UI primitives
    CalorieMath.swift      BMI, ideal weight, BMR/TDEE, MET calculations
    Theme.swift            Design tokens (Munch palette)
    SharedUI.swift         Card, ValueField, BigValueField, ResultNumber
    Food/                  FoodProduct, Open Food Facts client, Swiss food list
    Health/                HealthKitService (steps, active energy, weight)
    Battles/               Challenge model, score engine, sync services
  Features/   One folder per screen area (Diary, Scanner, Calculators,
              Battles, Progress, Profile, Onboarding)
  Models/     SwiftData models and shared enums
  Resources/  swiss_foods.json (official BLV food database, bundled)
```

## Data model (SwiftData)

- `UserProfile`: body data, activity level, goal, computed daily calorie target
- `FoodEntry`: one logged food per meal and day, calories plus macros
- `WeightEntry`: weight history for the progress chart
- `WaterDay`: glasses of water per day
- `Challenge`: battle metadata plus participants stored as JSON data

Enums (`Sex`, `ActivityLevel`, `Goal`, `MealType`, `BattleMetric`) are stored as raw strings for painless SwiftData persistence.

## Key decisions

- **XcodeGen** generates the Xcode project from `project.yml`. Generated files (`Zwaeg.xcodeproj`, `Info.plist`, `Zwaeg.entitlements`) are gitignored.
- **CalorieMath is UI-free** so the battle score engine reuses the same formulas.
- **Battles are backend-less**: participants meet via a 6-character join code. `ChallengeSyncService` writes to the CloudKit *public* database (one record per participant per day) using the code as the only link between players; no iCloud identity is read and nothing ties a score to an Apple Account. Everything read back is treated as untrusted input and sanitized, because anyone with a code can write.
- **SwiftData never touches CloudKit**: `AppModel` pins `cloudKitDatabase: .none`. SwiftData defaults to `.automatic`, which would mirror the whole local store to the user's private database as soon as the iCloud entitlement is present — the opposite of the local-first promise, and it refuses to load the store at all because the models have non-optional attributes without defaults.
- **Food data**: barcode lookups hit the Swiss Open Food Facts instance and prefer German product names. Generic foods come from the official Swiss Food Composition Database V7.0 (BLV, naehrwertdaten.ch), converted from the published Excel export to a bundled JSON (1220 foods, values per 100 g, synonyms searchable). The BLV terms allow use in nutrition apps with attribution, which the in-app help screen provides.
- **Theme tokens** in `Theme.swift` carry the whole design. The app is pinned to light mode because the design language is light.

## Design language

The UI follows the "Munch" concept (see the design export in the repo root): warm cream background, soft white cards with large radii, coral accent with white text, peach chips, SF Rounded type, a floating pill tab bar with a raised scan button, and one question per screen in onboarding.
