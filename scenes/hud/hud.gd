extends CanvasLayer
# HUD — displays score, health, active mods with levels, live DPS,
# game-over screen, and a detailed TAB stats overlay.

@onready var score_label: Label = $ScoreLabel
@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var game_over_label: Label = $GameOverLabel
@onready var mods_container: HBoxContainer = $ModsContainer
@onready var mods_label: Label = $ModsContainer/ModsLabel
@onready var dps_label: Label = $DpsLabel
@onready var stats_panel: Panel = $StatsPanel
@onready var stats_text: RichTextLabel = $StatsPanel/StatsText
@onready var boss_label: Label = $BossLabel
@onready var boss_hp_bar: ProgressBar = $BossHPBar
@onready var buff_label: Label = $BuffLabel

var heart_texture: Texture2D = preload("res://art/heart.png")

var mod_icons := {
	"spread":  preload("res://art/upgrade_spread.png"),
	"rapid":   preload("res://art/upgrade_rapid.png"),
	"pierce":  preload("res://art/upgrade_pierce.png"),
	"bigshot": preload("res://art/upgrade_bigshot.png"),
	"homing":  preload("res://art/upgrade_homing.png"),
	"orbit":   preload("res://art/upgrade_orbit.png"),
	"rear":    preload("res://art/upgrade_rear.png"),
}

var mod_display := {
	"spread":  { "name": "SPREAD",  "color": Color(0.3, 1.0, 0.3)  },
	"rapid":   { "name": "RAPID",   "color": Color(1.0, 0.6, 0.2)  },
	"pierce":  { "name": "PIERCE",  "color": Color(0.3, 1.0, 1.0)  },
	"bigshot": { "name": "BIG",     "color": Color(1.0, 0.3, 0.3)  },
	"homing":  { "name": "HOMING",  "color": Color(1.0, 0.3, 1.0)  },
	"orbit":   { "name": "ORBIT",   "color": Color(0.3, 1.0, 0.9)  },
	"rear":    { "name": "REAR",    "color": Color(1.0, 1.0, 0.3)  },
}


var _active_buffs := {}  # { "speed": remaining_seconds, ... }

# WorldGenerator reference — fetched in _ready for terrain legend toggling.
var _world_gen: Node2D = null
var _tab_open := false

# Gold display — icon advances through 10 treasure images as thresholds are passed
const GOLD_THRESHOLDS: Array[int] = [4, 10, 40, 100, 400, 1000, 4000, 10000, 40000]
var _gold_textures: Array[Texture2D] = [
	preload("res://art/items/treasure/1.png"),
	preload("res://art/items/treasure/2.png"),
	preload("res://art/items/treasure/3.png"),
	preload("res://art/items/treasure/4.png"),
	preload("res://art/items/treasure/5.png"),
	preload("res://art/items/treasure/6.png"),
	preload("res://art/items/treasure/7.png"),
	preload("res://art/items/treasure/8.png"),
	preload("res://art/items/treasure/9.png"),
	preload("res://art/items/treasure/10.png"),
]
var _gold_icon: TextureRect = null
var _gold_count_label: Label = null

# Powerup popup — created once, reused for each pickup
var _powerup_popup: Label = null
var _powerup_tween: Tween = null

var powerup_display := {
	"life_pot":        { "text": "+1 HP",         "color": Color(1.0, 0.3, 0.3) },
	"nut":             { "text": "+1 HP",         "color": Color(1.0, 0.3, 0.3) },
	"scroll_fire":     { "text": "FIRE POWER",    "color": Color(1.0, 0.5, 0.1) },
	"scroll_ice":      { "text": "FREEZE ALL",    "color": Color(0.4, 0.7, 1.0) },
	"scroll_thunder":  { "text": "THUNDER",       "color": Color(1.0, 1.0, 0.3) },
	"gem_red":         { "text": "+50 SCORE",     "color": Color(1.0, 0.2, 0.2) },
	"gem_green":       { "text": "SPEED BOOST",   "color": Color(0.3, 1.0, 0.4) },
	"gem_purple":      { "text": "SHIELD",        "color": Color(0.7, 0.3, 1.0) },
}

func _ready() -> void:
	# Keep processing even when the tree is paused (Tab overlay / pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_label.visible = false
	stats_panel.visible = false
	boss_label.visible = false
	boss_hp_bar.visible = false
	buff_label.visible = false
	update_score(0)
	_create_gold_display()
	_create_powerup_popup()
	_world_gen = get_parent().get_node_or_null("WorldGenerator")


func _process(delta: float) -> void:
	# Update live DPS display (runs even while paused)
	dps_label.text = "DPS: %.1f" % Stats.get_dps()

	# Tab: open/close overlay — pauses the game tree while held
	var tab_now := Input.is_action_pressed("show_stats")
	if tab_now != _tab_open:
		_tab_open = tab_now
		_set_tab_overlay(tab_now)
	if _tab_open:
		_refresh_stats_panel()

	# Buff timers only tick when the game is running
	if not get_tree().paused:
		_update_buff_display(delta)


