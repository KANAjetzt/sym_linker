@tool
extends EditorPlugin


var context_actions


func _enter_tree() -> void:
	context_actions = SymLinkerFileSystemContextActions.new(get_editor_interface())
	get_editor_interface().get_base_control().add_child(context_actions)


func _exit_tree() -> void:
	context_actions.free()


func _get_plugin_name():
	return "Sym Linker"


func _get_plugin_icon():
	return get_editor_interface().get_theme_icon(&"ExternalLink", &"EditorIcons")
