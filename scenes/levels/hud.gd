# ===== hud.gd =====
extends CanvasLayer

@onready var energy_bar: ProgressBar = $EnergyBar

func _ready() -> void:
	GameManager.player_energy_updated.connect(_on_energy_updated)
	GameManager.player_form_changed.connect(_on_form_changed)

func _on_energy_updated(current: float, max_energy: float) -> void:
	energy_bar.max_value = max_energy
	energy_bar.value = current

func _on_form_changed(new_form: String) -> void:
	pass