func _get_gold_icon_index(gold_count: int) -> int:
	var idx := 0
	for threshold: int in GOLD_THRESHOLDS:
		if gold_count >= threshold:
			idx += 1
		else:
			break
	return mini(idx, _gold_textures.size() - 1)


func _create_gold_display() -> void:
	var hbox := HBoxContainer.new()
	hbox.offset_left = 10.0
	hbox.offset_top = 66.0
	hbox.offset_right = 200.0
	hbox.offset_bottom = 82.0
	hbox.add_theme_constant_override("separation", 3)
	add_child(hbox)

	_gold_icon = TextureRect.new()
	_gold_icon.texture = _gold_textures[0]
	_gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_icon.custom_minimum_size = Vector2(16, 16)
	_gold_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hbox.add_child(_gold_icon)

	_gold_count_label = Label.new()
	_gold_count_label.text = "0"
	_gold_count_label.layout_mode = 2
	_gold_count_label.add_theme_font_size_override("font_size", 11)
	_gold_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_gold_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_gold_count_label.add_theme_constant_override("outline_size", 2)
	_gold_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_gold_count_label)


func update_gold(value: int) -> void:
	if _gold_icon:
		_gold_icon.texture = _gold_textures[_get_gold_icon_index(value)]
	if _gold_count_label:
		_gold_count_label.text = str(value)


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


# Build weapon icon stacks from the player's mod dictionary
func update_mods(mods: Dictionary) -> void:
	# Clear previous icons (keep ModsLabel child)
	for child in mods_container.get_children():
		if child != mods_label:
			child.queue_free()

	var has_any := false
	for mod_name: String in mods:
		var level: int = mods[mod_name]
		if level <= 0:
			continue
		has_any = true
		mods_container.add_child(_build_mod_icon(mod_name, level))

	mods_label.visible = not has_any


func _build_mod_icon(mod_name: String, level: int) -> Control:
	var info: Dictionary = mod_display.get(mod_name, { "name": mod_name.to_upper(), "color": Color.WHITE })
	var col: Color = info["color"]

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 1)

	# Icon
	var icon := TextureRect.new()
	icon.texture = mod_icons.get(mod_name)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	vbox.add_child(icon)

	# Name + level number label
	var name_label := Label.new()
	name_label.text = "%s %d" % [info["name"], level]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", col)
	vbox.add_child(name_label)

	# Level pips
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 1)
	for i in range(3):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(6, 3)
		pip.color = col if i < level else Color(0.3, 0.3, 0.3, 0.5)
		pips.add_child(pip)
	vbox.add_child(pips)

	return vbox


func show_game_over(final_score: int = 0, kills: int = 0) -> void:
	var dps_str := "%.1f" % Stats.get_avg_dps()
	var time_str := Stats.get_time_string()
	game_over_label.text = "GAME OVER\nScore: %d | Kills: %d\nTime: %s | Avg DPS: %s\nPress R to restart" % [
		final_score, kills, time_str, dps_str]
	game_over_label.visible = true


# ── TAB stats overlay ────────────────────────────────────────────────────

func _set_tab_overlay(open: bool) -> void:
	stats_panel.visible = open
	get_tree().paused = open
	if _world_gen and _world_gen.has_method("set_terrain_legend_visible"):
		_world_gen.set_terrain_legend_visible(open)


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

	lines.append("")
	lines.append("[b]— Keys —[/b]")
	lines.append("WASD / Arrows  Move")
	lines.append("SPACE          Dodge")
	lines.append("TAB            Stats (pause)")
	lines.append("G              New terrain")
	lines.append("T              Skip music")
	lines.append("R              Restart (game over)")

	stats_text.text = "\n".join(lines)


# ── Buff display ──────────────────────────────────────────────────────

var _buff_display := {
	"speed":  { "label": "SPEED",  "color": Color(0.3, 1.0, 0.4) },
	"damage": { "label": "FIRE",   "color": Color(1.0, 0.5, 0.2) },
	"shield": { "label": "SHIELD", "color": Color(0.7, 0.3, 1.0) },
}

func on_buff_changed(buff_name: String, active: bool, duration: float) -> void:
	if active:
		_active_buffs[buff_name] = duration
	else:
		_active_buffs.erase(buff_name)


func _update_buff_display(delta: float) -> void:
	# Tick down timers
	var to_remove: Array[String] = []
	for buff_name: String in _active_buffs:
		_active_buffs[buff_name] -= delta
		if _active_buffs[buff_name] <= 0.0:
			to_remove.append(buff_name)
	for bn: String in to_remove:
		_active_buffs.erase(bn)

	if _active_buffs.is_empty():
		buff_label.visible = false
		return

	buff_label.visible = true
	var parts: Array[String] = []
	for buff_name: String in _active_buffs:
		var info: Dictionary = _buff_display.get(buff_name, { "label": buff_name.to_upper(), "color": Color.WHITE })
		var secs: float = _active_buffs[buff_name]
		parts.append("%s %.0fs" % [info["label"], secs])
	buff_label.text = " | ".join(parts)


