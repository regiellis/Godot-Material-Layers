## Contains [code]SurfaceMaterial[/code] & mask texture or [code]MaskMaterial[/code].
## [url=https://www.foyez.es/docs/material-layers]Learn more[/url]
@icon ("res://addons/materialLayers/icons/materialLayer.svg")
@tool
class_name MaterialLayer
extends Resource

signal material_replaced
signal mask_updated
## Emitted when a change alters the generated shader's structure, so the
## stack knows a recompile is needed rather than just a value sync.
signal structure_changed

@export var label: String = "Layer":
	set(val):
		label = val

@export var active: bool = true:
	set(val):
		active = val
		emit_changed()
		structure_changed.emit()
    
## Stored by reference: editing the assigned material asset updates every
## stack that uses it. For a per-stack copy, use Godot's own Make Unique.
@export var surface_material: ShaderMaterial:
	set(val):
		surface_material = val
		if surface_material and surface_material.get("use_as_overlay"):
			mask_active = false
		material_replaced.emit()
		emit_changed()

enum MaskType { TEXTURE, MATERIAL }


@export var mask_active: bool = true:
	set(val):
		mask_active = val
		emit_changed()
		notify_property_list_changed()
		structure_changed.emit()

@export var mask_type: MaskType = MaskType.MATERIAL:
	set(val):
		mask_type = val
		emit_changed()
		notify_property_list_changed()
		structure_changed.emit()

@export var mask_texture: Texture2D:
	set(val):
		mask_texture = val
		mask_updated.emit()
		emit_changed()

enum TextureChannel { RED, GREEN, BLUE, ALPHA }

@export var mask_texture_channel: TextureChannel = TextureChannel.RED:
	set(val):
		mask_texture_channel = val
		mask_updated.emit()
		emit_changed()

@export var mask_uv_scale: Vector2 = Vector2.ONE:
	set(val):
		mask_uv_scale = val
		mask_updated.emit()
		emit_changed()

@export var mask_uv_offset: Vector2 = Vector2.ZERO:
	set(val):
		mask_uv_offset = val
		mask_updated.emit()
		emit_changed()

## Sample the mask texture with the mesh's second UV channel.
@export var mask_uv2: bool = false:
	set(val):
		mask_uv2 = val
		mask_updated.emit()
		emit_changed()

## Stored by reference, like surface_material.
@export var mask_material: ShaderMaterial:
	set(val):
		mask_material = val
		material_replaced.emit()
		emit_changed()


func _validate_property(property: Dictionary) -> void:
	if property.name in ["mask_type", "mask_material", "mask_texture", "mask_texture_channel", "mask_uv_scale", "mask_uv_offset", "mask_uv2"]:
		if !mask_active:
			property.usage &= ~PROPERTY_USAGE_EDITOR

	if property.name in ["mask_texture", "mask_texture_channel", "mask_uv_scale", "mask_uv_offset", "mask_uv2"]:
		if mask_type != MaskType.TEXTURE:
			property.usage &= ~PROPERTY_USAGE_EDITOR

	if property.name == "mask_material":
		if mask_type != MaskType.MATERIAL:
			property.usage &= ~PROPERTY_USAGE_EDITOR
	
	if property.name == "surface_material":
		property.hint = PROPERTY_HINT_RESOURCE_TYPE
		property.hint_string = "SurfaceMaterial"
	
	if property.name == "mask_material":
		property.hint = PROPERTY_HINT_RESOURCE_TYPE
		property.hint_string = "MaskMaterial"