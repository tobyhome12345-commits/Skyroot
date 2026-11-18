class_name SkyMap
## Reads data/sky_map.json: each island's fixed place in the shared sky
## (bearing from north, degrees below the horizon, distance). Distant views
## and glide directions both come from here, so an island always appears in
## the same place, from every other island.

const PATH := "res://data/sky_map.json"

static var _data := {}


static func _islands() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"islands": {}}
	return _data["islands"]


## Islands that have a place in the sky (null slots are left out).
static func ids() -> Array:
	var out := []
	for id: String in _islands():
		if _islands()[id] != null:
			out.append(id)
	return out


static func has_place(id: String) -> bool:
	return _islands().get(id) != null


static func slot(id: String) -> Dictionary:
	var s = _islands().get(id)
	return s if s is Dictionary else {}


## Unit direction to the island's place in the sky (north = -z, east = +x).
static func direction(id: String) -> Vector3:
	var s := slot(id)
	if s.is_empty():
		return Vector3.ZERO
	var b := deg_to_rad(float(s["bearing"]))
	var d := deg_to_rad(float(s["below"]))
	return Vector3(sin(b) * cos(d), -sin(d), -cos(b) * cos(d))


## Where the island's distant view sits, relative to the island you are on.
static func offset(id: String) -> Vector3:
	var s := slot(id)
	return direction(id) * float(s.get("distance", 0.0))


## Level direction towards the island's place (for glides), or zero.
static func heading(id: String) -> Vector3:
	var d := direction(id)
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.ZERO
