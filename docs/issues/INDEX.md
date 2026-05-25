# Issue Index — 卡牌词条拼装 Roguelike

> Generated 2026-05-19 from PRD v1 + CONTEXT v1 + ADR-001 + PROTOTYPE_REPORT.
> Slicing methodology: mattpocock `/to-issues` (vertical, end-to-end day-1 deliverables).

## Counts

| Metric | Count |
|---|---|
| Total issues | 22 |
| AFK (agent self-verifiable) | 11 |
| HITL (human eyes required) | 11 |
| `Blocked-by: none` (Day 1 ready) | 1 |
| Estimate S | 7 |
| Estimate M | 11 |
| Estimate L (split candidates) | 4 |

### AFK roster (agent-runnable)
- ISSUE-001 Bootstrap template fork (S)
- ISSUE-002 Trait+Card data model (M)
- ISSUE-003 emit() trigger stack core (M)
- ISSUE-004 SpecialReaction timing (S)
- ISSUE-005 BattleState + fight loop (M)
- ISSUE-006 18-fight Run sequence (M)
- ISSUE-007 Post-battle heal core (S)
- ISSUE-008 Enemy carried_traits + drops (M)
- ISSUE-019 Headless 1k-run sim regression (M)
- ISSUE-020 emit() scale fixture (S)
- ISSUE-021 Trait+reaction coverage matrix (L)

### HITL roster (human review needed)
- ISSUE-009 Hand UI w/ trait icons (L) — US-01
- ISSUE-010 Enemy intent UI (M) — US-02
- ISSUE-011 Reaction + devour animations (M) — US-03/05
- ISSUE-012 Hover preview stack (M) — US-04
- ISSUE-013 Camp inventory + drag-drop + dismantle (L) — US-06/07/08
- ISSUE-014 Reaction preview diff (L, M5 core UX) — US-09
- ISSUE-015 Shop two-column (S) — US-10
- ISSUE-016 Reforge base slot (M) — US-16
- ISSUE-017 Tree map node selection (M) — US-11
- ISSUE-018 Run end + meta progression (L) — US-12/13/13b/14/15
- ISSUE-022 License/NOTICE check (S)

---

## Day-1 Ready (Blocked-by: none)

> Highlighted: start here.

- **ISSUE-001 — Bootstrap: fork Slay-The-Robot template + headless smoke test** (AFK / S)

Once 001 is green, the next layer (002, 022) unblocks immediately.

---

## Dependency graph (DAG)

```
ISSUE-001 (Bootstrap) ──┬── ISSUE-002 (Data model) ──┬── ISSUE-003 (emit core) ──┬── ISSUE-004 (Reactions+timing) ──┬── ISSUE-011 (anims, also needs 008,009)
                        │                            │                           │                                  ├── ISSUE-014 (preview diff, also needs 013)
                        │                            │                           │                                  ├── ISSUE-020 (emit scale)
                        │                            │                           │                                  └── ISSUE-021 (coverage matrix, also needs 002)
                        │                            │                           │
                        │                            │                           └── ISSUE-005 (Battle loop) ───┬── ISSUE-006 (Run sequence) ──┬── ISSUE-007 (heal)
                        │                            │                                                          │                              ├── ISSUE-008 (drops) ──┬── ISSUE-013 (camp, also needs 002) ──┬── ISSUE-014
                        │                            │                                                          │                              │                       ├── ISSUE-015 (shop) ────────────────────┘
                        │                            │                                                          │                              │                       └── ISSUE-016 (reforge)
                        │                            │                                                          │                              ├── ISSUE-017 (map, also needs 013,015) ── ISSUE-018 (run end, also needs 007)
                        │                            │                                                          │                              └── ISSUE-019 (sim, also needs 008)
                        │                            │                                                          └── (ISSUE-009 hand UI, also needs 005)
                        │                            └── (ISSUE-021 coverage uses 002+003+004)
                        │
                        └── ISSUE-022 (License/NOTICE)
```

### Edge list (compact)

| Issue | Blocked-by |
|---|---|
| 001 | — |
| 002 | 001 |
| 003 | 002 |
| 004 | 003 |
| 005 | 003 |
| 006 | 005 |
| 007 | 006 |
| 008 | 006 |
| 009 | 005 |
| 010 | 005, 008 |
| 011 | 004, 008, 009 |
| 012 | 009, 004 |
| 013 | 002, 008 |
| 014 | 013, 004 |
| 015 | 013 |
| 016 | 013 |
| 017 | 006, 013, 015 |
| 018 | 006, 007, 017 |
| 019 | 006, 008 |
| 020 | 003 |
| 021 | 002, 003, 004 |
| 022 | 001 |

DAG validation: no cycles. Foundation slice (001-005) is the longest unblock path — every HITL ticket sits behind at least 005 (battle loop) so they have something real to render against.

---

## User Story coverage

| User Story | Issue(s) |
|---|---|
| US-01 出牌 (hand UI) | 009 |
| US-02 看意图 | 010 |
| US-03 触发反应 (anim) | 011 |
| US-04 看反应预览 (battle hover) | 012 |
| US-05 击杀掉词条 (anim) | 011 (anim) + 008 (data) |
| US-06 拆装 (camp visibility) | 013 |
| US-07 拖拽镶嵌 | 013 |
| US-08 拆卸入库存 | 013 |
| US-09 反应预览 diff (M5 核心 UX) | 014 |
| US-10 商店两栏 | 015 |
| US-11 地图选路 | 017 |
| US-12 boss 击败 → 元进度 | 018 |
| US-13 死亡保留进度 | 018 |
| US-13b 战后回血 (M3) | 007 (data/numbers) + 018 (anim polish) |
| US-14 巫女背景叙事钩子 | 018 |
| US-15 每局必给小奖励 | 018 |
| US-16 重铸基底 | 016 |

All 17 user stories covered. The non-US infrastructure issues are 001 (bootstrap), 002-005 (foundation), 006 (run sequence), 008 (drops), 019/020/021 (testing), 022 (license).

---

## Suggested execution waves

1. **Wave 1 (AFK foundation)**: 001 → 002 → 003 → (004 ‖ 005 ‖ 022) → 006 → (007 ‖ 008 ‖ 020)
2. **Wave 2 (AFK data + sim)**: 019 ‖ 021
3. **Wave 3 (HITL battle UI)**: 009 → 010 → 012 → 011
4. **Wave 4 (HITL camp slice)**: 013 → (014 ‖ 015 ‖ 016)
5. **Wave 5 (HITL run frame)**: 017 → 018

Waves 2 and 3 can interleave since they touch different layers. Wave 5 (018) is the largest single ticket and should be split into 18a/18b/18c during planning.

---

## Open notes

- ISSUE-021 (coverage matrix) has implicit coupling to ISSUE-019 (sim) — author 80 traits + 25 reactions early so the sim runs against representative data.
- ISSUE-018 size is at the L boundary; expect split into 3 sub-tickets when the camp/map slices reveal more constraints.
- No user story was dropped or merged-out; M5 (US-09) explicitly upgraded to its own L-sized ticket per PRD §4.5 mandate.

---

*Index end. Next: pick up ISSUE-001 with executor agent (AFK / S, no blockers).*
