extends Node

# Logger centralizado — todos los sistemas llaman aquí en vez de usar print() directo.
# Objetivo: consola limpia, solo eventos relevantes (sin spam de energía/posición por frame).

func transition(form_name: String) -> void:
	print("[FORMA] Cambiando a: ", form_name)

func player_attack(damage: float, hits: int) -> void:
	if hits > 0:
		print("[COMBATE] Jugador muerde por ", damage, " de daño (", hits, " enemigo(s) golpeado(s))")
	else:
		print("[COMBATE] Jugador muerde, pero ningún enemigo estaba en rango")

func enemy_attack(damage: float) -> void:
	print("[COMBATE] Enemigo ataca al jugador por ", damage, " de daño")

func player_damaged(source: String, amount: float) -> void:
	print("[DAÑO] Jugador recibió ", amount, " de ", source)

func enemy_damaged(amount: float, remaining_health: float) -> void:
	print("[DAÑO] Enemigo recibió ", amount, " | Vida restante: ", remaining_health)

func enemy_defeated() -> void:
	print("[ENEMIGO] Enemigo derrotado")

func enemy_detected_player() -> void:
	print("[ENEMIGO] Detectó al jugador, iniciando persecución")

func enemy_lost_player() -> void:
	print("[ENEMIGO] Perdió al jugador, volviendo a patrullar")

func entered_salt() -> void:
	print("[SAL] Jugador pisó un camino de sal")

func exited_salt() -> void:
	print("[SAL] Jugador salió del camino de sal")

func player_died() -> void:
	print("[MUERTE] Jugador murió")

func player_respawned(position: Vector2) -> void:
	print("[RESPAWN] Jugador reapareció en: ", position)

func event(tag: String, message: String) -> void:
	print("[", tag, "] ", message)
