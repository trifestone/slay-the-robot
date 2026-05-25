# read only data for displaying info on a keyword; used for tooltips
extends SerializableData
class_name KeywordData

@export var keyword_child_keyword_object_ids: Array[String] = []	# if this keyword appears, it will imply the child keywords and display them
@export var keyword_text_bb_code: String = ""	# rich text displayed in a KeywordPanel describing the keyword
