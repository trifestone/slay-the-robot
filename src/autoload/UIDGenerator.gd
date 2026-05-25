## Helper singleton
## Manages Unique ID generation for PrototypeData objects
extends Node

var unique_id_counter = 0

func generate_unique_id(prototype_data: PrototypeData) -> String:
	var prefix: String = prototype_data.get_unique_id_prefix()
	self.unique_id_counter += 1
	if self.unique_id_counter >= 10000000:
		self.unique_id_counter = 0
	return prefix + "-" + str(Time.get_unix_time_from_system() * 1000) + str(Time.get_ticks_msec()) + "-" + str(unique_id_counter)
