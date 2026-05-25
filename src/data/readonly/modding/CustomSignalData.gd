## Read only data object that controls the loading of a single mod.
## These are used to generate CustomSignal objects in Signals, which are typically used
## by CombatStatsData and ActionEmitCustomSignal
extends SerializableData
class_name CustomSignalData

## If this custom signal should be loaded into CombatStatsData and treated as a stat that
## can be tracked
@export var custom_signal_is_stat: bool = true
## Follows naming convention of CUSTOM_STAT_<NAME>
@export var custom_signal_stat_name: String = "CUSTOM_STAT_NAME"
