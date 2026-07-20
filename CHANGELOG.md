# Changelog

All notable changes to Zwäg are documented here. This project follows
[semantic versioning](https://semver.org): patch releases fix bugs, minor
releases add features, and anything that changes behaviour is noted.

## 1.2.0 (2026-07-20)

Fair battles with photo proof, routes from Apple Health, recipes in every
language — plus a tappable water widget, a weekly review and achievement
badges.

- Water widget you can tap. A new home screen widget shows today's glasses
  as a drop grid and logs a glass directly from the home screen — without
  opening the app. Glasses tapped while the app is closed are folded into
  the diary the next time it opens, day-accurate even across midnight.
- Wochenrückblick. The progress screen opens the week in review: days in
  the calorie target, averages for calories and water, the weight change,
  the best day — with a share card rendered as an image. An optional
  reminder delivers it Sunday evening (new card on the reminders screen).
  On Sundays the review covers the running week, otherwise the last
  completed one; weeks always run Monday to Sunday.
- Erfolge. Fourteen achievement badges on the profile, all derived from
  data already on the device: first entry, 100/500 entries, week / month /
  100-day streaks, fasting windows, a water week, progress photo,
  weigh-ins, own foods, recipe favorites and the first battle. Unlock
  dates persist, so a badge survives a broken streak; fresh unlocks get
  confetti.
- The iPad home screen no longer warns about alternate icons: Midnight and
  Mono ship in the 152/167px sizes iPads want (ITMS-90892).
- Meine Routen: walks, runs and hikes recorded with Apple Watch or the
  Workout app appear on the progress screen as map tiles, with a full-screen
  route view behind each. Zwäg only reads what Health already stored —
  it never tracks location itself, and routes stay on the device.
- Proof photos are visible to the battle. Tapping a participant's camera
  badge opens their Foto-Belege: every manual session's photo with capture
  time, distance and steps. Proofs must be shot live with the camera, the
  same picture can't be used twice (perceptual hash), and any member can
  raise an Einspruch — objects more than half of the others, the day's
  manual steps are revoked from everyone's leaderboard. The privacy label
  gains Photos (battle-shared user content).
- Recipes translate themselves. In a non-German app language, the recipe
  page offers "Auf … übersetzen": Apple's on-device translation converts
  name, ingredients and steps (nothing leaves the device), the result is
  cached per language, and a toggle switches back to the original. Where
  Apple can't produce the app language (Danish, Swedish, ...), an English
  translation is offered instead; on iOS 17 an honest note says recipes
  are currently German.
- Online food search got serious. It now fetches up to 24 results instead
  of 6, searches in the app language plus English (with localized product
  names), and zero-calorie products like Cola Zero appear — only entries
  whose nutrition table was never filled in are dropped.
- Battle roles for leaving and ending. "Battle verlassen" removes you from
  the others' leaderboards (your scores, proofs and objections are deleted
  from the cloud), and the creator additionally gets "Battle für alle
  beenden", which deletes the battle for every participant — their apps
  show it as ended on the next refresh. The routes card now also explains
  how to get a first route when none exists yet.
- The manual-training camera badge now actually reaches opponents: score
  records carry a manual flag through CloudKit (schema field Score.manual,
  deploy before release). Battles can be deleted from the detail screen
  (removes them from this device only), and the floating tab bar hides on
  the battle detail like on recipe pages.
- "Persönliche Daten" and "Mein Buddy" merge into one profile row with
  Daten/Buddy tabs — one entry less in the profile list.
- "Was passt heute noch?" — from 11:00, the diary suggests up to three
  recipes that fit the remaining calorie budget, leaning high-protein while
  the protein target is far away. Tapping opens the recipe; the picks stay
  stable for the day.
- Logged meals mirror into Apple Health as dietary energy, protein, carbs
  and fat (daily totals, replaced on every edit). Existing Health
  connections get the additional write permission sheet once.
- Custom macro split. "Ziele & Vorgaben" gains a Makro-Verteilung section
  with presets (Ausgewogen, High-Protein, Low-Carb, Keto) and custom
  percent steppers; the diary's macro bars follow.
- Step battles can't be cheated from the Health app anymore. Battle scores
  now ignore values typed by hand into Apple Health (device-measured steps
  and active calories are unaffected) — quietly, per HealthKit's
  wasUserEntered flag. A note in the battle explains the rule.
