extends CanvasLayer
# HUD — displays score, health, active mods with levels, live DPS,
# game-over screen, and a detailed TAB stats overlay.

@onready var score_label: Label = $ScoreLabel
@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var game_over_label: Label = $GameOverLabel
@onready var mods_label: Label = $ModsLabel
@onready var dps_label: Label = $DpsLabel
@onready var stats_panel: Panel = $StatsPanel
@onready var stats_text: RichTextLabel = $StatsPanel/StatsText

var heart_texture: Texture2D = preload("res://art/heart.png")

var mod_display := {
	"spread":  { "name": "SPREAD",  "color": "green"  },
	"rapid":   { "name": "RAPID",   "color": "orange" },
	"pierce":  { "name": "PIERCE",  "color": "cyan"   },
	"bigshot": { "name": "BIG",     "color": "red"    },
	"homing":  { "name": "HOMING",  "color": "magenta"},
	"orbit":   { "name": "ORBIT",   "color": "aqua"   },
	"rear":    { "name": "REAR",    "color": "yellow" },
}


func _ready() -> void:
	game_over_label.visible = false
	stats_panel.visible = false
	update_score(0)


func _process(_delta: float) -> void:
	# Update live DPS display
	dps_label.text = "DPS: %.1f" % Stats.get_dps()

	# TAB toggle for stats overlay
	stats_panel.visible = Input.is_action_pressed("show_stats")
	if stats_panel.visible:
		_refresh_stats_panel()


func update_score(value: int) -> void:
	score_label.text = "Score: %d" % value


func update_health(value: int) -> void:
	for child in hearts_container.get_children():
		child.queue_free()
	for i in range(value):
		var heart := TextureRect.new()
		heart.texture = heart_texture
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(18, 18)
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_container.add_child(heart)


# Build the mods status line from the player's mod dictionary
func update_mods(mods: Dictionary) -> void:
	var parts: Array[String] = []
	for mod_name: String in mods:
		var level: int = mods[mod_name]
		if level <= 0:
			continue
		var info: Dictionary = mod_display.get(mod_name, { "name": mod_name.to_upper(), "color": "white" })
		var stars := "I".repeat(level)
		parts.append("%s %s" % [info["name"], stars])

	if parts.is_empty():
		mods_label.text = "PEA SHOOTER"
	else:
		mods_label.text = "  ".join(parts)


func show_game_over(final_score: int = 0, kills: int = 0) -> void:
	var dps_str := "%.1f" % Stats.get_avg_dps()
	var time_str := Stats.get_time_string()
	game_over_label.text = "GAME OVER\nScore: %d | Kills: %d\nTime: %s | Avg DPS: %s\nPress R to restart" % [
		final_score, kills, time_str, dps_str]
	game_over_label.visible = true


# ── TAB stats overlay ────────────────────────────────────────────────────

func _refresh_stats_panel() -> void:
	var s := Stats
	var lines: Array[String] = []

	lines.append("[b]═══ COMBAT STATS ═══[/b]")
	lines.append("Time: %s" % s.get_time_string())
	lines.append("")

	lines.append("[b]— Damage —[/b]")
	lines.append("Total dealt:  %d" % s.total_damage_dealt)
	lines.append("Total taken:  %d" % s.total_damage_taken)
	lines.append("Current DPS:  %.1f" % s.get_dps())
	lines.append("Average DPS:  %.1f" % s.get_avg_dps())
	lines.append("Shots fired:  %d" % s.total_shots_fired)
	lines.append("Hit rate:     %.0f%%" % s.get_accuracy())
	lines.append("")

	lines.append("[b]— Kills (%d total) —[/b]" % s.total_kills)
	lines.append("Kills/min:    %.1f" % s.get_kills_per_minute())
	if not s.kills_by_type.is_empty():
		for enemy_type: String in s.kills_by_type:
			var k: int = s.kills_by_type[enemy_type]
			var d: int = s.damage_by_type.get(enemy_type, 0)
			lines.append("  %-10s  %d kills / %d dmg" % [enemy_type, k, d])
	lines.append("")

	lines.append("[b]— Pickups (%d total) —[/b]" % s.total_pickups)
	if not s.pickups_by_mod.is_empty():
		for mod_name: String in s.pickups_by_mod:
			lines.append("  %-10s  x%d" % [mod_name.to_upper(), s.pickups_by_mod[mod_name]])
	lines.append("")

	lines.append("[b]— Event Log —[/b]")
	var log_start := maxi(s.event_log.size() - 8, 0)
	for i in range(log_start, s.event_log.size()):
		lines.append(s.event_log[i])

	stats_text.text = "\n".join(lines)
