#!/usr/bin/env python3
"""One-time batch translation of the bundled recipes into the app languages.

Produces Zwaeg/Resources/RecipeTranslations/<lang>.json in exactly the
TranslatedRecipe format the app reads ({id: {name, ingredients, steps}}),
so bundled translations show instantly in every language — including the
ones Apple's on-device translation can't produce (da, sv, nb, sq, sr, hr,
bs, fa, ta, ti).

Usage:
    GOOGLE_TRANSLATE_KEY=... python3 scripts/translate_recipes.py [lang ...]

Without language arguments, all 20 non-German app languages are generated.
Cost: Google Cloud Translation v2 charges per character; the whole recipe
corpus is ~350k characters, so expect roughly $7 per language.

Caveats:
- sr comes back in Cyrillic script (the app otherwise uses Latin Serbian).
- Quantities like "60 g" survive translation untouched in practice, but
  spot-check a handful of recipes per language before shipping.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECIPES = ROOT / "Zwaeg" / "Resources" / "Recipes"
OUT = ROOT / "Zwaeg" / "Resources" / "RecipeTranslations"

# App language -> Google Translate code.
LANGUAGES = {
    "en": "en", "fr": "fr", "it": "it", "es": "es", "pt": "pt", "nl": "nl",
    "da": "da", "nb": "no", "sv": "sv", "pl": "pl", "tr": "tr", "sq": "sq",
    "sr": "sr", "hr": "hr", "bs": "bs", "uk": "uk", "ar": "ar", "fa": "fa",
    "ta": "ta", "ti": "ti",
}

BATCH = 100  # strings per API call (limit is 128)


def load_recipes():
    recipes = []
    for file in sorted(RECIPES.glob("*.json")):
        recipes.extend(json.loads(file.read_text()))
    return recipes


def translate_batch(texts, target, key):
    body = urllib.parse.urlencode(
        [("q", t) for t in texts]
        + [("source", "de"), ("target", target), ("format", "text"), ("key", key)]
    ).encode()
    request = urllib.request.Request(
        "https://translation.googleapis.com/language/translate/v2", data=body)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = json.load(response)
            return [item["translatedText"]
                    for item in payload["data"]["translations"]]
        except Exception as error:  # noqa: BLE001 - retry then re-raise
            if attempt == 3:
                raise
            print(f"  retry after error: {error}")
            time.sleep(3 * (attempt + 1))


def translate_language(app_lang, google_lang, recipes, key):
    texts, spans = [], []
    for recipe in recipes:
        start = len(texts)
        texts.append(recipe["name"])
        texts.extend(recipe["ingredients"])
        texts.extend(recipe["steps"])
        spans.append((recipe["id"], start,
                      len(recipe["ingredients"]), len(recipe["steps"])))

    translated = []
    for offset in range(0, len(texts), BATCH):
        translated.extend(translate_batch(texts[offset:offset + BATCH],
                                          google_lang, key))
        print(f"  {min(offset + BATCH, len(texts))}/{len(texts)}")

    table = {}
    for recipe_id, start, ingredient_count, step_count in spans:
        table[recipe_id] = {
            "name": translated[start],
            "ingredients": translated[start + 1:start + 1 + ingredient_count],
            "steps": translated[start + 1 + ingredient_count:
                                start + 1 + ingredient_count + step_count],
        }
    OUT.mkdir(exist_ok=True)
    out_file = OUT / f"recipes-{app_lang}.json"
    out_file.write_text(json.dumps(table, ensure_ascii=False, indent=1))
    print(f"  wrote {out_file.relative_to(ROOT)} ({len(table)} recipes)")


def main():
    key = os.environ.get("GOOGLE_TRANSLATE_KEY")
    if not key:
        sys.exit("Set GOOGLE_TRANSLATE_KEY (Google Cloud Translation API key).")
    wanted = sys.argv[1:] or list(LANGUAGES)
    recipes = load_recipes()
    characters = sum(len(t) for r in recipes
                     for t in [r["name"], *r["ingredients"], *r["steps"]])
    print(f"{len(recipes)} recipes, ~{characters:,} characters per language")
    for app_lang in wanted:
        google_lang = LANGUAGES.get(app_lang)
        if not google_lang:
            print(f"skipping unknown language {app_lang}")
            continue
        print(f"translating to {app_lang} ...")
        translate_language(app_lang, google_lang, recipes, key)


if __name__ == "__main__":
    main()
