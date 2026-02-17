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
@onready var mute_button: Button = $MuteButton

@onready var highscore_label = $Labels/HighscoreLabel
@onready var score_label: Label = $Labels/ScoreLabel
@onready var status_label: Label = $Labels/StatusLabel
@onready var leaderboard_name: Label = $Labels/LeaderboardName
@onready var leaderboard_score:Label = $Labels/LeaderboardScore
@onready var leaderboard_info = $Labels/LeaderboardInfo

@onready var input_name = $Labels/InputName

@onready var snd_correct_pattern: AudioStreamPlayer2D = $Sounds/snd_correct_pattern
@onready var snd_play: AudioStreamPlayer2D = $Sounds/snd_play
@onready var snd_select: AudioStreamPlayer2D = $Sounds/snd_select
@onready var snd_wrong: AudioStreamPlayer2D = $Sounds/snd_wrong
@onready var snd_sequence_complete = $Sounds/snd_sequence_complete

@onready var http_request = $HTTPRequest

# General
const	grid_size := 9
enum	states {START,
				ROUND_START,
				ADD_RANDOM_PATTERN,
				DISPLAY,
				SETUP_INPUT,
				CHECK_INPUT,
				CORRECT_PATTERN,
				LEADERBOARD_ENTRY,
				GAMEOVER}
var		buttons: Array[Button] = []
var		rng := RandomNumberGenerator.new()
var		score := 0
var 	highscore := 0
var		last_highscore := 0
var		state := states.START
var		timer := 0.0

# Http requests
var		last_request := ""

# Round Start
const	round_start_rate := 1

# Display
enum	ds_states {START, DISPLAY_TIMER, IN_BETWEEN, LAST_TIMER}
const	starting_display_rate := 1.0
const 	min_display_rate := 0.25
const	change_display_rate	:= 0.05
const	display_in_between_rate := 0.25
const	display_last_rate := 1.25
const	correct_pattern_rate := 0.4
var		ds_state := ds_states.START
var		display_rate := starting_display_rate

# Patterns
var		patterns = []
var		patterns_index := 0
var		current_pattern_size := 0

# Status
const	txt_round_start := "loading\ngame"
const	txt_display := "new\nsequence"
const 	txt_input := "enter\npattern(s)"
const	txt_correct := "pattern\ncomplete"
const	txt_wrong := "gameover\nplay again?"
const 	txt_complete := "sequence\ncomplete"
const	txt_leaderboard := "new\nhighscore"

# Colors
const		col_pressed := Color(0.91, 0.91, 0.91)
const		col_wrong := Color(0.914, 0.247, 0.106)
const		col_reveal := Color.DARK_GRAY
const		col_correct := Color(0.267, 0.773, 0.4)
const		col_normal := Color(0.431, 0.431, 0.431)

func _ready():
	rng.randomize()
	buttons = [b1, b2, b3, b4, b5, b6, b7, b8, b9]
	all_clickable(false)
	
	

	
	# Connect HTTPRequest signal
	http_request.request_completed.connect(self._http_request_completed)
	get_scores()

func _process(delta):
	if mute_button.button_pressed:
		var bus_idx = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		var bus_idx = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus_idx, false)	
	match state:
		states.START:
			display_score(score_label, score)
			display_highscore()
			if play_button.button_pressed:
				snd_play.play()
				play_button.disabled = true
				state = states.ROUND_START
		states.ROUND_START:
			all_clickable(false)
			set_all_button_colors(col_pressed)
			status_label.text = txt_round_start			
			display_score(score_label, score)
			display_highscore()
			patterns_index = 0
			disable_pattern()
			timer += delta
			if timer >= round_start_rate:
				timer = 0
				state = states.ADD_RANDOM_PATTERN
		states.ADD_RANDOM_PATTERN:
			patterns.append(generate_random_pattern())
			state = states.DISPLAY
		states.DISPLAY:
			display_patterns(delta)
		states.SETUP_INPUT:
			status_label.text = txt_input
			all_clickable(true)
			set_all_button_colors(col_normal)
			disable_pattern()
			reset_button_correct()
			current_pattern_size = get_pattern_size()
			state = states.CHECK_INPUT
		states.CHECK_INPUT:
			check_player_input()
		states.CORRECT_PATTERN:
			timer += delta
			if timer >= correct_pattern_rate:
				timer = 0
				if patterns_index < patterns.size():
					state = states.SETUP_INPUT
				else:
					score += 1
					state = states.ROUND_START
		states.LEADERBOARD_ENTRY:
			if input_name.text.length() == 3:
				leaderboard_info.text = "hit enter!"
				if Input.is_action_just_pressed("Enter"):
					submit_score(input_name.text, score)
					input_name.text = ""
					input_name.release_focus()
					play_button.disabled = false
					leaderboard_info.text = "-----"
					input_name.placeholder_text = "-----"
					status_label.text = txt_wrong
			if play_button.button_pressed:
				play_after_gameover()
		states.GAMEOVER:
			all_clickable(false)
			if score > last_highscore:
				input_name.grab_focus()
				leaderboard_info.text = "new highscore!"
				input_name.placeholder_text = "type initials (3)"
				status_label.text = txt_leaderboard
				state = states.LEADERBOARD_ENTRY
				return
			status_label.text = txt_wrong
			play_button.disabled = false
			if play_button.button_pressed:
				play_after_gameover()

func play_after_gameover():
	play_button.disabled = true
	snd_play.play()
	reset_game()

