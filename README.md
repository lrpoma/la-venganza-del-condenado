# La venganza del condenado

Plataformas 2D / terror folclórico andino en **Godot 4.x** (INF-266 Taller de Proyecto, UMSA).
Basado en el relato «Mitos y Cuentos de Pucarani: La Venganza del Condenado». Ver el GDD para el diseño completo.

## Ejecutar
Abrir la carpeta en Godot 4.x y pulsar F5 (escena principal: `scenes/ui/main_menu.tscn`).

## Controles (GDD §17)
| Tecla | Acción |
|---|---|
| A/D o flechas | Mover |
| Espacio | Saltar (Humano corto, Perro largo) |
| J o click izquierdo | Morder (solo Perro) |
| 1 / 2 / 3 | Humano / Perro / Remolino |
| W/S | Subir/bajar (Remolino) |
| E | Interactuar con el Yatiri Apu / avanzar diálogo |
| Esc | Pausa |

**Mando PS4:** stick/D-pad mover · ✕ saltar · □ interactuar/continuar diálogo · ○ o R2 morder · L1 Humano · R1 Perro · △ Remolino · Options pausa · menús con D-pad/stick y ✕.

## Guardado
Un solo slot (`user://savegame.json`): se guarda al empezar cada nivel y al terminar un diálogo del Yatiri. El menú ofrece **Continuar** (si existe guardado) o **Nueva partida**, que lo sobrescribe. Al terminar el juego se borra.

## Historia por niveles
Nivel 1: el Yatiri te dirige al primer traidor, que dice «yo no sé, el otro sabe» y al morir señala al segundo. Nivel 2: primer Yatiri (encrucijada) introduce al segundo traidor (lanza cuchillos); al vencerlo revela que José Mamani guarda el oro y aparece un segundo Yatiri que explica al jefe final (la salida se abre tras escucharlo). Nivel 3: José Mamani.

## Estructura
- `autoload/` — `GameManager` (progreso, flujo de niveles, señales), `Audio` (SFX/música), `GameLog` (consola).
- `scenes/player/` — jugador + máquina de estados (Humano / Perro / Remolino).
- `enemies/` — `Enemy` (perros y amigos, IA por estados + RayCast2D), `Boss` (José Mamani), proyectil de incienso.
- `scenes/levels/` — `Level` (clase base con ayudantes de construcción), `level1-3.gd/.tscn`, HUD, fondo, sal/incienso, salida.
- `scenes/npc/yatiri.gd` — NPC obligatorio (Idle / Diálogo / Desvanecerse).
- `scenes/ui/` — menú, Game Over, final + créditos.
- `assets/` — sprites y audio **generados** con `python3 tools/gen_assets.py` (pixel art x3, SFX y música ambiental). Se pueden sustituir por arte propio manteniendo nombre y frames horizontales.
- `tools/playtest.tscn` — prueba automática de lógica: `godot --headless --path . tools/playtest.tscn`.
- `tools/shot.tscn` — utilidad para capturar frames (`--write-movie`) de un nivel/posición/forma.

## Cumplimiento del GDD
| Sección | Estado |
|---|---|
| §12 Formas: Humano +5 EE/s lento sin salto/ataque; Perro -10/s rápido, salto largo, mordida; Remolino -30/s sin gravedad | ✅ |
| §11/§18 Una barra de **Vida** (roja) + barra de **Energía Espiritual**; energía 0 => vuelve a Humano; caer al abismo o vida 0 => Game Over y reintento del nivel | ✅ |
| §13 Sal/incienso (daño continuo a Humano y Perro, Remolino inmune); perros guardianes (patrulla → persecución por cono de RayCast2D → ataque con aviso); jefe con escudo de rezos / ráfagas de incienso | ✅ |
| §9 NPC Yatiri Apu: altar (Area2D) + tecla E, diálogo, desbloquea Remolino, entrega coca/pista, se desvanece en partículas; aparece en Nivel 1 y Nivel 2 | ✅ |
| §14 Nivel 1 Caminos de Pucarani, Nivel 2 Qhenaco Alto (abismos, ascenso), Nivel 3 La Casa de José (jefe); «Nivel 0 – La Fosa» como cinemática de texto | ✅ |
| §15 Huesos (+20 EE), Amuleto (-30 % drenaje, se obtiene al completar el Nivel 2), Ofrenda de coca (revela el punto débil del jefe), Oro maldito (dispara el final) | ✅ |
| §16 Pixel art nocturno frío con sal/incienso en amarillo/naranja; SFX (ladrido, viento, chisporroteo, clic) y música ambiental | ✅ (arte/audio generados proceduralmente; conviene reemplazar por arte final) |
| §18 Victoria: jefe derrotado → cinemática de transformación → créditos | ✅ |
| §22 Capas de colisión (entorno, jugador, enemigos, zonas de daño, hitbox, interacción) y `CharacterBody2D` | ✅ |

Notas de diseño / decisiones propias (revisar contra el GDD): los dos primeros asesinos no tienen nombre en el GDD, se llaman «primer/segundo traidor»; la vida no se regenera (el altar del Yatiri la restaura); la «huida al amanecer» de §7 no está implementada como cuenta regresiva.

## Pruebas (GDD §20.1)
`tools/playtest.gd` automatiza P01, P02, P03, P04, P05, P06, P07 y P08 (lógica). P09/P10 (flujo completo, audio) requieren jugar a mano.
