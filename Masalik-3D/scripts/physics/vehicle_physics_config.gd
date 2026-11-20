class_name VehiclePhysicsConfig
extends Resource

@export_group("Chassis")
@export var mass_kg := 1920.0
@export var center_of_mass_offset := Vector3(0.0, -0.36, 0.0)
@export var wheelbase := 2.72
@export var track_width := 1.94
@export var wheel_radius := 0.45
@export var wheel_width := 0.32
@export var width := 1.8
@export var length := 4.25
@export var roof_height := 1.33
@export var cargo_limit := 250.0
@export var drag_area := 1.08
@export var rolling_resistance := 0.012
var tire_compound := "all_terrain"

@export_group("Suspension")
@export var suspension_rest_length := 0.64
@export var suspension_max_travel := 0.35
@export var spring_stiffness := 43000.0
@export var spring_damping := 5500.0
@export var anti_roll_stiffness := 9400.0

@export_group("Engine and transmission")
@export var torque_nm := 450.0
@export var idle_rpm := 800.0
@export var redline_rpm := 6000.0
@export var fuel_capacity := 85.0
@export var fuel_liters_per_min := 1.35
@export var final_drive := 3.91
@export var reverse_ratio := 3.45
@export var ratios := PackedFloat32Array([3.82, 2.34, 1.58, 1.17, 0.92, 0.74])
@export var default_drivetrain := "4H"
@export var supported_modes := PackedStringArray(["2H", "4H", "4L"])

@export_group("Steering and brakes")
@export var max_brake_force := 24000.0
@export var handbrake_force := 19000.0
@export var max_steer_angle_deg := 33.0
@export var steer_response_speed := 3.4
@export var asphalt_friction := 1.08
@export var dirt_friction := 0.72
