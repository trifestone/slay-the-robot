## ISSUE-009a — composes a single human-readable string for the 3 trait slots
## of a TraitCard, in either "en" or "zh_CN".
##
## Empty slots contribute nothing. Locked slot[0] is rendered identically to
## the others (the lock badge is a UI concern, not a text concern).
##
## Public API:
##   compose(card: TraitCard, locale: String = "zh_CN") -> String
##   render_trait(t: Trait, locale: String) -> String
extends RefCounted

const EnumsScript := preload("res://core/enums.gd")

# ---------------------------------------------------------------------------
# Locale dictionaries
# ---------------------------------------------------------------------------
# Effect types we support in v0. Extend by adding entries here only.
const EFFECT_TEMPLATES_ZH := {
	"Damage": "造成 %d 点 %s伤害",
	"Apply":  "给目标 %d 层 %s",
	"Draw":   "抽 %d 张牌",
	"Heal":   "回复 %d 点生命",
	"Block":  "获得 %d 点格挡",
	"HealSelfPercent": "回复 %d%% 生命",
	"Spawn":  "生成 %d 张牌",
}

const EFFECT_TEMPLATES_EN := {
	"Damage": "Deal %d %sdamage",
	"Apply":  "apply %d %s",
	"Draw":   "draw %d card%s",
	"Heal":   "heal %d HP",
	"Block":  "gain %d block",
	"HealSelfPercent": "heal %d%% HP",
	"Spawn":  "spawn %d card%s",
}

# School adjective per locale. Empty string means "no school adjective" — used
# for non-elemental effects so we don't say "Deal X  damage" with two spaces.
const SCHOOL_ZH := {
	0: "火焰",   # Fire
	1: "腐蚀",   # Decay
	2: "月华",   # Moon
	3: "钢铁",   # Iron
	4: "尸骨",   # Bone
	5: "虚空",   # Void
}

const SCHOOL_EN := {
	0: "Fire ",
	1: "Decay ",
	2: "Moon ",
	3: "Iron ",
	4: "Bone ",
	5: "Void ",
}

# Apply payload nouns — what status word goes after the count.
# Keyed by (school, locale).
const APPLY_NOUN_ZH := {
	0: "油",       # Fire (oil_slick)
	1: "腐蚀",     # Decay
	2: "月华",     # Moon
	3: "钢护",     # Iron
	4: "骸骨",     # Bone
	5: "虚空",     # Void
}

const APPLY_NOUN_EN := {
	0: "Oil",
	1: "Decay",
	2: "Moon",
	3: "Plate",
	4: "Bone",
	5: "Void",
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Compose all trait fragments into one human-readable string for the card.
## Empty slots produce no fragment. Joiner is " + " in both locales.
func compose(card: Resource, locale: String = "zh_CN") -> String:
	if card == null:
		return ""
	var fragments: Array = []
	for s in card.slots:
		if s == null or s.trait_ref == null:
			continue
		var f: String = render_trait(s.trait_ref, locale)
		if f != "":
			fragments.append(f)
	return " + ".join(fragments)


## Render a single Trait into a localized string.
## Returns "" for unsupported effect types so the caller can skip silently.
func render_trait(t: Resource, locale: String) -> String:
	if t == null:
		return ""
	var is_zh: bool = (locale != "en")
	var templates: Dictionary = EFFECT_TEMPLATES_ZH if is_zh else EFFECT_TEMPLATES_EN
	if not templates.has(t.effect_type):
		return ""
	var tmpl: String = templates[t.effect_type]
	var school: int = t.axis_school
	var school_word: String = ""
	var apply_noun: String = ""
	if is_zh:
		school_word = SCHOOL_ZH.get(school, "")
		apply_noun = APPLY_NOUN_ZH.get(school, "")
	else:
		school_word = SCHOOL_EN.get(school, "")
		apply_noun = APPLY_NOUN_EN.get(school, "")

	match t.effect_type:
		"Damage":
			return tmpl % [t.effect_value, school_word]
		"Apply":
			return tmpl % [t.effect_value, apply_noun]
		"Draw":
			if is_zh:
				return tmpl % [t.effect_value]
			# English plural: "card" vs "cards"
			var plural := "" if t.effect_value == 1 else "s"
			return tmpl % [t.effect_value, plural]
		"Spawn":
			if is_zh:
				return tmpl % [t.effect_value]
			var plural2 := "" if t.effect_value == 1 else "s"
			return tmpl % [t.effect_value, plural2]
		"Heal", "Block", "HealSelfPercent":
			return tmpl % [t.effect_value]
		_:
			return ""
