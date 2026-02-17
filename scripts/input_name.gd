extends LineEdit

func _ready():
	text_changed.connect(_on_text_changed)

func _on_text_changed(new_text: String):
	var filtered = ""
	for c in new_text:
		if c >= "a" and c <= "z" or c >= "A" and c <= "Z":
			filtered += c.to_upper()
	
	if text != filtered:
		text = filtered
		caret_column = text.length()
