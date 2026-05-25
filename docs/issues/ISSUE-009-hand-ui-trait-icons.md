# ISSUE-009 — Hand UI: 3 trait icons per card + composed effect text (US-01)

**Labels**: `enhancement`, `HITL`, `status:ready-for-human`
**User Story**: US-01 (PRD §3 出牌)
**Estimate**: L (8h+, consider splitting into 9a icons / 9b composed-text)

## What
Render the player's hand as Cards with three slot icons and a composed effect string (not raw trait list). On hover, primary text resolves "trait1 + trait2 + trait3" into one human-readable description for the current card state. End-to-end: a battle starts, the player sees 5 cards, each card visually communicates 3 trait icons + composed effect within Steam Deck 7-inch readability bounds.

## Why
PRD §3 US-01: StS players need to read combos at a glance under 3-energy time pressure. PRD §5.5 calls out the 15-icon-on-screen silhouette test as a known art risk.

## Acceptance criteria
- [ ] `src/ui/card_ui.gd` (Control node) renders: base art, slot[0/1/2] icons in a horizontal row, energy cost, composed effect text.
- [ ] Composed-effect resolver: takes `Card` and produces a string like "造成 8 点 火焰伤害 + 给目标 1 层 油" (zh-CN) or "Deal 8 Fire damage + apply 1 Oil" (en) — both locales required for v0 (PRD §6 #2).
- [ ] Empty slot renders as muted "+" placeholder (camp can fill later).
- [ ] Locked slot[0] shows a small lock badge.
- [ ] 5 cards × 3 icons = 15 icons fit on a 1280×720 viewport without overlap; visual review screenshot in `docs/visual/us-01-hand.png`.
- [ ] `tests/test_card_ui_resolver.gd`: verifies composed-string formatter for 3 sample cards (basic Attack, Skill with reaction-pair, empty-slot card).
- [ ] No mock-only path: hand pulls from real `BattleState.hand` (ISSUE-005).

## Implementation hints
- Files: `src/ui/{card_ui,hand_ui,trait_icon}.gd`, `src/ui/card_ui.tscn`, `data/locale/{en,zh_CN}.po`, `tests/test_card_ui_resolver.gd`
- Reference Wildfrost rounded-card style + Cult of the Lamb palette per PRD §2 / A5.
- Use `TranslationServer` for locale switching.
- Designer review checkpoint required (HITL): silhouette/readability sign-off.

## Blocked-by
- ISSUE-005

## Out of scope (this issue)
- Hover-preview reaction stack → ISSUE-012
- Drag-drop (camp) → ISSUE-013
- Reaction trigger animation → ISSUE-011
- Final art assets (placeholder icons OK)

## Source
- PRD §3 US-01
- PRD §5.5 (Steam Deck readability)
- A5 mockup (战斗界面)
