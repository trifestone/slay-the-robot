# Slay the Robots

<p align="center">
  <a href="./README.md"><img src="https://img.shields.io/badge/Lang-English-blue?style=for-the-badge" alt="English"></a>
  <a href="./README_zh.md"><img src="https://img.shields.io/badge/%E8%AF%AD%E8%A8%80-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-red?style=for-the-badge" alt="简体中文"></a>
</p>

A Godot 4.6 roguelike deck-builder built on a **trait-composition** card system.
Each card is composed of small reusable *traits* (Damage / Block / Burn / Resonate / …),
and those traits can react to one another mid-resolution, producing emergent combos.

Fork of [Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) — see [`NOTICE`](./NOTICE) for upstream attribution.

> 中文版 README: [README_zh.md](./README_zh.md)

---

## Stack

- **Engine**: Godot 4.6.2 stable
- **Language**: GDScript
- **Tests**: GdUnit4 v6.1.3 (vendored at `src/addons/gdUnit4/`)
- **Platform**: Windows / Linux / macOS (engine-supported)

---

## Repository layout

```
.
├── docs/              # PRD, ADRs, issues, research, legal
│   ├── prd/           # product requirements
│   ├── adr/           # architecture decision records
│   ├── issues/        # ISSUE-XXX tickets
│   └── research/      # design exploration notes
├── src/               # the Godot project (open this folder as the Godot project root)
│   ├── core/          # battle loop, traits, reactions, RNG
│   ├── data/          # card / trait / enemy resources
│   ├── ui/            # scenes & view scripts
│   ├── vfx/           # particle scenes (reaction bursts, devour-kill, etc.)
│   ├── tests/         # GdUnit4 test suites
│   └── addons/        # vendored addons (gdUnit4, label_font_auto_sizer, …)
├── prototype/         # standalone experiments
├── tools/             # one-off scripts (data validators, generators)
└── NOTICE             # third-party attribution
```

---

## Getting started

### 1. Install Godot

Grab **Godot 4.6.2 stable** from <https://godotengine.org/download/>.

### 2. Open the project

Open the **`src/`** folder as a Godot project (not the repo root).

### 3. Run

Press `F5` (or the Play button) inside the editor.

---

## Running tests

The full GdUnit4 suite can be driven from the command line:

```bash
cd src
godot --headless --path . \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a tests
```

Currently **285 tests** across 28 suites cover the battle loop, trait reactions,
deterministic RNG, UI composition, and VFX scenes.

HTML reports land in `src/reports/report_N/`.

---

## Project status

Early-development prototype with the following complete:
- ✅ Core battle loop, trait reaction system, single-room battle UI
- ✅ Multi-target selection, turn resolution panel, VFX
- ✅ Tree map node selection (StS-style)
- ✅ Camp (inventory + drag-drop mount/dismantle)
- ✅ Shop (two-column cards + traits + heal)
- ✅ Reforge (base slot change with cost)
- ✅ **Enemy AI System**: Intent patterns (Attack/Block/Buff/Debuff/Charge/MegaAttack)
- ✅ **Enemy AI System**: Multi-enemy coordination (tank/aggressive pairs, boss charge)
- ✅ **UI**: Card dealing animation, turn-end summary with buttons
- ✅ **UI**: Energy insufficient feedback, shield/block display

Next up: events, meta-progression (unlock/ascension). See [`docs/issues/`](./docs/issues) for the active ticket backlog.

---

## License

MIT — see [`src/LICENSE`](./src/LICENSE). Upstream and third-party attributions
are enumerated in [`NOTICE`](./NOTICE).
