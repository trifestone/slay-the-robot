## Readonly data; stores data about a pool of EventData IDs
extends SerializableData
class_name EventPoolData

## The event ids copied into the event pool in PlayerData
@export var event_pool_event_object_ids: Array[String] = []

## If for some reason the event pool becomes empty, this event id can be used as a fallback.
@export var event_pool_fallback_event_object_id: String = ""
