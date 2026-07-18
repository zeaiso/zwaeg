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

Useful for driving the app from the CLI or Xcode scheme arguments. All of them work in debug builds only; release builds ignore every launch argument:

| Argument | Effect |
|---|---|
| `-seed-profile` | Creates a test profile with weight history, three days of meals, water and a demo battle when no profile exists |
| `-tab <0-6>` | Opens a specific tab (0 diary, 1 battles, 2 scanner, 3 calculators, 4 profile, 5 recipes, 6 fasting; tab 1 exists only in `ZWAEG_BATTLES` builds) |
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
| `-create-battle` | Publishes a real challenge to CloudKit via the production create path; smoke-tests the round trip on a simulator signed into iCloud (combine with `-tab 1`; needs a `ZWAEG_BATTLES` build) |
| `-open-battle` | Opens the first active battle (combine with `-tab 1`; needs a `ZWAEG_BATTLES` build) |
| `-open-create` | Opens the new-challenge sheet (combine with `-tab 1`; needs a `ZWAEG_BATTLES` build) |
| `-open-join` | Opens the join-by-code sheet (combine with `-tab 1`; needs a `ZWAEG_BATTLES` build) |
| `-open-buddy` | Opens the buddy editor (combine with `-tab 4`) |
| `-studio-style <id>` | Preselects a DiceBear style in the studio, e.g. `notionists` (combine with `-open-studio`) |
| `-open-challenges` | Opens the challenges page |
| `-open-language` | Opens the language picker (combine with `-tab 4`) |
| `-open-look` | Opens the look picker (combine with `-tab 4`) |
| `-demo-product` | Opens the meal detail sheet with a sample product (combine with `-tab 2`) |
| `-demo-scan <code>` | Runs a barcode lookup as if scanned (combine with `-tab 2`) |
| `-seed-custom-food` | Creates a demo custom food with barcode `4041234567890` when none exists |
| `-open-custom-form` | Opens the custom food form with a prefilled barcode (combine with `-tab 2`) |
| `-demo-label` | Runs the nutrition label parser on sample OCR lines and opens the prefilled form (combine with `-tab 2`) |
| `-scroll-bottom` | Opens the diary scrolled to the bottom |
| `-seed-snapshot` | Watch app only: fakes a synced day snapshot, since no paired iPhone exists on a simulator |
| `-person-buddy` | Puts a random person buddy on the profile (code drawn, body follows weight) |

Example:

```sh
xcrun simctl launch "iPhone 17 Pro" ch.emanuell.zwaeg -seed-profile -tab 2 -demo-product
```

## Build configuration

Two switches live outside the committed spec, both optional and neither secret:

| What | Where | Effect |
|---|---|---|
| `ZWAEG_BATTLES` | `.env` (see `.env.example`), read by `make generate` | `true` merges `Config/Battles.yml`: iCloud entitlement plus the `ZWAEG_BATTLES` compilation condition. Unset counts as false, so a plain `xcodegen generate` compiles battles out entirely: no CloudKit linked, no Battles tab. |
| `DEVELOPMENT_TEAM` | `Config/Local.xcconfig` (see the `.example`) | Signs builds for a real device or the App Store. Simulator builds need no team. `Config/Signing.xcconfig` pulls it in with an optional `#include?`, so a fresh clone still generates a working project. |

Toggling `ZWAEG_BATTLES` rewrites `Zwaeg/Zwaeg.entitlements`, and Xcode rejects an entitlements file that changed under an incremental build. Run `make clean` after switching.

CI builds both settings, so the battles code stays compiled even though it is off by default.

## CloudKit setup for battles

Battles are the only feature that leaves the device. They use the **public** database of the container `iCloud.ch.emanuell.zwaeg` (see `ChallengeSyncService`). Everything else stays local: `AppModel` pins `cloudKitDatabase: .none` so SwiftData never mirrors the store.

Building battles for the simulator needs no Apple account: simulators do not enforce entitlements, so the UI and the no-iCloud paths can be developed for free. Running a real battle, on a device or through the App Store, needs a paid Apple Developer account and this one-time setup:

1. **Developer portal**: register the App ID `ch.emanuell.zwaeg`, enable the iCloud capability, and create the container `iCloud.ch.emanuell.zwaeg`.
2. **CloudKit Console** (Development environment), create two record types:

   | Record type | Fields |
   |---|---|
   | `Challenge` | `code` (String), `name` (String), `metric` (String), `startDay` (Date/Time), `endDay` (Date/Time) |
   | `Score` | `challengeCode` (String), `participantID` (String), `participantName` (String), `dayKey` (String), `value` (Double), `manual` (Int, 1 = day includes a photo-backed manual session) |

3. **Mark `Score.challengeCode` as Queryable.** Pulling a leaderboard queries on it; without the index the query fails and the battles screen shows a generic error. Record names are queryable by default, which is all `Challenge` needs.
4. **Security roles**: `_world` needs read and write on both types. Anyone holding a join code is an untrusted writer by design, so `ChallengeSyncService` sanitizes every field it reads back.
5. **Deploy Schema to Production** before shipping a release build. A build signed for production talks to the production environment, which starts out empty. Re-deploy after every field addition — `Score.manual` (added after 1.1.0) will not exist in production until then, and pushes from a release build would fail.

Testing on a simulator or device needs an iCloud account signed in under Settings. Without one the app still runs and shows the "sign in to iCloud" notice on the battles screen, which is worth checking too.

## Simulator notes

- The simulator has no camera; the scanner shows a manual barcode entry fallback. Verified test barcode: `7610036010305` (Villars chocolate).
- Battles need an iCloud account in the simulator's Settings app; without one you get the sign-in notice instead of a leaderboard.
- The Health store is empty in the simulator; steps and active energy read 0. Add samples in the simulator Health app to test the flow.
- Downloaded simulator runtimes may lack the color emoji font. The UI uses SF Symbols for anything meaningful.
- Screenshots: `xcrun simctl io "iPhone 17 Pro" screenshot out.png`

## Conventions

- German UI strings with Swiss spelling (Grösse, Mässig). Code, comments and docs in English.
- No en or em dashes in any text; use plain hyphens or rephrase.
- Design tokens live in `Core/Theme.swift`; do not hardcode colors in views unless they are one-off semantic colors.
- Commit each logical unit separately, right when it is done and verified.
