extends "res://tests/support/case.gd"


## Nothing drawn on the HUD may take the mouse (a captured mouse sits at the centre of the
## screen; a control there once swallowed every movement and the view would not turn). Only
## the pause menu's buttons and sliders may.
func test_hud_lets_the_mouse_through() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := Hud.new()
	tree.root.add_child(hud)
	if hud.get_child_count() == 0:
		# The test runner's tree may not call _ready on its own yet.
		hud._ready()
	check(hud.get_child_count() > 0, "the HUD built its controls")
	var takers: Array[String] = []
	_collect_takers(hud, hud._menu, takers)
	check(takers.is_empty(), "these HUD controls take the mouse: %s" % ", ".join(takers))
	hud.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _collect_takers(node: Node, menu: Node, out: Array[String]) -> void:
	for child in node.get_children():
		if child == menu:
			continue
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append("%s (%s)" % [child.name, child.get_class()])
		_collect_takers(child, menu, out)
