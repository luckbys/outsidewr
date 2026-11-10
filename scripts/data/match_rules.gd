class_name MatchRules
extends RefCounted
## Balance lives here rather than being scattered through rendering and UI.

const FACTIONS: Array[FactionData] = [
	preload("res://resources/factions/police.tres"),
	preload("res://resources/factions/traffic.tres")
]
const WAVE_INTERVAL := 14.0
const WAVE_SIZE := 3
const RESPAWN_TIME := 8.0
const PULSE_RADIUS := 155.0
const PULSE_DAMAGE := 70.0
const PULSE_COOLDOWN := 7.0
const PULSE_SLOW := 0.35
const PULSE_SLOW_DURATION := 1.5
const DASH_DISTANCE := 125.0
const DASH_COOLDOWN := 5.0
const BASE_HEAL_PER_SECOND := 24.0
const DEFENSE_WINDUP := 0.45
const DEFENSE_AGGRO_TIME := 3.0
const BOT_RETREAT_HEALTH := 0.28
const BOT_RETURN_HEALTH := 0.78

static func stats(role: int) -> Dictionary:
	match role:
		0: # Hero
			return {"hp": 420.0, "speed": 118.0, "damage": 28.0,
				"range": 125.0, "interval": 0.65, "reward": 100}
		1: # Troop
			return {"hp": 100.0, "speed": 47.0, "damage": 11.0,
				"range": 74.0, "interval": 0.95, "reward": 15}
		2: # Barricade
			return {"hp": 640.0, "speed": 0.0, "damage": 38.0,
				"range": 190.0, "interval": 1.15, "reward": 120}
		_: # Core
			return {"hp": 1100.0, "speed": 0.0, "damage": 20.0,
				"range": 145.0, "interval": 1.2, "reward": 0}
