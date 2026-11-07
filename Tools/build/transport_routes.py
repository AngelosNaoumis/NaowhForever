"""Builds NaowhForever_QoL/Travel/TransportRoutes.lua: the boats and zeppelins NauticusClassic timed.

Run from the repo root with NauticusClassicResurrected's data.lua (MIT, psynct's NauticusClassic with the
Forever ships added, github.com/sam-k-taylor/NauticusClassicResurrected, commit
efabdb82d11c771e0acac2deb562caba9908e0e5):

    python Tools/build/transport_routes.py path/to/NauticusClassicResurrected/data.lua

Each route keeps its measured round trip, each dock's arrival and departure in its cycle, and the
trigger segments a rider passes. NauticusClassic stores places on the whole-world map; they are turned
into world yards by a fit per continent on the docks it shares with TransportData.lua. Points tagged
rawp are already world yards on their own continent, with x and y the other way round from ours.
"""

import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402

# NauticusClassic's transport id, the ship's name, then each dock in the order of its plat tags: the
# TransportData stop and the place. The Forever ships are unnamed in the data, so their docks name them.
ROUTES = [
    (1, "The Thundercaller", [("1411:Zeppelin to Undercity", "Orgrimmar"), ("1420:Zeppelin to Orgrimmar", "Undercity")]),
    (2, "The Iron Eagle", [("1411:Zeppelin to Grom'gol", "Orgrimmar"), ("1434:Zeppelin to Orgrimmar", "Grom'gol")]),
    (3, "The Purple Princess", [("1420:Zeppelin to Grom'gol", "Undercity"), ("1434:Zeppelin to Undercity", "Grom'gol")]),
    (4, "The Maiden's Fancy", [("1413:Boat to Booty Bay", "Ratchet"), ("1434:Boat to Ratchet", "Booty Bay")]),
    (5, "The Bravery", [("1437:Boat to Southshore", "Menethil Harbor"), ("1424:Boat to Auberdine", "Southshore"),
                        ("1439:Boat to Menethil Harbor", "Auberdine")]),
    (6, "The Lady Mehley", [("1437:Boat to Theramore", "Menethil Harbor"), ("1445:Boat to Menethil Harbor", "Theramore")]),
    (7, "The Moonspray", [("1438:Boat to Auberdine", "Rut'theran Village"),
                          ("1439:Boat to Rut'theran Village", "Auberdine")]),
    (8, "Feathermoon Ferry", [("1444:Boat to the Feralas coast", "Feathermoon Stronghold"),
                              ("1444:Boat to Feathermoon Stronghold", "The Forgotten Coast")]),
    (11, "Stormwind Harbor - Auberdine", [("1453:Boat to Auberdine", "Stormwind Harbor"),
                                          ("1439:Boat to Stormwind Harbor", "Auberdine")]),
    (12, "Zephras Isle - Mulgore", [("2521:Zeppelin to Mulgore", "Windshapers Dock"),
                                    ("1412:Zeppelin to Zephras Isle", "Skywatch Plateau")]),
    (13, "Zephras Isle - Dalaran", [("2521:Zeppelin to Dalaran", "High Order Dock"),
                                    ("1416:Zeppelin to Zephras Isle", "Dalaran")]),
    (14, "Powderfuse Port - Steamwheedle Port", [("2548:Boat to Steamwheedle Port", "Powderfuse Port"),
                                                 ("1446:Boat to Powderfuse Port", "Steamwheedle Port")]),
]
# NauticusClassic's whole-world map holds Kalimdor left of the middle and the Eastern Kingdoms right of it.
KALIMDOR, EASTERN_KINGDOMS, MIDDLE = 1, 0, 0.5
MAX_DOCK_MISS = 20

OUTPUT = paths.ROOT / "NaowhForever_QoL" / "Travel" / "TransportRoutes.lua"
STOPS = paths.ROOT / "NaowhForever_QoL" / "Travel" / "TransportData.lua"


def section(text, name):
    start = text.index(f"NauticusClassic.{name} = {{")
    return text[start:text.index("\n}", start)]


def packed(text, name, end=None):
    start = text.index(f"NauticusClassic.{name} = {{")
    body = text[start:text.index(f"NauticusClassic.{end} = {{", start)] if end else text[start:]
    blocks = re.split(r"^\s*\[(\d+)\] = \{", body, flags=re.M)[1:]
    return {int(blocks[i]): re.findall(r'^\s*"([^"]+)"', blocks[i + 1], re.M) for i in range(0, len(blocks), 2)}


def read_routes(text):
    rtts = [float(v) for v in re.findall(r"^\s*([0-9.]+), -- \[\d+\]", section(text, "rtts"), re.M)]
    for tid, rtt in re.findall(r"^\s*\[(\d+)\] = ([0-9.]+),", section(text, "rtts_forever"), re.M):
        rtts[int(tid) - 1] = float(rtt)
    raw = {int(tid): int(cont) for tid, cont in re.findall(r"^\[(\d+)\] = (\d+),", section(text, "rawInstance"), re.M)}
    data = packed(text, "packedData")
    data.update({tid: rows for tid, rows in packed(text, "packedData_forever", "packedData").items() if rows})
    routes = {}
    for tid, lines in data.items():
        rows, x, y, offset = [], 0.0, 0.0, 0.0
        for line in lines:
            fields = line.split(":")
            x, y = x + float(fields[0]), y + float(fields[1])
            offset += float(fields[2])
            rows.append({"x": x, "y": y, "dt": float(fields[2]), "offset": offset, "tags": fields[5:]})
        routes[tid] = {"period": rtts[tid - 1], "rows": rows, "raw": raw.get(tid)}
    return routes


