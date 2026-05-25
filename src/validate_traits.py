import json
from collections import Counter

with open(r"C:\Users\zuolei01\Documents\MyGame\src\data\traits.json", encoding="utf-8") as f:
    traits = json.load(f)

print("Total:", len(traits))

ids = [t["id"] for t in traits]
dups = {k: v for k, v in Counter(ids).items() if v > 1}
print("Duplicate ids:", dups)

rarity = Counter(t["rarity"] for t in traits)
print("Rarity:", dict(rarity))

school = Counter(t["axis_school"] for t in traits)
print("School:", dict(school))

timing = Counter(t["trigger"] for t in traits)
print("Trigger/Timing:", dict(timing))

violations = [t["id"] for t in traits if t["trigger"] in ("OnKill", "OnTraitFired") and t["cooldown_per_turn"] < 1]
print("M1 violations:", violations)

# Coverage cells (school x timing)
cells = set()
for t in traits:
    cells.add((t["axis_school"], t["trigger"]))
print("Coverage cells occupied:", len(cells), "/ 48")

# Per-school counts
for s in ["Fire","Decay","Moon","Iron","Bone","Void"]:
    c = sum(1 for t in traits if t["axis_school"] == s)
    print(f"  {s}: {c}")

# Per-timing counts
for tr in ["OnPlay","OnDraw","OnDiscard","OnKill","OnHit","StartTurn","EndTurn","OnTraitFired"]:
    c = sum(1 for t in traits if t["trigger"] == tr)
    print(f"  {tr}: {c}")
