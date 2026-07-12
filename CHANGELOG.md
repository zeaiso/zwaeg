# Changelog

All notable changes to Zwäg are documented here.

## 0.0.1 (unreleased)

The first public release. Everything below ships together, waiting only for
the Apple developer account approval.

### Diary and food
- Diary with daily calorie budget, calorie ring, macro bars, four meals and offline Swiss food search
- Barcode scanner (VisionKit) with Open Food Facts lookup and manual entry fallback
- Custom foods with values per 100 g and optional barcode, reusable in search and found by the scanner offline
- Official Swiss Food Composition Database V7.0 (BLV) bundled for offline search, 1220 foods with synonyms
- Meal detail sheet with portion chips, macro tiles and per-meal add button
- "Like yesterday" quick copy for empty meals, favorites and recently logged products
- Calendar day switcher, day details with balance, macro comparison and logged foods
- Streak card with milestone banners and confetti

### Recipes
- 200+ healthy recipes with real photos, Swiss classics in light versions included
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
- Battles with friends via 6-character join codes, live leaderboard, CloudKit sync layer prepared
- Endless challenge ladders with "now" and "done" tabs
- Points unlock studio looks (neon hair, extras, pirate and ninja sets)

### Everyday tracking
- Water goal (2 liters as 8 glasses, configurable) with glass grid and reminders
- Weight quick log with automatic calorie target recalculation and 7-day chart
- Daily mood with history
- Reminders for meals and water at custom times
- Calculators: BMI, ideal weight, calorie needs, calorie burn
- Apple Health integration: steps, active energy, weight sync

### Platform
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
- Debug launch arguments compiled out of release builds
