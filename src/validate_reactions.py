import json
from collections import Counter

with open(r"C:\Users\zuolei01\Documents\MyGame\src\data\traits.json", encoding="utf-8") as f:
    traits = json.load(f)
trait_ids = {t["id"] for t in traits}
trait_timing = {t["id"]: t["trigger"] for t in traits}

with open(r"C:\Users\zuolei01\Documents\MyGame\src\data\reactions.json", encoding="utf-8") as f:
    reactions = json.load(f)

print("Total reactions:", len(reactions))

# Check watch_for ids exist
for r in reactions:
    for tid in r["watch_for"]:
        if tid not in trait_ids:
            print(f"  MISSING trait id '{tid}' in reaction '{r['id']}'")

# Check timing is valid
valid_timings = {"OnPlay", "OnDraw", "OnDiscard", "OnKill", "OnHit", "StartTurn", "EndTurn", "OnTraitFired"}
for r in reactions:
    if r["timing"] not in valid_timings:
        print(f"  INVALID timing '{r['timing']}' in reaction '{r['id']}'")

# Categorize: same-timing = both watch_for traits have same trigger as reaction timing
# cross-school = watch_for traits are from different schools
# inhibit = flavor contains suppression keywords
same_timing = 0
cross_school = 0
inhibit = 0
for r in reactions:
    t0_id, t1_id = r["watch_for"][0], r["watch_for"][1]
    t0 = next((t for t in traits if t["id"] == t0_id), None)
    t1 = next((t for t in traits if t["id"] == t1_id), None)

    is_same_timing = (t0 and t0["trigger"] == r["timing"]) or (t1 and t1["trigger"] == r["timing"])
    is_cross_school = t0 and t1 and t0["axis_school"] != t1["axis_school"]
    is_inhibit = "抑制" in r["flavor"] or "相消" in r["flavor"] or "suppress" in r["flavor"].lower() or "inhibit" in r["flavor"].lower() or "cancel" in r["flavor"].lower()

    category = []
    if is_inhibit:
        category.append("inhibit")
        inhibit += 1
    elif is_cross_school:
        category.append("cross_school")
        cross_school += 1
    else:
        category.append("same_timing")
        same_timing += 1
    print(f"  {r['id']}: timing={r['timing']} t0_school={t0['axis_school'] if t0 else '?'} t1_school={t1['axis_school'] if t1 else '?'} → {category}")

print(f"\nSame-timing: {same_timing}, Cross-school: {cross_school}, Inhibit: {inhibit}")
print(f"Required: 18 same-timing / 5 cross-school / 2 inhibit")
