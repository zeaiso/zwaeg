#!/usr/bin/env python3
"""Fetch openly licensed recipe photos from Wikimedia Commons.

Only images under CC0, CC BY, CC BY-SA or public domain are accepted so they
can ship inside the app. Every bundled image is recorded with author, license
and source in Zwaeg/Resources/RecipeImages/credits.json and docs/IMAGE-CREDITS.md.

Usage:
  fetch_recipe_images.py search <searches.json> <workdir>
      Queries Commons for every recipe id -> search term, downloads small
      review thumbnails and writes <workdir>/candidates.json.
  fetch_recipe_images.py bundle <workdir> <selection.json> <repo-root>
      Downloads the selected candidates at 800 px, writes them to
      Zwaeg/Resources/RecipeImages/ and regenerates the credit files.
"""

import html
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "ZwaegRecipeImages/1.0 (Zwaeg iOS app; emanuell.ademi@hotmail.com)"
LICENSE_OK = re.compile(r"^(cc0|cc by(-sa)?( \d\.\d)?|public domain)", re.IGNORECASE)
CANDIDATES_PER_RECIPE = 2


def get(url):
    for attempt in range(5):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 4:
                raise
            time.sleep(10 * (attempt + 1))


def api(params):
    params = {"format": "json", **params}
    return json.loads(get(API + "?" + urllib.parse.urlencode(params)))


def strip_tags(text):
    return html.unescape(re.sub(r"<[^>]+>", "", text or "")).strip()


def search_candidates(term, width):
    data = api({
        "action": "query", "generator": "search",
        "gsrsearch": f"{term} filetype:bitmap", "gsrnamespace": 6, "gsrlimit": 8,
        "prop": "imageinfo", "iiprop": "url|mime|extmetadata", "iiurlwidth": width,
    })
    pages = sorted(data.get("query", {}).get("pages", {}).values(),
                   key=lambda p: p.get("index", 99))
    found = []
    for page in pages:
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata", {})
        license_name = meta.get("LicenseShortName", {}).get("value", "")
        if info.get("mime") != "image/jpeg" or not LICENSE_OK.match(license_name):
            continue
        found.append({
            "title": page.get("title", ""),
            "thumb": info.get("thumburl"),
            "descriptionUrl": info.get("descriptionurl"),
            "artist": strip_tags(meta.get("Artist", {}).get("value", "")) or "unknown",
            "license": license_name,
        })
        if len(found) == CANDIDATES_PER_RECIPE:
            break
    return found


def cmd_search(searches_path, workdir):
    searches = json.loads(pathlib.Path(searches_path).read_text())
    workdir = pathlib.Path(workdir)
    (workdir / "review").mkdir(parents=True, exist_ok=True)
    state = workdir / "candidates.json"
    candidates = json.loads(state.read_text()) if state.exists() else {}
    for recipe_id, term in searches.items():
        if recipe_id in candidates:
            continue
        try:
            found = search_candidates(term, 320)
            for rank, candidate in enumerate(found):
                (workdir / "review" / f"{recipe_id}__{rank}.jpg").write_bytes(get(candidate["thumb"]))
        except Exception as error:
            print(f"FAIL {recipe_id}: {error}")
            continue
        candidates[recipe_id] = found
        state.write_text(json.dumps(candidates, ensure_ascii=False, indent=1))
        print(f"{recipe_id}: {len(found)} candidates ({term})")
        time.sleep(1.2)


def cmd_bundle(workdir, selection_path, repo_root):
    workdir, repo = pathlib.Path(workdir), pathlib.Path(repo_root)
    candidates = json.loads((workdir / "candidates.json").read_text())
    selection = json.loads(pathlib.Path(selection_path).read_text())
    image_dir = repo / "Zwaeg/Resources/RecipeImages"
    image_dir.mkdir(parents=True, exist_ok=True)
    credits = []
    for recipe_id, rank in sorted(selection.items()):
        candidate = candidates[recipe_id][rank]
        data = None
        for width in (800, 640, 320):
            try:
                data = get(candidate["thumb"].replace("/320px-", f"/{width}px-"))
                break
            except Exception:
                continue
        if data is None:
            print(f"FAIL {recipe_id}")
            continue
        (image_dir / f"recipe-{recipe_id}.jpg").write_bytes(data)
        credits.append({
            "id": recipe_id,
            "title": candidate["title"].removeprefix("File:"),
            "artist": candidate["artist"],
            "license": candidate["license"],
            "source": candidate["descriptionUrl"],
        })
        print(f"bundled {recipe_id} ({candidate['license']})")
        time.sleep(0.3)
    (image_dir / "credits.json").write_text(json.dumps(credits, ensure_ascii=False, indent=1) + "\n")

    lines = ["# Image credits", "",
             "Recipe photos come from Wikimedia Commons and are used under their",
             "respective free licenses. Fetched with scripts/fetch_recipe_images.py.", ""]
    for entry in credits:
        lines.append(f"- **{entry['title']}** by {entry['artist']}, "
                     f"{entry['license']}, [source]({entry['source']})")
    (repo / "docs/IMAGE-CREDITS.md").write_text("\n".join(lines) + "\n")
    print(f"\n{len(credits)} images, credits written to docs/IMAGE-CREDITS.md")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "search":
        cmd_search(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 2 and sys.argv[1] == "bundle":
        cmd_bundle(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print(__doc__)
        sys.exit(1)