# ── Boss announcements ─────────────────────────────────────────────────

func show_boss_fight() -> void:
	boss_label.text = "BOSS FIGHT"
	boss_label.modulate = Color(1, 0.15, 0.1, 0)
	boss_label.scale = Vector2(0.3, 0.3)
	boss_label.pivot_offset = boss_label.size / 2.0
	boss_label.visible = true
	var tw := create_tween()
	# Slam in: scale up + fade in
	tw.tween_property(boss_label, "scale", Vector2(1.2, 1.2), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(boss_label, "modulate", Color(1, 0.15, 0.1, 1), 0.2)
	# Settle to normal scale
	tw.tween_property(boss_label, "scale", Vector2(1.0, 1.0), 0.15)
	# Hold
	tw.tween_interval(2.0)
	# Fade out
	tw.tween_property(boss_label, "modulate", Color(1, 0.15, 0.1, 0), 0.6)
	tw.tween_callback(func(): boss_label.visible = false)


func show_boss_hp_bar(maximum: int) -> void:
	boss_hp_bar.max_value = maximum
	boss_hp_bar.value = maximum
	boss_hp_bar.visible = true


func update_boss_hp(current: int, maximum: int) -> void:
	boss_hp_bar.max_value = maximum
	boss_hp_bar.value = current
	if current <= 0:
		boss_hp_bar.visible = false


func show_boss_defeated() -> void:
	boss_label.text = "DEFEATED"
	boss_label.modulate = Color(1, 0.85, 0.1, 0)
	boss_label.scale = Vector2(1.0, 1.0)
	boss_label.pivot_offset = boss_label.size / 2.0
	boss_label.visible = true
	var tw := create_tween()
	# Fade in + slight scale punch
	tw.tween_property(boss_label, "modulate", Color(1, 0.85, 0.1, 1), 0.3)
	tw.parallel().tween_property(boss_label, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(boss_label, "scale", Vector2(1.0, 1.0), 0.15)
	# Hold
	tw.tween_interval(2.5)
	# Fade out
	tw.tween_property(boss_label, "modulate", Color(1, 0.85, 0.1, 0), 0.8)
	tw.tween_callback(func(): boss_label.visible = false)


# ── Powerup popup ─────────────────────────────────────────────────────

func _create_powerup_popup() -> void:
	_powerup_popup = Label.new()
	_powerup_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_powerup_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_powerup_popup.anchors_preset = Control.PRESET_CENTER
	_powerup_popup.anchor_left = 0.5
	_powerup_popup.anchor_top = 0.5
	_powerup_popup.anchor_right = 0.5
	_powerup_popup.anchor_bottom = 0.5
	_powerup_popup.offset_left = -160.0
	_powerup_popup.offset_top = 20.0
	_powerup_popup.offset_right = 160.0
	_powerup_popup.offset_bottom = 55.0
	_powerup_popup.add_theme_font_size_override("font_size", 20)
	_powerup_popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_powerup_popup.add_theme_constant_override("outline_size", 3)
	_powerup_popup.visible = false
	add_child(_powerup_popup)


func show_powerup_effect(powerup_type: String) -> void:
	var info: Dictionary = powerup_display.get(powerup_type,
		{ "text": powerup_type.to_upper(), "color": Color.WHITE })
	var col: Color = info["color"]

	# Kill previous animation
	if _powerup_tween and _powerup_tween.is_valid():
		_powerup_tween.kill()

	_powerup_popup.text = info["text"]
	_powerup_popup.add_theme_color_override("font_color", col)
	_powerup_popup.modulate = Color(col.r, col.g, col.b, 0)
	_powerup_popup.scale = Vector2(0.4, 0.4)
	_powerup_popup.pivot_offset = _powerup_popup.size / 2.0
	_powerup_popup.visible = true

	_powerup_tween = create_tween()
	# Pop in: scale up + fade in
	_powerup_tween.tween_property(_powerup_popup, "scale", Vector2(1.2, 1.2), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_powerup_tween.parallel().tween_property(_powerup_popup, "modulate", Color(col.r, col.g, col.b, 1), 0.1)
	# Settle
	_powerup_tween.tween_property(_powerup_popup, "scale", Vector2(1.0, 1.0), 0.08)
	# Hold
	_powerup_tween.tween_interval(0.8)
	# Float up + fade out
	_powerup_tween.tween_property(_powerup_popup, "offset_top", _powerup_popup.offset_top - 15.0, 0.4)
	_powerup_tween.parallel().tween_property(_powerup_popup, "modulate", Color(col.r, col.g, col.b, 0), 0.4)
	# Reset and hide
	_powerup_tween.tween_callback(func():
		_powerup_popup.visible = false
		_powerup_popup.offset_top = 20.0
	)
