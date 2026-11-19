extends Control

const DRIVE_SCENE := "res://scenes/main/main_game.tscn"
const CREDIT := "برمجة وتطوير معتز العلقمي – تعز – اليمن – 2026م"

@onready var panel: VBoxContainer = %Menu
@onready var about: VBoxContainer = %About
@onready var resume_button: Button = %Continue


func _ready() -> void:
	resume_button.disabled = not PersistenceManager.save_data.get("has_driven", false)
	resume_button.pressed.connect(_start.bind(true))
	%Start.pressed.connect(_start.bind(false))
	%ShowAbout.pressed.connect(_show_about.bind(true))
	%Back.pressed.connect(_show_about.bind(false))
	%Credit.text = CREDIT
	%Start.grab_focus()


func _start(resume: bool) -> void:
	QualityManager.resume_drive = resume
	get_tree().change_scene_to_file(DRIVE_SCENE)


func _show_about(show_about: bool) -> void:
	panel.visible = not show_about
	about.visible = show_about
	if show_about:
		%Back.grab_focus()
	else:
		%ShowAbout.grab_focus()
