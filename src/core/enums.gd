## Enum singletons for the trait/card data model.
## All enum values are accessed as Enums.TriggerEvent.OnPlay, etc.
class_name Enums


enum TriggerEvent {
	OnPlay,
	OnDraw,
	OnDiscard,
	OnKill,
	OnHit,
	StartTurn,
	EndTurn,
	OnTraitFired,
}

enum School {
	Fire,
	Decay,
	Moon,
	Iron,
	Bone,
	Void,
}

enum Scope {
	Self,
	Card,
	Hand,
	Battlefield,
}

enum Rarity {
	Common,
	Uncommon,
	Rare,
}
