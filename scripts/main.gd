extends Node2D

@onready var b1: Button = $GridButtons/Button1
@onready var b2: Button = $GridButtons/Button2
@onready var b3: Button = $GridButtons/Button3
@onready var b4: Button = $GridButtons/Button4
@onready var b5: Button = $GridButtons/Button5
@onready var b6: Button = $GridButtons/Button6
@onready var b7: Button = $GridButtons/Button7
@onready var b8: Button = $GridButtons/Button8
@onready var b9: Button = $GridButtons/Button9

@onready var play_button: Button = $PlayButton

@onready var status_label: Label = $Labels/StatusLabel
@onready var round_label: Label = $Labels/RoundLabel

# General
const	grid_size := 9
enum	states {START, ROUND_START, GAMEOVER, SETUP_INPUT, CHECK_INPUT, DISPLAY, ADD_RANDOM_PATTERN}
var		buttons: Array[Button] = []
var		rng := RandomNumberGenerator.new()
var		round_num := 1
var		state := states.START

# Round Start
var		round_start_rate := 1
var		round_start_timer := 0.0

# Display
enum	ds_states {START, DISPLAY_TIMER, IN_BETWEEN, LAST_TIMER}
var		ds_state := ds_states.START
var		display_rate := 1
var		display_in_between_rate := 0.1
var		display_last_rate := 1.5
var		ds_timer := 0.0

# Patterns
var		patterns = []
var		patterns_index := 0
var		current_pattern_size := 0

# Colors
const		col_pressed := Color.WHITE
const		col_wrong := Color.INDIAN_RED
const		col_correct := Color.GRAY
const		col_normal := Color(0.431, 0.431, 0.431)

func _ready():
	rng.randomize()
	buttons = [b1, b2, b3, b4, b5, b6, b7, b8, b9]
	all_clickable(false)
	
func set_one_button_color(button: Button, color: Color):
	var style_dup := button.get_theme_stylebox("pressed").duplicate()
	style_dup.bg_color = color
	button.add_theme_stylebox_override("pressed", style_dup)
	
func set_all_button_colors(color: Color):
	for button in buttons:
		var style_dup := button.get_theme_stylebox("pressed").duplicate()
		style_dup.bg_color = color
		button.add_theme_stylebox_override("pressed", style_dup)

func _process(delta):
	if Input.is_action_just_pressed("R"):
		get_tree().reload_current_scene()

	match state:
		states.START:
			play_button.text = "Play"
			if play_button.button_pressed or Input.is_action_just_pressed("C"):
				play_button.hide()
				state = states.ROUND_START
		states.ROUND_START:
			all_clickable(false)
			set_all_button_colors(col_pressed)
			status_label.text = "Get ready!"			
			round_label.text = "Round " + str(round_num)
			patterns_index = 0
			disable_pattern()
			round_start_timer += delta
			if round_start_timer >= round_start_rate:
				round_start_timer = 0
				state = states.ADD_RANDOM_PATTERN
		states.ADD_RANDOM_PATTERN:
			status_label.text = ""
			patterns.append(generate_random_pattern())
			state = states.DISPLAY
		states.DISPLAY:
			display_patterns(delta)
		states.SETUP_INPUT:
			all_clickable(true)
			set_all_button_colors(col_normal)
			disable_pattern()
			current_pattern_size = get_pattern_size()
			state = states.CHECK_INPUT
		states.CHECK_INPUT:
			check_player_input()
		states.GAMEOVER:
			all_clickable(false)
			play_button.text = "Restart"
			play_button.show()
			if play_button.button_pressed:
				play_button.hide()
				reset_game()

func display_patterns(delta):
	ds_timer += delta
	match ds_state:
		ds_states.START:
			ds_timer = 0
			patterns_index = 0
			activate_pattern(patterns[patterns_index])
			if patterns.size() == 1:
				ds_state = ds_states.LAST_TIMER
			else:
				ds_state = ds_states.DISPLAY_TIMER
		ds_states.DISPLAY_TIMER:
			if ds_timer >= display_rate:
				ds_timer = 0
				disable_pattern()
				ds_state = ds_states.IN_BETWEEN
		ds_states.IN_BETWEEN:
			if ds_timer >= display_in_between_rate:
				ds_timer = 0
				patterns_index += 1
				activate_pattern(patterns[patterns_index])
				if patterns_index == patterns.size() - 1:
					ds_state = ds_states.LAST_TIMER
				else:
					ds_state = ds_states.DISPLAY_TIMER
		ds_states.LAST_TIMER:
			if ds_timer >= display_last_rate:
				ds_timer = 0
				patterns_index = 0
				ds_state = ds_states.START
				state = states.SETUP_INPUT

func reset_game():
	round_num = 1
	patterns.clear()
	state = states.ROUND_START

func check_player_input():
	var num_correct := 0
	for i in grid_size:
		if buttons[i].button_pressed:
			# Disable clicking the button off again
			buttons[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Compare with current pattern
			if patterns[patterns_index][i]:
				num_correct += 1
				set_one_button_color(buttons[i], col_pressed)
				if num_correct == current_pattern_size:
					patterns_index += 1
					if patterns_index < patterns.size():
						state = states.SETUP_INPUT
					else:
						round_num += 1
						state = states.ROUND_START
			else:
				set_one_button_color(buttons[i], col_wrong)
				reveal_correct_pattern()
				state = states.GAMEOVER
				break

func reveal_correct_pattern():
	for i in grid_size:
		if patterns[patterns_index][i] and !buttons[i].button_pressed:
			set_one_button_color(buttons[i], col_correct)
			buttons[i].button_pressed = true

func get_pattern_size():
	var size := 0;
	for p in patterns[patterns_index]:
		if p:
			size += 1
	return size


func all_clickable(status):
	for b in buttons:
		if status:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE

func generate_random_pattern():
	var temp = []
	var valid := false
	while !valid:
		# Append true or false
		for i in grid_size:
			temp.append(rng.randi() % 2 == 0)
		# Check for at least one true statment
		for boolean in temp:
			if boolean:
				valid = true
				break
	return temp

func activate_pattern(pattern):
	for i in grid_size:
		buttons[i].button_pressed = pattern[i]
		
func disable_pattern():
	for i in grid_size:
		buttons[i].button_pressed = true
		buttons[i].button_pressed = false

