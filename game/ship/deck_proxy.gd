class_name DeckProxy
extends StaticBody3D
## A still, invisible copy of the deck, parked far below the world. Players on board walk on
## this instead of the moving ship, so the rocking and turning never push them about; what
## you see is their proxy position carried onto the real ship (see LocalPlayer).

const ORIGIN := Vector3(0, -2000, 0)
const LAYER := 2


func _ready() -> void:
	position = ORIGIN
	collision_layer = LAYER
	collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(ShipShape.deck_faces())
	var holder := CollisionShape3D.new()
	holder.shape = shape
	add_child(holder)


## Ship-frame position <-> proxy world position.
static func to_proxy(local: Vector3) -> Vector3:
	return ORIGIN + local


static func from_proxy(p: Vector3) -> Vector3:
	return p - ORIGIN
