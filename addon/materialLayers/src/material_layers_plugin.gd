@tool
extends EditorPlugin

var _inspector_plugin: LayerStackInspectorPlugin

func _enter_tree() -> void:
    # plugin.cfg has no compatibility field, so enforce the floor here: the
    # generated shaders write BENT_NORMAL_MAP, which needs 4.5 or newer.
    var v := Engine.get_version_info()
    if v.major < 4 or (v.major == 4 and v.minor < 5):
        push_error("Material Layers requires Godot 4.5 or newer; this is Godot %s. Generated shaders will not compile." % v.string)
    _inspector_plugin = LayerStackInspectorPlugin.new()
    add_inspector_plugin(_inspector_plugin)

func _exit_tree() -> void:
    remove_inspector_plugin(_inspector_plugin)
    _inspector_plugin = null
