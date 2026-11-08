"""Build the Training Planner's demon books: the grimoires a warlock buys for each demon.

A demon book is an item whose use spell (ItemXItemEffect -> ItemEffect.SpellID) has a Learn Spell
effect (SpellEffect Effect 36) aimed at the pet (ImplicitTarget 5), teaching a spell that
SkillLineAbility files under a demon's own skill line (the first SkillLine of its CreatureFamily: Imp
188, Voidwalker 204, Succubus and Incubus 205, Felhunter 189), and that a warlock may use (ItemSparse
AllowableClass). That leaves out the old "Grimoire of ..." items the tables still have, which teach the
warlock (target 1) or a spell no skill line has (Blood Boil, Mind Bomb). Each book's level and price
are the item's own (ItemSparse RequiredLevel and BuyPrice), and the rank it teaches over is the taught
spell's SupercedesSpell.

Which books a demon trainer stocks, and at what price, the server decides; the game's tables are all
we have, so every book they list is kept at its BuyPrice.

Writes NaowhForever_Training/Data/TrainingGrimoires.lua.

Usage: python Tools/build/training_grimoires.py [--build 1.60.1.70862]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import wago  # noqa: E402
from journal import ROOT, header, write  # noqa: E402

OUT = ROOT / "NaowhForever_Training" / "Data" / "TrainingGrimoires.lua"
LEARN_SPELL = "36"   # SpellEffect's Effect for teaching a spell
PET = "5"            # ImplicitTarget for the caster's pet
WARLOCK = 9


def demons(families):
    """Skill line -> the CreatureFamily rows whose own (first) skill line it is, by ID."""
    out = {}
    for row in sorted(families, key=lambda r: int(r["ID"])):
        if int(row["SkillLine_0"] or 0):
            out.setdefault(int(row["SkillLine_0"]), []).append(row)
    return out


def grimoires(sparse, item_effects, effects, spell_effects, abilities, families):
    """The demons that have books, in the order a warlock meets them (by first book's level): each
    {line, name, families, books}, its books {level, spell, cost, item, needs} in level order."""
    lines = demons(families)
    use = {}
    for row in effects:
        use[row["ID"]] = row["SpellID"]
    taught = {}
    for row in spell_effects:
        if row["Effect"] == LEARN_SPELL and row["ImplicitTarget_0"] == PET and int(row["EffectTriggerSpell"] or 0):
            taught.setdefault(row["SpellID"], int(row["EffectTriggerSpell"]))
    line_of, before = {}, {}
    for row in abilities:
        if int(row["SkillLine"]) in lines:
            line_of[int(row["Spell"])] = int(row["SkillLine"])
            before[int(row["Spell"])] = int(row["SupercedesSpell"] or 0)
    items = {row["ID"]: row for row in sparse}
    books = {}
    for row in item_effects:
        spell = taught.get(use.get(row["ItemEffectID"]))
        item = items.get(row["ItemID"])
        if not spell or spell not in line_of or not item:
            continue
        if not int(item["AllowableClass"]) >> (WARLOCK - 1) & 1:
            continue
        books.setdefault(line_of[spell], []).append({
            "level": int(item["RequiredLevel"]), "spell": spell, "cost": int(item["BuyPrice"]),
            "item": int(row["ItemID"]), "needs": before[spell]})
    out = []
    for line, rows in books.items():
        rows.sort(key=lambda b: (b["level"], b["spell"]))
        out.append({"line": line, "name": " or ".join(f["Name_lang"] for f in lines[line]),
                    "families": [int(f["ID"]) for f in lines[line]], "books": rows})
    out.sort(key=lambda d: (d["books"][0]["level"], d["line"]))
    return out


def build(build_id):
    found = grimoires(wago.table("ItemSparse", build_id), wago.table("ItemXItemEffect", build_id),
                      wago.table("ItemEffect", build_id), wago.table("SpellEffect", build_id),
                      wago.table("SkillLineAbility", build_id), wago.table("CreatureFamily", build_id))
    out = header("TrainingGrimoires.lua", f"the books each warlock demon learns from, built from game build {build_id}")
    out.append("ns.TrainingGrimoires = {")
    for demon in found:
        families = ", ".join(map(str, demon["families"]))
        out.append(f"    {{ line = {demon['line']}, name = \"{demon['name']}\", families = {{ {families} }}, books = {{")
        for b in demon["books"]:
            needs = f", needs = {b['needs']}" if b["needs"] else ""
            out.append(f"        {{ {b['level']}, {b['spell']}, {b['cost']}, item = {b['item']}{needs} }},")
        out.append("    } },")
    out.append("}")
    write(OUT, out)
    print(f"Wrote {OUT.relative_to(ROOT)}: " + ", ".join(f"{d['name']} {len(d['books'])}" for d in found))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--build", default=wago.BUILD, help="the Forever build to read (default: wago.BUILD)")
    build(parser.parse_args().build)


if __name__ == "__main__":
    main()
