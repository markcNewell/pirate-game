class_name DeckProxy
extends StaticBody3D
## A still, invisible copy of the deck, parked far below the world. Players on board walk on
## this instead of the moving ship, so the rocking and turning never push them about; what
## you see is their proxy position carried onto the real ship (see LocalPlayer).

const ORIGIN := Vector3(0, -2000, 0)
const LAYER := 2


## The hull whose deck this is now (the one the local player stands on).
var hull_type := -1
var _shape: ConcavePolygonShape3D


func _ready() -> void:
	position = ORIGIN
	collision_layer = LAYER
	collision_mask = 0
	_shape = ConcavePolygonShape3D.new()
	_shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = _shape
	add_child(holder)
	use(Hull.galleon())


## Switches to `hull`'s deck (boarding a sloop, or back aboard a galleon).
func use(hull: Hull) -> void:
	if hull.type == hull_type or _shape == null:
		return
	hull_type = hull.type
	_shape.set_faces(hull.deck_faces())


## Ship-frame position <-> proxy world position.
static func to_proxy(local: Vector3) -> Vector3:
	return ORIGIN + local


static func from_proxy(p: Vector3) -> Vector3:
	return p - ORIGIN
