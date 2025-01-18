extends Effect

@export var bonus: float = 0.2

func _apply() -> void:
	get_target().speed *= 1 + bonus

func _cease() -> void:
	get_target().speed /= 1 + bonus
