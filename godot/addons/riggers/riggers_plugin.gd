@tool
extends EditorPlugin
## Adds a top-level "Riggers" menu to the editor menu bar (next to Scene / Project / Debug / Editor /
## Help). "Rig Piece" launches the Piece Rigger scene in play mode — a runnable scene (so it previews
## fully) where you place an arrow per blend shape and save it to a WallPiece config. The menu is
## injected into the editor's internal MenuBar, so it degrades gracefully if a future Godot changes
## the editor layout.

var _menu: PopupMenu


func _enter_tree() -> void:
	var bar := _find_menu_bar(EditorInterface.get_base_control())
	if bar == null:
		push_warning("Riggers: editor MenuBar not found — top-level 'Riggers' menu not added.")
		return
	_menu = PopupMenu.new()
	_menu.name = "Riggers"
	_menu.add_item("Rig Piece", 0)
	_menu.id_pressed.connect(_on_menu_id)
	bar.add_child(_menu)
	bar.set_menu_title(bar.get_menu_count() - 1, "Riggers")


func _exit_tree() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()


func _find_menu_bar(node: Node) -> MenuBar:
	if node is MenuBar:
		return node as MenuBar
	for c in node.get_children():
		var found := _find_menu_bar(c)
		if found != null:
			return found
	return null


func _on_menu_id(id: int) -> void:
	if id == 0:
		EditorInterface.play_custom_scene("res://addons/riggers/piece_rig.tscn")
