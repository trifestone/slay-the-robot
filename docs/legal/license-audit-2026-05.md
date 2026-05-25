---
status: pending-legal-review
audit_date: 2026-05-20
auditor: agent
reviewer: TBD
---

# License Audit — 2026-05-20

## Scope

This audit covers all third-party components incorporated in the MyGame repository
as of 2026-05-20. It was generated automatically by the ISSUE-022 executor agent
and requires human legal sign-off before any public release.

## Dependency Inventory

| # | Component | License | Version / SHA | Source | Vendored Path | Status |
|---|-----------|---------|---------------|--------|---------------|--------|
| 1 | Slay-The-Robot (upstream template) | MIT | SHA `5170758dcf9d07a49c0bfd3e336384289b9b1ad5`, fork date 2026-05-19 | https://github.com/DesirePathGames/Slay-The-Robot | `src/` (fork root) | Confirmed present — `src/LICENSE` preserved verbatim |
| 2 | GdUnit4 | MIT | v6.1.3 | https://github.com/MikeSchulze/gdUnit4 | `src/addons/gdUnit4/` | Confirmed present — `src/addons/gdUnit4/plugin.cfg` version field = "6.1.3" |
| 3 | godot-state-charts | TBD | TBD | https://github.com/derkork/godot-state-charts (anticipated) | not yet vendored | Not present in `src/addons/` as of audit date; NOTICE placeholder added |
| 4 | Godot Engine | MIT | 4.6.2.stable.official.71f334935 | https://github.com/godotengine/godot | Runtime (not vendored) | Engine binary not shipped; listed for completeness |
| 5 | Fonts / Audio / Art | TBD | TBD | TBD | not yet sourced | Placeholder phase — no third-party assets incorporated |

## Upstream Fork SHA

`5170758dcf9d07a49c0bfd3e336384289b9b1ad5` (DesirePathGames/Slay-The-Robot, forked 2026-05-19)

## Automated Audit Script Output

Script: `tools/check_license.ps1`

```
OK  : src/LICENSE exists and is non-empty
OK  : NOTICE contains 'Slay-The-Robot'
OK  : NOTICE contains 'GdUnit4'
OK  : NOTICE contains 'Godot'
OK  : src/addons/gdUnit4/ directory exists

License audit OK
```

Exit code: **0**

## Files Created / Verified by This Audit

- `src/LICENSE` — upstream Slay-The-Robot MIT license (not modified)
- `NOTICE` — third-party attribution file (created)
- `tools/check_license.ps1` — CI-ready audit script (created)
- `docs/legal/license-audit-2026-05.md` — this document (created)

## Per-File License Headers

Per project convention (PRD §7.1), license headers are **not** added to new
project source files (`src/data/`, `src/tests/`, `tools/`). Headers are only
preserved where the upstream already had them. No modifications were made to
any file inside `src/addons/` or any fork-origin script.

## Open Items

- [ ] godot-state-charts: confirm license and version when the addon is imported
- [ ] Fonts / Audio / Art: enumerate all assets and confirm licenses before v1 release
- [ ] Legal reviewer must verify that MIT-on-MIT fork attribution is sufficient for planned distribution channels (itch.io, Steam)

---

## Legal Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Auditor (agent) | ISSUE-022 executor | 2026-05-20 | (automated) |
| Legal reviewer | TBD | | __________________ |
| Project lead | TBD | | __________________ |

**Action required**: A qualified reviewer must inspect this document, verify the
dependency inventory, and sign above before any public release of MyGame.
