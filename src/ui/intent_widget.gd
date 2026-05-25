## ISSUE-010a — intent_widget logic.
## Pure-data resolver: given an enemy's intent string + numeric value,
## produces a code-tag, display label, and locale-aware tooltip.
##
## The .tscn-side widget consumes resolve() and renders icon + number;
## tooltip text is what hover code shows.
##
## Public API:
##   resolve(intent: String, value: int, locale: String = "zh_CN") -> Dictionary
##     returns { icon_code, label, tooltip }
extends RefCounted

const SUPPORTED_INTENTS := ["Attack", "Block", "Buff", "Debuff", "Multi"]

# code-tag drives the .tscn icon swap (placeholder until real sprites land)
const ICON_CODES := {
	"Attack":  "ATK",
	"Block":   "BLK",
	"Buff":    "BUF",
	"Debuff":  "DBF",
	"Multi":   "MUL",
}

const COLORS := {
	"Attack":  Color(0.85, 0.30, 0.20),
	"Block":   Color(0.55, 0.65, 0.85),
	"Buff":    Color(0.45, 0.75, 0.40),
	"Debuff":  Color(0.65, 0.30, 0.65),
	"Multi":   Color(0.85, 0.65, 0.20),
}

const TOOLTIP_ZH := {
	"Attack":  "下回合攻击造成 %d 点伤害",
	"Block":   "下回合获得 %d 点格挡",
	"Buff":    "下回合给自己施加 %d 层增益",
	"Debuff":  "下回合给玩家施加 %d 层减益",
	"Multi":   "下回合执行多重动作 (强度 %d)",
}

const TOOLTIP_EN := {
	"Attack":  "Will attack for %d damage next turn",
	"Block":   "Will gain %d block next turn",
	"Buff":    "Will buff self by %d next turn",
	"Debuff":  "Will debuff player by %d next turn",
	"Multi":   "Will perform multiple actions next turn (intensity %d)",
}


## Resolve intent + value into a render dictionary.
## Unknown intents fall back to a neutral display so UI never crashes.
func resolve(intent: String, value: int, locale: String = "zh_CN") -> Dictionary:
	var safe_intent: String = intent if SUPPORTED_INTENTS.has(intent) else "Attack"
	var is_zh: bool = (locale != "en")
	var tmpl_dict: Dictionary = TOOLTIP_ZH if is_zh else TOOLTIP_EN
	var tooltip: String = (tmpl_dict[safe_intent] as String) % value

	# Label is the bare number for Attack/Block/Multi (the most common cases).
	# Buff/Debuff show "+N" / "-N" to disambiguate.
	var label: String
	match safe_intent:
		"Buff":   label = "+%d" % value
		"Debuff": label = "-%d" % value
		_:        label = str(value)

	return {
		"icon_code": ICON_CODES[safe_intent],
		"label":     label,
		"tooltip":   tooltip,
		"color":     COLORS[safe_intent],
		"intent":    safe_intent,
	}


## Convenience: human-readable trait list for carried_traits hover.
## Returns an Array of {id, flavor} dictionaries (Array preserves order).
func describe_carried(carried_traits: Array) -> Array:
	var out: Array = []
	for t in carried_traits:
		if t == null:
			continue
		out.append({"id": t.id, "flavor": t.flavor})
	return out