- Treadmill sessions join the battle with photo proof. "Training nachtragen"
  in a step battle takes a distance and requires a photo of the machine's
  display; the photo stays on the device, the converted steps (≈1300/km)
  count toward the day, and everyone in the battle sees a camera badge on
  participants with hand-added days. Several sessions per day are fine
  (morning and evening run, up to six) — each needs its own photo.

## 1.1.0 (2026-07-18)

The first feature release, shaped by the first days of real-world use:
faster food logging, a streak that forgives a missed day, and progress you
can see. Everything stays local first.

### Scanner and food logging
- Photo food recognition. A third "Foto" mode in the scanner photographs the
  plate, classifies it on device with Apple's built-in Vision taxonomy (no
  bundled model, the photo never leaves the device) and offers the
  recognized foods as tappable chips that resolve to entries of the bundled
  Swiss Food Composition Database and open the normal portion sheet. Strong
  on single whole foods (fruit, vegetables, common dishes), weaker on mixed
  plates.
- Portion sheet units: a dropdown switches between Portionen, Gramm and
  Stück. Gram mode has a type-anything field (number pad with a Fertig
  button, so the keyboard always dismisses) plus quick chips for 50 to 300 g;
  Stück counts whole pieces; switching units carries the chosen amount over,
  and the last used unit is remembered. Foods recognized by photo carry a
  typical piece weight (an apple counts as 130 g, an egg as 60 g), so
  "2 Stück" means two pieces instead of a flat 200 g.
- Food search also asks Open Food Facts. Typing three or more letters
  searches the online database alongside the offline results (debounced, via
  the Search-a-licious API), so branded products like a Kaffee Latte appear
  by name without scanning. Results without nutrition values are dropped, and
  a product you open joins the offline cache like a scanned barcode.
- Own foods ("Meine Lebensmittel") show a visible delete button instead of
  the hidden long-press menu, also when they appear in search results.

### Streak and progress
- Streak freezes, Duolingo-style. Every seventh logged day banks a freeze (at
  most two at once) and a missed day automatically spends one, so the streak
  survives the gap. The diary header shows the banked freezes next to the
  flame, and a "Streak gerettet!" banner appears when a freeze just bridged
  yesterday. Freezes are only spent when they actually reach the next logged
  day — a gap too wide to close wastes nothing — and backfilling a bridged
  day refunds its freeze.
- Streak widget for the home screen: flame, day count and banked freezes,
  with a small lock screen variant. The flame greys out until something is
  logged today. Updates whenever the diary changes, like the day-ring widget.
- Progress photos replace the morphing body buddy on the progress screen.
  Add a photo of yourself each week (stored only on the device, never
  synced); the card shows your first and newest photo side by side with the
  logged weight at the time, every photo has a delete button, and a gentle
  badge appears when the newest photo is over a week old.

### Plan and reminders
- Choose your meals. "Ziele & Vorgaben" gets a Mahlzeiten section: turn off
  the meals you don't eat (all calories at lunch, lunch and dinner only, no
  snacks, ...) and they disappear from the diary and the meal pickers, while
  the daily calorie budget redistributes over the meals you kept. A disabled
  meal that still holds logged entries stays visible for that day, meal
  reminders only fire for meals you eat, and at least one meal always stays
  on.
- Fasting start reminder. A third card on the reminders screen sends a daily
  notification when the fasting window begins (default 20:00, freely
  configurable), alongside the existing water and meal reminders. Reminder
  times stored by earlier versions carry over unchanged.
- Weekly weigh-in reminder: a fourth card on the reminders screen with a
  weekday picker and time, so the scale becomes a Monday-morning habit.

### Fixes and languages
- Removed the free-text note on the "Wie war dein Tag?" mood card for now. The
  keyboard could not be dismissed after typing, so text entry is disabled until
  the input works properly. Picking a daily mood still works, and notes that
  were already saved stay on the device.
- Every new string ships in all 23 app languages.

## 1.0.0 (2026-07-16)

The first public release on the App Store. Local first: all personal data
stays on the device.

Build 2 was rejected by App Review (Guideline 1.4.1: health calculations
need citations), so 1.0.0 ships as build 4. The builds since the first
submission added the source citations plus hardening from a security and
correctness audit — nothing user-facing changed beyond that.

### Sources and hardening (builds 3-4)
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
