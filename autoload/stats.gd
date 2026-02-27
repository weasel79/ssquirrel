extends Node
# Global stats tracker — records all combat events for the TAB overlay.
# Autoloaded as "Stats". Tracks damage dealt/taken, kills, DPS, per-enemy
# breakdowns, weapon mod pickups, and timing.

# ── Cumulative counters ──────────────────────────────────────────────────
var total_damage_dealt := 0
var total_damage_taken := 0
var total_kills := 0
var total_shots_fired := 0
var total_pickups := 0
var game_time := 0.0

# ── Per-enemy-type kill/damage tracking ──────────────────────────────────
var kills_by_type := {}    # "Squirrel": 5, "Rat": 12, ...
var damage_by_type := {}   # "Squirrel": 10, ...

# ── Per-weapon-mod stats ─────────────────────────────────────────────────
var pickups_by_mod := {}   # "spread": 2, "homing": 1, ...

# ── DPS rolling window (last 5 seconds) ─────────────────────────────────
var _damage_log: Array[Dictionary] = []  # [{ "time": float, "amount": int }, ...]
const DPS_WINDOW := 5.0

# ── Recent events log (last 20 events for the overlay) ──────────────────
var event_log: Array[String] = []
const MAX_EVENTS := 20


func _process(delta: float) -> void:
	game_time += delta
	# Prune old DPS entries
	while not _damage_log.is_empty() and _damage_log[0]["time"] < game_time - DPS_WINDOW:
		_damage_log.pop_front()


func reset() -> void:
	total_damage_dealt = 0
	total_damage_taken = 0
	total_kills = 0
	total_shots_fired = 0
	total_pickups = 0
	game_time = 0.0
	kills_by_type.clear()
	damage_by_type.clear()
	pickups_by_mod.clear()
	_damage_log.clear()
	event_log.clear()


# ── Recording functions (called by game systems) ────────────────────────

func record_damage_dealt(amount: int, enemy_type: String) -> void:
	total_damage_dealt += amount
	damage_by_type[enemy_type] = damage_by_type.get(enemy_type, 0) + amount
	_damage_log.append({ "time": game_time, "amount": amount })


func record_damage_taken(amount: int) -> void:
	total_damage_taken += amount
	_add_event("Took %d damage" % amount)


func record_kill(enemy_type: String, score_value: int) -> void:
	total_kills += 1
	kills_by_type[enemy_type] = kills_by_type.get(enemy_type, 0) + 1
	_add_event("Killed %s (+%d)" % [enemy_type, score_value])


func record_shot(count: int = 1) -> void:
	total_shots_fired += count


func record_pickup(mod_name: String, new_level: int) -> void:
	total_pickups += 1
	pickups_by_mod[mod_name] = pickups_by_mod.get(mod_name, 0) + 1
	_add_event("%s → Lv%d" % [mod_name.to_upper(), new_level])


# ── Computed stats ───────────────────────────────────────────────────────

func get_dps() -> float:
	if _damage_log.is_empty():
		return 0.0
	var window_damage := 0
	for entry: Dictionary in _damage_log:
		window_damage += entry["amount"] as int
	var window_time := minf(game_time, DPS_WINDOW)
	if window_time <= 0.0:
		return 0.0
	return float(window_damage) / window_time


func get_avg_dps() -> float:
	if game_time <= 0.0:
		return 0.0
	return float(total_damage_dealt) / game_time


func get_kills_per_minute() -> float:
	if game_time <= 0.0:
		return 0.0
	return float(total_kills) / game_time * 60.0


func get_accuracy() -> float:
	if total_shots_fired <= 0:
		return 0.0
	# Approximate: total_damage_dealt / total_shots_fired (not exact, but useful)
	return minf(float(total_damage_dealt) / float(total_shots_fired) * 100.0, 100.0)


func get_time_string() -> String:
	var mins := int(game_time) / 60
	var secs := int(game_time) % 60
	return "%d:%02d" % [mins, secs]


func _add_event(text: String) -> void:
	event_log.append("[%s] %s" % [get_time_string(), text])
	if event_log.size() > MAX_EVENTS:
		event_log.pop_front()
