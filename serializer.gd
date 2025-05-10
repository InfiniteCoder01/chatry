class_name Serializer

static func serialize(value: Variant) -> Variant:
	if value is Array:
		var data := []
		for item: Variant in value:
			data.append(serialize(item))
		return data
	elif value is Dictionary:
		var data := {}
		for key: Variant in value.keys():
			data[serialize(key)] = serialize(value[key])
		return data
	elif value is Object:
		var data := {}
		for property: Dictionary in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				data[property.name] = serialize(value[property.name])
		return data
	return value

static func default_value(type: Variant.Type, script: Variant) -> Variant:
	if script != null: return script.new()
	match type:
		TYPE_NIL: return null
		TYPE_BOOL: return false
		TYPE_INT: return 0
		TYPE_FLOAT: return 0.0
		TYPE_STRING: return ""
		TYPE_VECTOR2: return Vector2()
		TYPE_VECTOR2I: return Vector2i()
		TYPE_RECT2: return Rect2()
		TYPE_RECT2I: return Rect2i()
		TYPE_VECTOR3: return Vector3()
		TYPE_VECTOR3I: return Vector3i()
		TYPE_TRANSFORM2D: Transform2D()
		TYPE_VECTOR4: return Vector4()
		TYPE_VECTOR4I: return Vector4i()
		TYPE_PLANE: return Plane()
		TYPE_QUATERNION: return Quaternion()
		TYPE_AABB: return AABB()
		TYPE_BASIS: return Basis()
		TYPE_TRANSFORM3D: return Transform3D()
		TYPE_PROJECTION: return Projection()
		TYPE_COLOR: return Color()
		TYPE_STRING_NAME: return StringName()
		TYPE_NODE_PATH: return NodePath()
		TYPE_RID: return RID()
		TYPE_OBJECT: return Object.new()
		TYPE_CALLABLE: return Callable()
		TYPE_SIGNAL: return Signal()
		TYPE_DICTIONARY: return Dictionary()
		TYPE_ARRAY: return Array()
		TYPE_PACKED_BYTE_ARRAY: return PackedByteArray()
		TYPE_PACKED_INT32_ARRAY: return PackedInt32Array()
		TYPE_PACKED_INT64_ARRAY: return PackedInt64Array()
		TYPE_PACKED_FLOAT32_ARRAY: return PackedFloat32Array()
		TYPE_PACKED_FLOAT64_ARRAY: return PackedFloat64Array()
		TYPE_PACKED_STRING_ARRAY: return PackedStringArray()
		TYPE_PACKED_VECTOR2_ARRAY: return PackedVector2Array()
		TYPE_PACKED_VECTOR3_ARRAY: return PackedVector3Array()
		TYPE_PACKED_COLOR_ARRAY: return PackedColorArray()
		TYPE_PACKED_VECTOR4_ARRAY: return PackedVector4Array()
	return null

static func deserialize(value: Variant, data: Variant) -> Variant:
	if value is Array:
		for item_data: Variant in data:
			var item_instance: Variant = default_value(value.get_typed_builtin(), value.get_typed_script())
			value.append(deserialize(item_instance, item_data))
		return value
	elif value is Dictionary:
		for key_data: Variant in data.keys():
			var key_instance: Variant = default_value(value.get_typed_key_builtin(), value.get_typed_key_script())
			var value_instance: Variant = default_value(value.get_typed_value_builtin(), value.get_typed_value_script())
			var key: Variant = deserialize(key_instance, key_data)
			value[key] = deserialize(value_instance, data[key])
		return value
	elif value is Object:
		for key: String in data.keys():
			if key in value:
				value[key] = deserialize(value[key], data[key])
		return value

	if data == null: return value
	return data
