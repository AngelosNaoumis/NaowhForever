"""Build Tools/data/foreverchanges_loot.json: the boss drops ForeverChanges' players have seen in
game, which Tools/build/journal.py places on the Dungeon Journal's bosses.

ForeverChanges lists each dungeon on /dungeons (its status "new" for one new in Forever) and, on
its page (/dungeons/<id>), each boss's drops, marking (w) the ones seen in game. On a classic
dungeon who drops what is Classic's: a mark on a Classic item there only says its Forever version
has been seen, so only the items new in Forever (t "new") are taken. On a dungeon new in Forever
every seen drop is. A page's other items are Classic's tables or not seen yet, and are left out.

Kept per page: its name, the date its drops are seen as of, and each boss with a seen drop (its
kind: boss, rare, quest, object or trash) and those drops. The file is written only when the drops
changed, so a new date alone changes nothing. The pages are read one at a time, a second apart.

--report FILE writes the drops gained and lost since the file was written, in Markdown, for the
daily watch (.github/workflows/daily-watch.yml).

Usage: python Tools/build/foreverchanges_loot.py [--report FILE]
"""
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
from foreverchanges_recipes import GAP, SITE, fetch, listed, page_data  # noqa: E402

OUT = paths.DATA / "foreverchanges_loot.json"
AS_OF = re.compile(r"Drops seen in game are as of (\d{4}-\d{2}-\d{2})")
REPORT_ROWS = 50   # drops named per list in the report; the rest are counted


def parse(page, new_dungeon):
    """A dungeon page's seen drops: {"seen": its date, "bosses": [{name, kind, items: [{id, name}]}]};
    no bosses on a page for a dungeon not out yet."""
    data = page_data(page)
    bosses = []
    for boss in listed(data, "bosses") or []:
        items = [{"id": i["i"], "name": i["n"]} for i in boss["items"]
                 if i.get("w") and (new_dungeon or i.get("t") == "new")]
        if items:
            bosses.append({"name": boss["name"], "kind": boss["kind"], "items": items})
    date = AS_OF.search(data)
    return {"seen": date.group(1) if date else None, "bosses": bosses}


def read():
    """{page id: {name, seen, bosses}} for every dungeon on ForeverChanges' dungeons page."""
    dungeons = listed(page_data(fetch(f"{SITE}/dungeons")), "dungeons")
    if not dungeons:
        raise ValueError("no dungeons on ForeverChanges' dungeons page")
    pages = {}
    for dungeon in dungeons:
        time.sleep(GAP)
        page = parse(fetch(f"{SITE}/dungeons/{dungeon['id']}"), dungeon.get("status") == "new")
        pages[dungeon["id"]] = dict(page, name=dungeon["name"])
    return pages


def drops(pages):
    """(page name, boss, item ID) -> item name, for every drop the pages have seen."""
    return {(page["name"], boss["name"], item["id"]): item["name"]
            for page in pages.values() for boss in page["bosses"] for item in boss["items"]}


def changes(old, new):
    """[("New", rows), ("Gone", rows)]: the drops new has seen that old had not, and old's that new
    no longer lists, a row each; both empty when the drops are the same."""
    before, after = drops(old), drops(new)
    return [(title, [f"- {page} / {boss}: {names[(page, boss, item)]} ({item})"
                     for page, boss, item in sorted(keys)])
            for title, keys, names in (("New", after.keys() - before.keys(), after),
                                       ("Gone", before.keys() - after.keys(), before))]


def report(pages, found):
    """The drops seen and what changed, in Markdown."""
    total = sum(len(boss["items"]) for page in pages.values() for boss in page["bosses"])
    counts = ", ".join(f"{len(rows)} {title.lower()}" for title, rows in found)
    lines = ["### ForeverChanges' seen drops", "", f"{SITE}/dungeons lists {total} drops seen in game: {counts}."]
    for title, rows in found:
        if not rows:
            continue
        lines += ["", f"**{title}:**", ""] + rows[:REPORT_ROWS]
        if len(rows) > REPORT_ROWS:
            lines.append(f"- and {len(rows) - REPORT_ROWS} more")
    return "\n".join(lines) + "\n"


def main():
    report_to = sys.argv[sys.argv.index("--report") + 1] if "--report" in sys.argv else None
    old = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    new = read()
    found = changes(old, new)
    if any(rows for _, rows in found):
        OUT.write_text(json.dumps(new, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    text = report(new, found)
    if report_to:
        Path(report_to).write_text(text, encoding="utf-8")
    else:
        print(text)


if __name__ == "__main__":
    main()
