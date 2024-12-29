@tool
class_name SymLinkerFileSystemContextActions
extends Control


var file_dialog := FileDialog.new()
var src_dir := ""
var dst_dir := ""
var editor_interface: EditorInterface

class ContextActionOptions:
	extends Resource

	var icon: StringName
	var title: String
	var meta_key: StringName
	var tooltip: String

	func _init(_icon, _title, _meta_key, _tooltip) -> void:
		icon = _icon
		title = _title
		meta_key = _meta_key
		tooltip = _tooltip


func _init(_editor_interface: EditorInterface) -> void:
	editor_interface = _editor_interface
	
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.min_size = Vector2(800, 400)
	file_dialog.title = "Select Directory"

	connect_file_system_context_actions(editor_interface.get_file_system_dock())


func _ready() -> void:
	add_child(file_dialog)

	file_dialog.dir_selected.connect(_on_file_dialog_dir_selected)


func connect_file_system_context_actions(file_system : FileSystemDock) -> void:
	var file_tree : Tree
	var file_list : ItemList

	for node in file_system.get_children():
		if is_instance_of(node, SplitContainer):
			file_tree = node.get_child(0)
			file_list = node.get_child(1).get_child(1)
			break

	for node in file_system.get_children():
		var context_menu : PopupMenu = node as PopupMenu
		if not context_menu:
			continue

		context_menu.id_pressed.connect(_on_file_system_context_menu_pressed.bind(context_menu))

		var signals := context_menu.get_signal_connection_list(&"id_pressed")
		if not signals.is_empty():
			match signals[0]["callable"].get_method():
				&"FileSystemDock::_tree_rmb_option":
					context_menu.about_to_popup.connect(_on_file_tree_context_actions_about_to_popup.bind(context_menu, file_tree))
				&"FileSystemDock::_file_list_rmb_option":
					context_menu.about_to_popup.connect(_on_file_list_context_actions_about_to_popup.bind(context_menu, file_tree))


# Called every time the file system context actions pop up
# Since they are dynamic, they are cleared every time and need to be refilled
func add_custom_context_actions(context_menu: PopupMenu, file_path: String) -> void:
	context_menu.add_separator()

	add_context_action(
		context_menu,
		file_path,
		ContextActionOptions.new(
			&"ExternalLink",
			"Create symlink",
			&"sym_link_dir",
			"Create a symlink at"
		)
	)


func add_context_action(context_menu: PopupMenu, path: String, options: ContextActionOptions) -> void:
	context_menu.add_icon_item(
				editor_interface.get_base_control().get_theme_icon(options.icon, &"EditorIcons"),
				"SymLinker: %s" % options.title
			)
	context_menu.set_item_metadata(
		context_menu.get_item_count() -1,
		{ options.meta_key: path }
	)
	context_menu.set_item_tooltip(
		context_menu.get_item_count() -1,
		"%s: \n%s" %
		[options.tooltip, str(path).trim_prefix("[").trim_suffix("]").replace(", ", "\n")]
	)


func handle_sym_linking(metadata: Dictionary) -> void:
	var dir: String = metadata.sym_link_dir
	dst_dir = dir

	if not src_dir.is_empty():
		var split := src_dir.split("/")
		file_dialog.current_dir = src_dir.trim_suffix(split[-1])

	file_dialog.popup_centered()


func _on_file_tree_context_actions_about_to_popup(context_menu: PopupMenu, tree: Tree) -> void:
	var selected := tree.get_next_selected(null)
	if not selected:		# Empty space was clicked
		return

	# multiselection
	var file_paths: Array[String] = []
	while selected:
		var file_path = selected.get_metadata(0)
		if file_path is String:
			file_paths.append(file_path)
		selected = tree.get_next_selected(selected)

	add_custom_context_actions(context_menu, file_paths[0].get_base_dir())


func _on_file_list_context_actions_about_to_popup(context_menu: PopupMenu, list: ItemList) -> void:
	if not list.get_selected_items().size() > 0:		# Empty space was clicked
		return

	var file_paths := []
	for item_index in list.get_selected_items():
		var file_path = list.get_item_metadata(item_index)
		if file_path is String:
			file_paths.append(file_path)

	add_custom_context_actions(context_menu, file_paths[0].get_base_dir())


func _on_file_system_context_menu_pressed(id: int, context_menu: PopupMenu) -> void:
	var file_paths: PackedStringArray
	var metadata = context_menu.get_item_metadata(id)
	var current_script: GDScript

	if file_dialog.visible:
		return

	if metadata is Dictionary and metadata.has("sym_link_dir"):
		handle_sym_linking(metadata)


func _on_file_dialog_dir_selected(dir: String) -> void:
	src_dir = dir

	if not src_dir.is_empty() and not dst_dir.is_empty():
		var error := SymLinkerFileSystemLink.mk_soft_dir(src_dir, dst_dir)
		if not error == OK:
			print("SymLinker: ERROR: encountered error \"%s\" linking \"%s\" to \"%s\"." % [error_string(error), src_dir, dst_dir])
			return

		print_rich("[color=#00ff0095]SymLinker: Successfully linked \"%s\" in \"%s\" [/color]" % [src_dir, dst_dir])
		editor_interface.get_resource_filesystem().scan_sources()
	else:
		print("SymLinker: ERROR: No dir selected.")
