# ISSUE-015 — Shop: card column + trait column (US-10)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-10 (PRD §3 补卡 / 补词条)
**Estimate**: S (≤2h)

## What
Build a shop scene with two clearly separated columns: cards (50/80/140 gold for Common/Uncommon/Rare) and traits (40/70/120 gold). Buy = gold deducted, item added to deck/inventory respectively. End-to-end: enter shop with 200 gold, buy 1 trait + 1 card, exit with correctly updated state.

## Why
PRD §3 US-10 + §4.8 economy table. The 9-10 decisions/run target can't be measured without a real shop.

## Acceptance criteria
- [ ] `src/ui/shop/{shop_scene,shop_item}.gd` + `.tscn`s.
- [ ] 3 random cards + 3 random traits seeded by run RNG.
- [ ] Affordability: button disabled when gold insufficient.
- [ ] Visual separation of two columns; tooltip on each item.
- [ ] Shop heal item (+30% maxHP / 50 gold) listed (PRD §4.8 row).
- [ ] Visual review screencap.
- [ ] `tests/test_shop_logic.gd`: buy deducts gold, adds to correct collection; insufficient-gold blocked.

## Implementation hints
- Files: `src/ui/shop/{shop_scene,shop_item}.{gd,tscn}`, `tests/test_shop_logic.gd`
- Hook into run.gd between battles via map (ISSUE-017 wires entry; for now `tools/open_shop.gd` debug entry).

## Blocked-by
- ISSUE-013

## Out of scope (this issue)
- Map node integration → ISSUE-017
- Card removal service (75+ gold) → defer to camp slice expansion
- Reroll mechanic

## Source
- PRD §3 US-10 + §4.8 价格表
