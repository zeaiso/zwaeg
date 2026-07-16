# Changelog

All notable changes to Zwäg are documented here. This project follows
[semantic versioning](https://semver.org): patch releases fix bugs, minor
releases add features, and anything that changes behaviour is noted.

## 1.0.0 (2026-07-16)

The first public release on the App Store. Local first: all personal data
stays on the device.

Build 2 was rejected by App Review (Guideline 1.4.1: health calculations
need citations), so 1.0.0 ships as build 3. The builds since the first
submission added the source citations plus hardening from a security and
correctness audit — nothing user-facing changed beyond that.

### Sources and hardening (build 3)
- Citations for all health calculations, as App Review (Guideline 1.4.1) requires for medical information. Each calculator (BMI, calorie needs, ideal weight, activity burn) shows a "Sources" card linking the scientific reference behind its formula — WHO for the BMI classification, Mifflin-St Jeor (1990) and FAO/WHO/UNU (2004) for the calorie goal, Pai & Paloucek (2000) for the ideal-weight formulas and the Compendium of Physical Activities (2011) for MET values — plus a "guide values, not medical advice" note. The onboarding result and the Help & Support screen cite the same sources. Translated into all 23 app languages.
- Cap the battle leaderboard at 50 participants and stop paging once it is full. The scores live in a shared CloudKit database that anyone with the join code can write to, so an unbounded roster let a hostile code holder flood a challenge with fake participants until the app ran out of memory.
- Fix a crash when a food's serving size was not a normal number. Calorie and macro values were already clamped, but the serving size was not: a malformed Open Food Facts `serving_quantity`, or a very large number typed into the custom-food portion field, could reach the calorie calculation as an infinite or out-of-range value and crash the app. Serving size is now bounded at every source and at the point of use.
- Open Food Facts attribution now names its licence (Open Database License, ODbL), and the lookup request identifies the app version and a contact URL, as the Open Food Facts terms ask.
- The privacy manifest now also declares the anonymous per-install ID and user-typed challenge names shared by battles, so it lists the same data types as the App Store privacy label.

### Diary and food
- Diary with daily calorie budget, calorie ring, macro bars, four meals and offline Swiss food search
- Barcode scanner (VisionKit) with Open Food Facts lookup and manual entry fallback
- Custom foods with values per 100 g and optional barcode, reusable in search and found by the scanner offline
- Sugar, salt and fiber from Open Food Facts, shown on the portion sheet and summed in the day details
- Official Swiss Food Composition Database V7.0 (BLV) bundled for offline search, 1220 foods with synonyms
- Meal detail sheet with portion chips, macro tiles and per-meal add button
- "Like yesterday" quick copy for empty meals, favorites and recently logged products
- Calendar day switcher, day details with balance, macro comparison and logged foods
- Streak card with milestone banners and confetti

### Recipes
- 890 recipes across Swiss classics and international cuisines, with real photos
- Discover page with categories, calorie ranges and diet filters
- Recipe pages with nutrition facts per serving and a servings stepper that scales ingredients
- Shopping list with one-tap ingredient import and check-off
- Photo credits shown in the app; sources listed in docs/IMAGE-CREDITS.md

### Fasting
- Nine fasting plans from 12:12 to 23:1 in three levels
- Live fasting stages on the ring, from blood sugar to autophagy
- Editable start time, weekly stats, history and end-of-fast notification

### Buddy
- Buddy mascots: blob set, 500 funky avatars, classic wardrobe studio and saved looks closet
- Avatar studio with nine DiceBear styles, localized option names and pinned preview
- Own photo from the library as buddy
- Full-body buddy on the activity screen whose belly follows the BMI
- Reactive poses in the diary header and fasting ring

### Battles and challenges
- Battles with friends over steps, active calories or calorie deficit; share a 6-character join code, scores sync over CloudKit's public database, linked only by the code
- Battles are opt-in at build time; the App Store build ships with them on
- Endless challenge ladders with "now" and "done" tabs
- Points unlock studio looks (neon hair, extras, pirate and ninja sets)

### Everyday tracking
- Water goal (2 liters as 8 glasses, configurable) with glass grid and reminders
- Weight quick log with automatic calorie target recalculation and 7-day chart
- Week balance card on the activity screen: days on target, calorie balance, water and protein averages
- Daily mood with history
- Reminders for meals and water at custom times
- Calculators: BMI, ideal weight, calorie needs, calorie burn
- Apple Health integration: steps, active energy, weight sync

### Platform
- Universal app: iPhone and iPad
- Apple Watch app with day ring, water logging and complications
- Home screen and lock screen widgets
- Siri shortcuts for logging water and asking for remaining calories
- Live Activity with the fasting countdown in the Dynamic Island

### Languages and looks
- 23 languages including Swiss German and Romansh, language choice at first start
- Right-to-left layout for Arabic and Farsi
- Three looks (Munch, Midnight, Mono) with custom accent color and matching app icons
- Onboarding with one question per screen and typed number inputs

### Privacy
- Local first: all personal data stays on the device, no account, no ads, no subscription
- SwiftData never mirrors to iCloud; only battles leave the device, and only a display name and daily totals, keyed to a random per-install ID
- Debug launch arguments compiled out of release builds
