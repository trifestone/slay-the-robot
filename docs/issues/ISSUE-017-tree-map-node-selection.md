# ISSUE-017 — Tree map node selection (StS-style) (US-11)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-11 (PRD §3 地图选路)
**Estimate**: M (2-8h)

## What
Render a 3-act tree map (StS-style) with node types: Normal / Elite / Shop / Camp / Event / Boss. Player picks the next reachable node, click moves them and triggers the appropriate scene. End-to-end: starting a run shows act 1 map; selecting a node sequences ISSUE-005 (battle), ISSUE-013 (camp), or ISSUE-015 (shop) accordingly until boss.

## Why
PRD §3 US-11 + §4.8 single-run cadence. Without map, ISSUE-006's linear sequence has no player-choice dimension.

## Acceptance criteria
- [ ] `src/ui/map/{map_scene,map_node,map_generator}.gd` + `.tscn`.
- [ ] Procedural map generator: 3 acts × ~6 floors × 3 paths (StS layout). Boss at top of each act.
- [ ] Reachability: only forward-connected nodes clickable.
- [ ] Node icons distinct (5 visual types).
- [ ] Map state persists across battle/camp/shop returns.
- [ ] Visual review screencap.
- [ ] `tests/test_map_generator.gd`: generated map has correct node-type distribution; reachability graph is acyclic + forward-only.

## Implementation hints
- Files: `src/ui/map/{map_scene,map_node,map_generator}.{gd,tscn}`, `tests/test_map_generator.gd`
- Slay-The-Robot template (PRD §4.7) ships a map sample — adapt rather than rewrite.

## Blocked-by
- ISSUE-006, ISSUE-013, ISSUE-015

## Out of scope (this issue)
- Event nodes content (events themselves) → defer to v0.5 (PRD §4.8 lists events but content is open)
- Camp 30% maxHP heal node → camp slice expansion (still v0 but separate ticket if needed)

## Source
- PRD §3 US-11
- A1 §1, A6 §1.1 (Slay-The-Robot template)