func submit_score(player_name: String, submissionScore: int):
	last_request = "POST"
	
	var url = "https://patternrecall-default-rtdb.europe-west1.firebasedatabase.app/messages.json"
	var body = JSON.stringify({
		"name": player_name,
		"score": submissionScore,
		"timestamp": Time.get_unix_time_from_system()
	})

	http_request.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	
func get_scores():
	last_request = "GET"
	var url = "https://patternrecall-default-rtdb.europe-west1.firebasedatabase.app/messages.json?orderBy=%22score%22&limitToLast=10"
	http_request.request(url)

func _http_request_completed(_result, _response_code, _headers, body):
	if last_request == "POST":
		print("Score posted. Now requesting leaderboard")
		get_scores()
	else:
		var text = body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if data == null or not data is Dictionary:
			print("No leaderboard data or parse error")
			return
		update_leaderboard(data)

func update_leaderboard(data):
	# Convert dict to array for sorting
	var entries = []
	for key in data.keys():
		entries.append(data[key])
	
	# Sort by score desc, then timestamp asc on ties
	entries.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["timestamp"] < b["timestamp"]
	)
	
	# Update the text on the leaderboard
	var name_str = "name\n"
	var score_str = "score\n"
	for entry in entries:
		name_str += str(entry["name"]) + "\n"
		score_str += str(entry["score"]) + "\n"
	leaderboard_name.text = name_str
	leaderboard_score.text = score_str
	
	# Store the last_high_score
	if entries.size() == 10:
		last_highscore = entries[entries.size() - 1]["score"]

func reset_button_correct():
	for i in grid_size:
		buttons[i].correct = false

func display_score(label, num):
	var temp := ""
	if score < 10:
		temp = "000" + str(num)
	elif score < 100:
		temp = "00" + str(num)
	elif score < 1000:
		temp = "0" + str(num)
	else:
		temp = str(num)
	label.text = temp
	
func display_highscore():
	if (score > highscore):
		highscore = score
		display_score(highscore_label, highscore)

func display_patterns(delta):
	timer += delta
	match ds_state:
		ds_states.START:
			timer = 0
			patterns_index = 0
			status_label.text = txt_display
			activate_pattern(patterns[patterns_index])
			if patterns.size() == 1:
				ds_state = ds_states.LAST_TIMER
			else:
				ds_state = ds_states.DISPLAY_TIMER
		ds_states.DISPLAY_TIMER:
			if timer >= display_rate:
				timer = 0
				disable_pattern()
				ds_state = ds_states.IN_BETWEEN
		ds_states.IN_BETWEEN:
			if timer >= display_in_between_rate:
				timer = 0
				patterns_index += 1
				activate_pattern(patterns[patterns_index])
				if patterns_index == patterns.size() - 1:
					ds_state = ds_states.LAST_TIMER
				else:
					ds_state = ds_states.DISPLAY_TIMER
		ds_states.LAST_TIMER:
			if timer >= display_last_rate:
				timer = 0
				patterns_index = 0
				ds_state = ds_states.START
				state = states.SETUP_INPUT

func reset_game():
	score = 0
	display_rate = starting_display_rate
	patterns.clear()
	state = states.ROUND_START

func check_player_input():
	for i in grid_size:
		if buttons[i].button_pressed and !buttons[i].correct:
			# Activate press animation
			#buttons[i].press_animation = true
			# Disable clicking the button off again
			buttons[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Compare with current pattern
			if patterns[patterns_index][i]:
				buttons[i].correct = true
				set_one_button_color(buttons[i], col_pressed)
				if is_pattern_complete():
					input_pattern_complete()
					break
				else:
					snd_select.play()
			else:
				set_one_button_color(buttons[i], col_wrong)
				reveal_correct_pattern()
				snd_wrong.play()
				state = states.GAMEOVER
				break

func input_pattern_complete():
	patterns_index += 1
	highlight_correct_pattern()
	status_label.text = txt_correct
	if patterns_index < patterns.size():
		status_label.text = txt_correct
		snd_correct_pattern.play()
	else:
		status_label.text = txt_complete
		snd_sequence_complete.play()
	if display_rate > min_display_rate:
		display_rate -= change_display_rate		
	state = states.CORRECT_PATTERN

func is_pattern_complete():
	for i in grid_size:
		if buttons[i].correct != patterns[patterns_index][i]:
			return false
	return true

func highlight_correct_pattern():
	for button in buttons:
		if button.button_pressed:
			set_one_button_color(button, col_correct)

func reveal_correct_pattern():
	for i in grid_size:
		if patterns[patterns_index][i] and !buttons[i].button_pressed:
			set_one_button_color(buttons[i], col_reveal)
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
		for i in grid_size:
			if temp[i]:
				valid = true
				break
		# Check for duplicate pattern
		if valid and score < 512:
			for pattern in patterns:
				var dup = true
				for i in grid_size:
					if temp[i] != pattern[i]:
						dup = false
						break
				if dup:
					valid = false
					break
		if !valid:
			temp.clear()
	return temp

func activate_pattern(pattern):
	for i in grid_size:
		buttons[i].button_pressed = pattern[i]
		
func disable_pattern():
	for i in grid_size:
		#buttons[i].button_pressed = true
		buttons[i].button_pressed = false

func set_one_button_color(button: Button, color: Color):
	var style_dup := button.get_theme_stylebox("pressed").duplicate()
	style_dup.bg_color = color
	button.add_theme_stylebox_override("pressed", style_dup)
	
func set_all_button_colors(color: Color):
	for button in buttons:
		var style_dup := button.get_theme_stylebox("pressed").duplicate()
		style_dup.bg_color = color
		button.add_theme_stylebox_override("pressed", style_dup)