def read_stops(text):
    stops = {}
    for key, cont, x, y in re.findall(r'\["([^"]+)"\] = \{ map = \d+, continent = (\d+), x = ([-0-9.]+), y = ([-0-9.]+)',
                                      text):
        stops[key] = (int(cont), float(x), float(y))
    return stops


def side(u):
    return KALIMDOR if u < MIDDLE else EASTERN_KINGDOMS


def solve(points, pick):
    """Least squares for world = a * u + b * v + c over (u, v) -> world points."""
    rows = [(u, v, 1.0) for (u, v), _ in points]
    targets = [pick(world) for _, world in points]
    m = [[sum(r[i] * r[j] for r in rows) for j in range(3)] for i in range(3)]
    b = [sum(r[i] * t for r, t in zip(rows, targets)) for i in range(3)]
    for c in range(3):
        pivot = max(range(c, 3), key=lambda r: abs(m[r][c]))
        m[c], m[pivot], b[c], b[pivot] = m[pivot], m[c], b[pivot], b[c]
        for r in range(3):
            if r != c:
                f = m[r][c] / m[c][c]
                m[r] = [m[r][k] - f * m[c][k] for k in range(3)]
                b[r] -= f * b[c]
    return [b[i] / m[i][i] for i in range(3)]


def dock_rows(route, count):
    found = {}
    for index, row in enumerate(route["rows"]):
        for tag in row["tags"]:
            if tag.startswith("plat"):
                found[int(tag[4:])] = index
    assert sorted(found) == list(range(1, count + 1)), f"plat tags {sorted(found)} for {count} docks"
    return [found[n] for n in range(1, count + 1)]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    routes = read_routes(open(sys.argv[1], encoding="utf-8-sig").read())
    stops = read_stops(STOPS.read_text(encoding="utf-8"))

    def is_raw(route, row):
        return "rawp" in row["tags"]

    pairs = {KALIMDOR: [], EASTERN_KINGDOMS: []}
    for tid, _, docks in ROUTES:
        route = routes[tid]
        for row_index, (key, _) in zip(dock_rows(route, len(docks)), docks):
            row = route["rows"][row_index]
            if not is_raw(route, row):
                cont, x, y = stops[key]
                assert side(row["x"]) == cont, f"{key} is on the other continent in NauticusClassic"
                pairs[cont].append(((row["x"], row["y"]), (x, y)))
    fits = {cont: (solve(p, lambda w: w[0]), solve(p, lambda w: w[1])) for cont, p in pairs.items()}

    def world(route, row):
        if is_raw(route, row):
            return route["raw"], row["y"], row["x"]
        cont = side(row["x"])
        fx, fy = fits[cont]
        u, v = row["x"], row["y"]
        return cont, fx[0] * u + fx[1] * v + fx[2], fy[0] * u + fy[1] * v + fy[2]

    lines = [
        "-- TransportRoutes.lua: the ships NauticusClassic timed (MIT, psynct), generated by Tools/build/transport_routes.py.",
        "local ns = _G.NaowhForever",
        "",
        "ns.TransportRoutes = {",
    ]
    for tid, name, docks in ROUTES:
        route = routes[tid]
        rows = route["rows"]
        placed = []
        for row_index, (key, place) in zip(dock_rows(route, len(docks)), docks):
            cont, x, y = world(route, rows[row_index])
            miss = math.hypot(x - stops[key][1], y - stops[key][2])
            assert cont == stops[key][0] and miss < MAX_DOCK_MISS, f"{name} docks {miss:.1f} yd from {key}"
            arrive = rows[row_index - 1]["offset"] if row_index > 0 else 0.0
            placed.append((key, place, arrive, rows[row_index]["offset"]))
        triggers = []
        for index, row in enumerate(rows):
            if any(tag.startswith("trig") for tag in row["tags"]):
                cont, bx, by = world(route, row)
                cont_a, ax, ay = world(route, rows[index - 1])
                assert cont == cont_a, f"{name}'s trigger at row {index + 1} crosses continents"
                triggers.append((cont, ax, ay, bx, by, rows[index - 1]["offset"], row["dt"]))
        lines.append(f'    ["{name}"] = {{ period = {route["period"]:.6f}, docks = {{')
        for key, place, arrive, leave in placed:
            lines.append(f'        {{ stop = "{key}", place = "{place}", arrive = {arrive:.3f}, leave = {leave:.3f} }},')
        lines.append("    }, triggers = {")
        for cont, ax, ay, bx, by, at, span in triggers:
            lines.append(f"        {{ continent = {cont}, ax = {ax:.1f}, ay = {ay:.1f}, bx = {bx:.1f}, by = {by:.1f},"
                         f" at = {at:.3f}, span = {span:.3f} }},")
        lines.append("    } },")
    lines.append("}")
    OUTPUT.write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))
    print(f"Transport routes -> {OUTPUT}")


if __name__ == "__main__":
    main()
