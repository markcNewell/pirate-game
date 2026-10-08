class_name CrabView
extends Node3D
## The tales' crab (the one that ran off with Captain Coco), as players see it: the beach crabs'
## model but big and smug, scuttling sideways with a waddle, and flipped on its back once
## caught. It answers the same calls as SkeletonView, so the game can treat it as one.

var _model: MeshInstance3D
var _clock := randf() * 10.0
var _moving := false
var _fallen := 0.0
var _flash := 0.0


func _ready() -> void:
	_model = Toon.instance(Crabs.crab_mesh())
	_model.scale = Vector3.ONE * 2.2
	add_child(_model)


## `pose` is where it stands; `walking` and `fallen` come from the snapshot.
func place(pose: Transform3D, walking: bool, fallen: bool, delta: float) -> void:
	global_transform = pose
	_moving = walking
	_clock += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if fallen:
		_fallen = minf(1.0, _fallen + delta * 4.0)
	# A sideways scuttle: the shell rocks and bobs while it runs.
	var rock := (0.25 * sin(_clock * 22.0)) if _moving and _fallen <= 0.0 else 0.04 * sin(_clock * 2.0)
	_model.rotation = Vector3(0.0, PI / 2.0, rock + _fallen * PI)
	_model.position.y = (0.03 * absf(sin(_clock * 22.0)) if _moving else 0.0) + _fallen * 0.15


func set_digging(_on: bool) -> void:
	pass


func swing() -> void:
	pass


func hurt() -> void:
	_flash = 1.0


func shield_hit(_knocked: bool) -> void:
	pass
