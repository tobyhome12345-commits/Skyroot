extends Node3D
## A house interior: a 6 x 6 tile room on the same grid as the island.
## Cutaway view: back and side walls only, no front wall or ceiling.
## Furniture comes from the Kenney packs (see Assets/CREDITS.md). Every object
## snaps to whole tiles and owns its tiles (no sharing). Furniture that belongs
## together (a kitchen counter run, a sofa with its coffee table, a bed and its
## nightstand) is one object, so the pieces can stand close together.
## The exit door is on the front edge; the player enters on the tile behind it.

const ROOM_SIZE := Vector2i(6, 6)
const EXIT_CELL := Vector2i(2, 5)
const ENTRANCE_CELL := Vector2i(2, 4)
## Interior walls are Town modules stretched up to this height (m).
const WALL_HEIGHT := 2.8
## Furniture is drawn 1.35x its pack scale indoors so pieces fill their tiles
## and the room feels cozy, without getting cramped.
const INTERIOR_SCALE := 1.35
## Furniture against a wall keeps this far (m) from the tile edge, which
## clears the wall and its window shutters.
const WALL_CLEARANCE := 0.4
## Gap (m) between pieces standing side by side inside one object.
const PART_GAP := 0.08
## Rugs are scaled to fill this share of their footprint.
const RUG_FILL := 0.9

@export_enum("elder", "bedroom", "workshop", "library", "kite_workshop", "lookout", "family_home", "captain_cabin", "rope_loft", "chime_workshop", "bakehouse") var room := "elder"
@export var player_path: NodePath

## Tiles taken by objects (cell -> object name).
var occupied := {}
## Leafwind rooms: log walls, round windows, a trunk in the corner and
## Leafwind's plank floor (see scripts/treehouse.gd).
var _treehouse := false
var map_size := ROOM_SIZE


func _ready() -> void:
	var data: Dictionary = _rooms()[room]
	_treehouse = data["wall"] == "treehouse"
	_build_environment()
	_build_floor()
	_build_walls(data)
	_build_exit()
	_build_objects(data)
	_place_villager(data)
	_spawn_player()


# ---------------------------------------------------------------- rooms

## The four rooms. Object fields:
##   id       one model ("F:" Furniture Kit, "S:" Survival, "T:" Town)
##   row      several models side by side, touching: [[id, rot, top], ...]
##            laid along x (axis "x", default) or along z (axis "z")
##   cell     top-left tile; size: footprint in tiles (default 1 x 1)
##   rot      yaw in degrees (Furniture Kit models face +z, towards the camera)
##   against wall side(s) the object is pushed back against: "north", "west", "east"
##   top      small items standing on the model's top: [[id, rot], ...]
##   parts    pieces placed next to the main piece: [[id, rot, side, top], ...]
##            side = "north" / "south" / "east" / "west"; "next-west" etc.
##            places it next to the previous part instead (a chain)
##   flat     rugs: walkable, no collider, scaled to fill the footprint
##   light    adds a warm lamp light above the object
##   deco     a Leafwind prop (scripts/leafwind_props.gd), e.g. "kite_rack",
##            "wind_chime", "telescope", with its own "rot" / "color" / "flower"
func _rooms() -> Dictionary:
	var rooms := _pebblenook_rooms()
	rooms.merge(_leafwind_rooms())
	return rooms


## Leafwind's rooms: three houses and four huts.
func _leafwind_rooms() -> Dictionary:
	return {
		# 5. The kite-maker's workshop: kites on racks, cloth, tools, rope.
		"kite_workshop": {
			"villager": {"id": "tamsin", "cell": Vector2i(4, 3), "facing": 0.0},
			"wall": "treehouse", "windows": [Vector2i(1, 0), Vector2i(4, 0), Vector2i(5, 3)],
			"objects": [
				{"row": [["S:workbench", 0.0, [["S:tool-hammer", 30.0]]], ["F:desk", 0.0, [["F:lampSquareTable", 0.0]]]],
					"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "against": ["north", "west"], "light": true},
				{"type": "deco", "deco": "kite_rack", "cell": Vector2i(2, 0), "against": ["north"]},
				{"type": "deco", "deco": "kite_rack", "cell": Vector2i(3, 0), "against": ["north"]},
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 0.0]]], ["F:cardboardBoxOpen", 0.0, []]],
					"cell": Vector2i(4, 0), "size": Vector2i(2, 1), "against": ["north", "east"]},
				{"id": "S:chest", "cell": Vector2i(0, 1), "rot": 90.0, "against": ["west"]},
				{"type": "deco", "deco": "kite_pole", "color": "blue", "rot": 180.0, "cell": Vector2i(5, 1), "against": ["east"]},
				{"type": "deco", "deco": "rope_coils", "cell": Vector2i(0, 2), "against": ["west"]},
				{"id": "F:table", "cell": Vector2i(2, 2), "size": Vector2i(2, 1),
					"top": [["F:books", 20.0], ["S:box-open", 0.0]],
					"parts": [["F:chair", 90.0, "west", []]]},
				{"id": "F:lampSquareFloor", "cell": Vector2i(5, 2), "against": ["east"], "light": true},
				{"id": "S:barrel", "cell": Vector2i(0, 3), "against": ["west"]},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 3), "against": ["east"]},
				{"type": "deco", "deco": "planter", "flower": "flower_yellowA", "cell": Vector2i(0, 4), "against": ["west"]},
				{"row": [["S:box-large", 0.0, []], ["S:box", 20.0, []]],
					"axis": "z", "cell": Vector2i(5, 4), "size": Vector2i(1, 2), "against": ["east"]},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"type": "deco", "deco": "wind_chime", "rot": 180.0, "cell": Vector2i(4, 5)},
			],
		},
		# 6. The weather-watcher's lookout: a telescope at the window, books
		# and a radio on the desk, a comfy chair for long waits.
		"lookout": {
			"wall": "treehouse", "windows": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(0, 3), Vector2i(5, 2)],
			"objects": [
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 0.0]]], ["F:bookcaseClosed", 0.0, []]],
					"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "against": ["north", "west"]},
				{"id": "F:desk", "cell": Vector2i(2, 0), "size": Vector2i(2, 2), "against": ["north"],
					"top": [["F:lampSquareTable", 0.0], ["F:radio", 0.0]], "light": true,
					"parts": [["F:chairDesk", 180.0, "south", []]]},
				{"type": "deco", "deco": "telescope", "rot": 0.0, "cell": Vector2i(4, 0), "against": ["north"]},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 0), "against": ["north", "east"]},
				{"id": "F:loungeChairRelax", "cell": Vector2i(0, 3), "size": Vector2i(2, 1), "rot": 90.0, "against": ["west"]},
				{"id": "F:sideTable", "cell": Vector2i(0, 2), "rot": 90.0, "against": ["west"],
					"top": [["F:lampRoundTable", 0.0]], "light": true},
				{"row": [["F:bookcaseOpenLow", -90.0, [["F:plantSmall2", 0.0]]], ["F:bookcaseOpenLow", -90.0, [["F:books", 0.0]]]],
					"axis": "z", "cell": Vector2i(5, 1), "size": Vector2i(1, 2), "against": ["east"]},
				{"id": "F:rugRound", "cell": Vector2i(2, 2), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:lampRoundFloor", "cell": Vector2i(5, 3), "against": ["east"], "light": true},
				{"type": "deco", "deco": "wind_chime", "rot": 0.0, "cell": Vector2i(5, 4)},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"id": "S:chest", "cell": Vector2i(5, 5), "rot": -90.0, "against": ["east"]},
				{"id": "F:cardboardBoxClosed", "cell": Vector2i(4, 5)},
			],
		},
		# 7. A family home: a little kitchen, a dining table with a pie, a
		# bunk bed for the children, a sofa and a toy kite.
		"family_home": {
			"wall": "treehouse", "windows": [Vector2i(1, 0), Vector2i(0, 3), Vector2i(5, 2)],
			"objects": [
				{"row": [["F:kitchenFridgeSmall", 0.0, []], ["F:kitchenCabinet", 0.0, [["K:loaf", 0.0]]], ["F:kitchenStove", 0.0, []]],
					"cell": Vector2i(0, 0), "size": Vector2i(3, 1), "against": ["north", "west"]},
				{"id": "F:bookcaseOpenLow", "cell": Vector2i(3, 0), "against": ["north"], "top": [["F:bear", 0.0]]},
				{"id": "F:bedBunk", "cell": Vector2i(4, 0), "size": Vector2i(2, 2), "against": ["north", "east"]},
				{"id": "F:table", "cell": Vector2i(1, 2), "size": Vector2i(2, 1),
					"top": [["K:pie", 0.0], ["K:croissant", 40.0]],
					"parts": [["F:chair", 90.0, "west", []], ["F:chair", -90.0, "east", []]]},
				{"id": "F:sideTable", "cell": Vector2i(0, 3), "rot": 90.0, "against": ["west"],
					"top": [["F:lampRoundTable", 0.0]], "light": true},
				{"id": "F:rugRounded", "cell": Vector2i(2, 3), "size": Vector2i(2, 1), "flat": true},
				{"id": "F:loungeSofa", "cell": Vector2i(4, 3), "size": Vector2i(2, 2), "rot": -90.0, "against": ["east"]},
				{"type": "deco", "deco": "kite_pole", "color": "yellow", "rot": 90.0, "cell": Vector2i(5, 2), "against": ["east"]},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"id": "F:cardboardBoxOpen", "cell": Vector2i(3, 5)},
				{"id": "F:lampRoundFloor", "cell": Vector2i(4, 5), "light": true},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 5), "against": ["east"]},
				{"type": "deco", "deco": "planter", "flower": "flower_redA", "cell": Vector2i(0, 4), "against": ["west"]},
			],
		},
		# 8. Old Captain Brisk's cabin (north hut): sea chest, bunk, a map
		# table, his telescope, a cart wheel for a ship's wheel.
		"captain_cabin": {
			"wall": "treehouse", "windows": [Vector2i(1, 0), Vector2i(4, 0), Vector2i(5, 3)],
			"objects": [
				{"row": [["S:chest", 0.0, []], ["S:barrel", 0.0, []]],
					"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "against": ["north", "west"]},
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 0.0]]], ["F:bookcaseOpenLow", 0.0, [["S:bottle", 0.0]]]],
					"cell": Vector2i(2, 0), "size": Vector2i(2, 1), "against": ["north"]},
				{"type": "deco", "deco": "telescope", "cell": Vector2i(4, 0), "against": ["north"]},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 0), "against": ["north", "east"]},
				{"id": "F:bedSingle", "cell": Vector2i(0, 1), "size": Vector2i(2, 2), "against": ["west"]},
				{"type": "deco", "deco": "rope_coils", "cell": Vector2i(5, 1), "against": ["east"]},
				{"id": "F:table", "cell": Vector2i(3, 2), "size": Vector2i(2, 1),
					"top": [["F:books", 10.0], ["S:bottle-large", 0.0]],
					"parts": [["F:chair", 90.0, "west", []]]},
				{"id": "T:wheel", "cell": Vector2i(5, 2), "rot": 90.0, "against": ["east"]},
				{"id": "F:sideTable", "cell": Vector2i(0, 3), "rot": 90.0, "against": ["west"],
					"top": [["F:lampRoundTable", 0.0]], "light": true},
				{"id": "F:rugRectangle", "cell": Vector2i(3, 3), "size": Vector2i(2, 1), "flat": true},
				{"id": "S:barrel-open", "cell": Vector2i(0, 4), "against": ["west"]},
				{"id": "F:lampRoundFloor", "cell": Vector2i(5, 4), "against": ["east"], "light": true},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"id": "S:box", "cell": Vector2i(5, 5), "rot": 20.0, "against": ["east"]},
			],
		},
		# 9. Maude the rope-weaver's loft (north-east hut): coils of rope
		# everywhere, her workbench, a bed and a reading chair.
		"rope_loft": {
			"wall": "treehouse", "windows": [Vector2i(2, 0), Vector2i(0, 2), Vector2i(5, 3)],
			"objects": [
				{"row": [["S:workbench", 0.0, [["S:tool-hammer", 0.0]]], ["F:bookcaseOpenLow", 0.0, [["F:books", 0.0]]]],
					"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "against": ["north", "west"], "light": true},
				{"type": "deco", "deco": "rope_coils", "cell": Vector2i(2, 0), "against": ["north"]},
				{"type": "deco", "deco": "rope_coils", "rot": 60.0, "cell": Vector2i(3, 0), "against": ["north"]},
				{"id": "F:bedSingle", "cell": Vector2i(4, 0), "size": Vector2i(2, 2), "against": ["north", "east"]},
				{"id": "S:barrel", "cell": Vector2i(0, 1), "against": ["west"]},
				{"type": "deco", "deco": "rope_coils", "rot": -40.0, "cell": Vector2i(0, 2), "against": ["west"]},
				{"id": "F:rugRound", "cell": Vector2i(2, 2), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:lampRoundFloor", "cell": Vector2i(5, 2), "against": ["east"], "light": true},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 3), "against": ["east"]},
				{"id": "F:loungeChair", "cell": Vector2i(0, 3), "size": Vector2i(2, 1), "rot": 90.0, "against": ["west"],
					"parts": [["F:sideTable", 90.0, "east", [["F:plantSmall1", 0.0]]]]},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"type": "deco", "deco": "planter", "flower": "flower_purpleA", "cell": Vector2i(4, 5)},
				{"id": "S:chest", "cell": Vector2i(5, 5), "rot": -90.0, "against": ["east"]},
			],
		},
		# 10. Bellamy the chime-maker's workshop (chime corner hut): chimes
		# waiting to be tuned, a grinder and anvil, a cluttered table.
		"chime_workshop": {
			"wall": "treehouse", "windows": [Vector2i(1, 0), Vector2i(4, 0), Vector2i(0, 3), Vector2i(5, 3)],
			"objects": [
				{"row": [["S:workbench", 0.0, [["S:tool-hammer", 30.0]]], ["S:workbench-grind", 0.0, []]],
					"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "against": ["north", "west"], "light": true},
				{"type": "deco", "deco": "wind_chime", "cell": Vector2i(2, 0), "against": ["north"]},
				{"type": "deco", "deco": "wind_chime", "rot": 90.0, "cell": Vector2i(3, 0), "against": ["north"]},
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 0.0]]], ["S:workbench-anvil", 0.0, []]],
					"cell": Vector2i(4, 0), "size": Vector2i(2, 1), "against": ["north", "east"]},
				{"type": "deco", "deco": "wind_chime", "rot": 180.0, "cell": Vector2i(0, 2), "against": ["west"]},
				{"type": "deco", "deco": "wind_chime", "rot": 200.0, "cell": Vector2i(5, 2), "against": ["east"]},
				{"id": "F:table", "cell": Vector2i(2, 2), "size": Vector2i(2, 1),
					"top": [["S:bottle", 0.0], ["F:books", 30.0]],
					"parts": [["F:chair", 90.0, "west", []]]},
				{"id": "F:sideTable", "cell": Vector2i(0, 3), "rot": 90.0, "against": ["west"],
					"top": [["F:lampRoundTable", 0.0]], "light": true},
				{"id": "F:lampSquareFloor", "cell": Vector2i(5, 3), "against": ["east"], "light": true},
				{"id": "S:box", "cell": Vector2i(0, 4), "against": ["west"]},
				{"id": "S:barrel", "cell": Vector2i(5, 4), "against": ["east"]},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"id": "F:cardboardBoxOpen", "cell": Vector2i(4, 5)},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 5), "against": ["east"]},
			],
		},
		# 11. Barnaby the baker's bakehouse (south-west hut): his oven,
		# counters of bread and pie, flour barrels, a table with a cake.
		"bakehouse": {
			"wall": "treehouse", "windows": [Vector2i(1, 0), Vector2i(0, 3), Vector2i(5, 3)],
			"objects": [
				{"row": [["F:kitchenCabinet", 0.0, [["K:loaf", 0.0]]], ["F:kitchenStove", 0.0, []], ["F:kitchenCabinet", 0.0, [["K:pie", 0.0]]]],
					"cell": Vector2i(0, 0), "size": Vector2i(3, 1), "against": ["north", "west"]},
				{"type": "deco", "deco": "oven", "cell": Vector2i(3, 0), "against": ["north"]},
				{"row": [["F:bookcaseOpen", 0.0, [["K:loaf-round", 0.0]]], ["F:kitchenFridgeSmall", 0.0, []]],
					"cell": Vector2i(4, 0), "size": Vector2i(2, 1), "against": ["north", "east"]},
				{"row": [["S:barrel", 0.0, []], ["S:barrel-open", 0.0, []]],
					"axis": "z", "cell": Vector2i(5, 1), "size": Vector2i(1, 2), "against": ["east"]},
				{"id": "F:table", "cell": Vector2i(1, 2), "size": Vector2i(2, 1),
					"top": [["K:cake", 0.0], ["K:cutting-board", 30.0]],
					"parts": [["F:chair", 90.0, "west", []], ["F:chair", -90.0, "east", []]]},
				{"id": "F:rugRectangle", "cell": Vector2i(3, 2), "size": Vector2i(2, 1), "flat": true},
				{"id": "F:sideTable", "cell": Vector2i(0, 3), "rot": 90.0, "against": ["west"],
					"top": [["F:lampRoundTable", 0.0]], "light": true},
				{"id": "F:lampRoundFloor", "cell": Vector2i(5, 3), "against": ["east"], "light": true},
				{"id": "S:barrel", "cell": Vector2i(0, 4), "against": ["west"]},
				{"id": "S:box", "cell": Vector2i(5, 4), "rot": 15.0, "against": ["east"]},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"type": "deco", "deco": "planter", "flower": "flower_yellowB", "cell": Vector2i(4, 5)},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 5), "against": ["east"]},
			],
		},
	}


## Pebblenook's four rooms.
func _pebblenook_rooms() -> Dictionary:
	return {
		# 1. The elder's home: cozy living room and kitchen.
		"elder": {
			"villager": {"id": "elder", "cell": Vector2i(4, 4), "facing": 0.0},
			"wall": "wall", "windows": [Vector2i(3, 0), Vector2i(0, 4), Vector2i(5, 1)],
			"objects": [
				{"row": [["F:kitchenFridge", 0.0, []], ["F:kitchenCabinet", 0.0, [["F:kitchenCoffeeMachine", 0.0]]],
						["F:kitchenStove", 0.0, []], ["F:kitchenSink", 0.0, []]],
					"cell": Vector2i(0, 0), "size": Vector2i(3, 1), "against": ["north", "west"]},
				{"id": "F:sideTableDrawers", "cell": Vector2i(3, 0), "against": ["north"],
					"top": [["F:radio", 0.0]]},
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 0.0]]], ["F:pottedPlant", 0.0, []]],
					"cell": Vector2i(4, 0), "size": Vector2i(2, 1), "against": ["north", "east"]},
				{"id": "F:table", "cell": Vector2i(0, 1), "size": Vector2i(2, 1),
					"top": [["F:plantSmall1", 0.0]],
					"parts": [["F:chair", 90.0, "west", []], ["F:chair", -90.0, "east", []]]},
				{"id": "F:loungeSofa", "cell": Vector2i(3, 2), "size": Vector2i(3, 2), "rot": -90.0, "against": ["east"],
					"parts": [["F:tableCoffee", 90.0, "west", [["F:books", 30.0]]], ["F:loungeChair", 90.0, "next-west", []]]},
				{"id": "F:rugRectangle", "cell": Vector2i(1, 2), "size": Vector2i(2, 1), "flat": true},
				{"id": "F:sideTable", "cell": Vector2i(0, 3), "rot": 90.0, "against": ["west"],
					"top": [["F:lampRoundTable", 0.0]], "light": true},
				{"id": "F:coatRackStanding", "cell": Vector2i(0, 5)},
				{"id": "F:lampRoundFloor", "cell": Vector2i(5, 4), "against": ["east"], "light": true},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 5), "against": ["east"]},
			],
		},
		# 2. A young villager's bedroom.
		"bedroom": {
			"villager": {"id": "pip", "cell": Vector2i(4, 2), "facing": -30.0},
			"wall": "wall-wood", "windows": [Vector2i(2, 0), Vector2i(5, 3)],
			"objects": [
				{"id": "F:bedSingle", "cell": Vector2i(0, 0), "size": Vector2i(2, 2), "against": ["north", "west"],
					"parts": [["F:cabinetBed", 0.0, "east", [["F:lampSquareTable", 0.0]]]], "light": true},
				{"id": "F:desk", "cell": Vector2i(2, 0), "size": Vector2i(1, 2), "against": ["north"],
					"top": [["F:laptop", 0.0], ["F:books", -15.0]],
					"parts": [["F:chairDesk", 180.0, "south", []]]},
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 0.0]]], ["F:bookcaseClosedDoors", 0.0, []],
						["F:bookcaseClosedDoors", 0.0, []]],
					"cell": Vector2i(3, 0), "size": Vector2i(3, 1), "against": ["north", "east"]},
				{"id": "F:bear", "cell": Vector2i(0, 2), "rot": 90.0, "against": ["west"]},
				{"id": "F:rugRound", "cell": Vector2i(2, 2), "size": Vector2i(2, 2), "flat": true},
				{"row": [["F:bookcaseOpenLow", -90.0, [["F:radio", -90.0]]], ["F:pottedPlant", 0.0, []]],
					"axis": "z", "cell": Vector2i(5, 1), "size": Vector2i(1, 2), "against": ["east"]},
				{"id": "F:sideTable", "cell": Vector2i(0, 3), "rot": 90.0, "against": ["west"],
					"top": [["F:plantSmall1", 0.0]]},
				{"id": "F:lampRoundFloor", "cell": Vector2i(5, 4), "against": ["east"], "light": true},
				{"id": "F:cardboardBoxClosed", "cell": Vector2i(0, 5), "against": ["west"]},
			],
		},
		# 3. The tinkerer's workshop.
		"workshop": {
			"villager": {"id": "wren", "cell": Vector2i(1, 1), "facing": 20.0},
			"wall": "wall-wood", "windows": [Vector2i(0, 2), Vector2i(5, 3)],
			"objects": [
				{"row": [["F:lampSquareFloor", 0.0, []], ["S:workbench", 0.0, [["S:tool-hammer", 30.0]]],
						["S:workbench-anvil", 0.0, []]],
					"cell": Vector2i(0, 0), "size": Vector2i(3, 1), "against": ["north", "west"], "light": true},
				{"row": [["S:workbench-grind", 0.0, []], ["S:workbench", 0.0, [["S:tool-shovel", 0.0]]],
						["F:bookcaseOpen", 0.0, [["S:box", 10.0]]]],
					"cell": Vector2i(3, 0), "size": Vector2i(3, 1), "against": ["north", "east"]},
				{"row": [["S:chest", 90.0, []], ["F:bookcaseOpenLow", 90.0, [["S:bottle", 0.0]]]],
					"axis": "z", "cell": Vector2i(0, 1), "size": Vector2i(1, 2), "against": ["west"]},
				{"id": "F:table", "cell": Vector2i(2, 2), "size": Vector2i(2, 1),
					"top": [["S:tool-axe", 0.0], ["S:tool-pickaxe", 0.0]]},
				{"row": [["S:barrel", 0.0, []], ["S:barrel-open", 0.0, []]],
					"axis": "z", "cell": Vector2i(0, 4), "size": Vector2i(1, 2), "against": ["west"]},
				{"row": [["S:box-large", 0.0, []], ["S:box", 20.0, []]],
					"axis": "z", "cell": Vector2i(5, 4), "size": Vector2i(1, 2), "against": ["east"]},
				{"id": "F:lampSquareFloor", "cell": Vector2i(5, 2), "against": ["east"], "light": true},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 1), "against": ["east"]},
			],
		},
		# 4. A study / library with a fireplace.
		"library": {
			"villager": {"id": "quill", "cell": Vector2i(1, 1), "facing": 20.0},
			"wall": "wall", "windows": [Vector2i(0, 4), Vector2i(5, 4)],
			"objects": [
				{"row": [["F:bookcaseClosed", 0.0, []], ["F:bookcaseOpen", 0.0, [["F:books", 0.0]]]],
					"cell": Vector2i(0, 0), "size": Vector2i(2, 1), "against": ["north", "west"]},
				{"type": "fireplace", "cell": Vector2i(2, 0), "size": Vector2i(2, 2), "against": ["north"]},
				{"row": [["F:bookcaseOpen", 0.0, [["F:books", 20.0]]], ["F:bookcaseClosed", 0.0, []]],
					"cell": Vector2i(4, 0), "size": Vector2i(2, 1), "against": ["north", "east"]},
				{"row": [["F:bookcaseOpen", 90.0, [["F:books", 90.0]]], ["F:bookcaseOpenLow", 90.0, [["F:plantSmall3", 0.0]]]],
					"axis": "z", "cell": Vector2i(0, 1), "size": Vector2i(1, 2), "against": ["west"]},
				{"id": "F:loungeChair", "cell": Vector2i(0, 3), "size": Vector2i(2, 1), "rot": 90.0, "against": ["west"],
					"parts": [["F:sideTable", 90.0, "east", [["F:books", 45.0]]]]},
				{"id": "F:lampRoundFloor", "cell": Vector2i(0, 4), "against": ["west"], "light": true},
				{"id": "F:rugRectangle", "cell": Vector2i(2, 2), "size": Vector2i(2, 2), "flat": true},
				{"id": "F:desk", "cell": Vector2i(4, 1), "size": Vector2i(2, 1), "rot": -90.0, "against": ["east"],
					"top": [["F:lampSquareTable", 0.0], ["F:books", 90.0]], "light": true,
					"parts": [["F:chairDesk", 90.0, "west", []]]},
				{"id": "F:bookcaseOpen", "cell": Vector2i(5, 3), "rot": -90.0, "against": ["east"],
					"top": [["F:books", 0.0]]},
				{"id": "F:pottedPlant", "cell": Vector2i(5, 5), "against": ["east"]},
			],
		},
	}


# ---------------------------------------------------------------- grid

func cell_center(cell: Vector2i) -> Vector3:
	return Grid.cell_center(cell, ROOM_SIZE)


func in_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < ROOM_SIZE.x and cell.y < ROOM_SIZE.y


func room_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in ROOM_SIZE.y:
		for x in ROOM_SIZE.x:
			cells.append(Vector2i(x, z))
	return cells


# ---------------------------------------------------------------- room shell

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.065, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.82, 0.62)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Warm main light above the room, plus a soft fill for shadows.
	var main := OmniLight3D.new()
	main.name = "RoomLight"
	main.light_color = Color(1.0, 0.8, 0.58)
	main.light_energy = 2.2
	main.omni_range = 16.0
	main.omni_attenuation = 0.8
	main.shadow_enabled = true
	main.position = Vector3(0.0, 6.0, 0.0)
	add_child(main)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(1.0, 0.86, 0.7)
	fill.light_energy = 0.35
	fill.shadow_enabled = true
	fill.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	add_child(fill)


## Board floor, one tile at a time, top flush at y = 0: Fantasy Town Kit
## plank boards laid over a Furniture Kit floor tile (darkened), so the gaps
## between the boards read as seams.
func _build_floor() -> void:
	var floor_root := Node3D.new()
	floor_root.name = "Floor"
	add_child(floor_root)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.36, 0.22, 0.14)
	dark.roughness = 0.9
	for cell in room_cells():
		var centre := cell_center(cell)
		var boards := ModelLib.piece(ModelLib.TOWN + "planks.glb", ModelLib.TOWN_SCALE, centre, 0.0)
		var board_h := ModelUtil.local_aabb(boards).size.y * ModelLib.TOWN_SCALE
		boards.position.y = -board_h
		boards.name = "boards_%d_%d" % [cell.x, cell.y]
		floor_root.add_child(boards)
		var base: Array = ModelLib.placed("F:floorFull")
		var base_node: Node3D = base[0]
		base_node.position = centre + Vector3(0.0, -board_h - (base[1] as Vector3).y, 0.0)
		for mi in base_node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = dark
		if _treehouse:
			for mi in boards.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = _treehouse_floor()
		base_node.name = "floor_%d_%d" % [cell.x, cell.y]
		base_node.set_meta("cell", cell)
		floor_root.add_child(base_node)
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(ROOM_SIZE.x * Grid.TILE, 0.5, ROOM_SIZE.y * Grid.TILE)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, -0.25, 0.0)
	body.add_child(cs)


## Back (north) and side walls from Fantasy Town Kit modules, one per tile
## edge; the front edge is open (cutaway) but blocked by an invisible wall.
func _build_walls(data: Dictionary) -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var wall: String = data["wall"]
	var windows: Array = data.get("windows", [])
	var sides := {"north": [Vector2i(0, -1), 90.0], "west": [Vector2i(-1, 0), 180.0], "east": [Vector2i(1, 0), 0.0]}
	if _treehouse:
		_build_log_walls(walls, sides, windows)
	for cell in room_cells() if not _treehouse else []:
		for side: String in sides:
			var d: Vector2i = sides[side][0]
			if in_room(cell + d):
				continue
			var kind := wall + ("-window-shutters" if cell in windows else "")
			var piece := ModelLib.piece(ModelLib.TOWN + kind + ".glb", ModelLib.TOWN_SCALE, cell_center(cell), sides[side][1])
			piece.scale.y = WALL_HEIGHT  # Town modules are 1 unit tall
			piece.name = "wall_%s_%d_%d" % [side, cell.x, cell.y]
			walls.add_child(piece)
	# Collision: a slab along each wall (covers the window shutters), and an
	# invisible one along the open front edge.
	var body := StaticBody3D.new()
	body.name = "WallBody"
	add_child(body)
	var w := ROOM_SIZE.x * Grid.TILE
	var d := ROOM_SIZE.y * Grid.TILE
	var t := WALL_CLEARANCE
	var h := WALL_HEIGHT
	_wall_box(body, Vector3(w, h, t), Vector3(0.0, h / 2.0, -d / 2.0 + t / 2.0))
	_wall_box(body, Vector3(t, h, d), Vector3(-w / 2.0 + t / 2.0, h / 2.0, 0.0))
	_wall_box(body, Vector3(t, h, d), Vector3(w / 2.0 - t / 2.0, h / 2.0, 0.0))
	_wall_box(body, Vector3(w, h, t), Vector3(0.0, h / 2.0, d / 2.0 + t / 2.0))


## Treehouse walls (Leafwind): one piece per tile edge, each a stack of
## round logs kept inside the outer band of the tile (furniture keeps
## WALL_CLEARANCE away), with a round sky-blue window on window tiles.
## A tree trunk grows up through the back-left corner, with a leafy
## branch along the top of the back wall.
const LOG_INSET := 0.14
const LOG_RADIUS := 0.12


func _build_log_walls(walls: Node3D, sides: Dictionary, windows: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room)
	var h := Grid.TILE / 2.0
	for cell in room_cells():
		for side: String in sides:
			var d: Vector2i = sides[side][0]
			if in_room(cell + d):
				continue
			var piece := Node3D.new()
			piece.name = "wall_%s_%d_%d" % [side, cell.x, cell.y]
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var c := cell_center(cell)
			var e := Vector3(d.x, 0.0, d.y)
			var along := Vector3(absf(e.z), 0.0, absf(e.x))
			var line := c + e * (h - LOG_INSET)
			var rows := int(WALL_HEIGHT / (2.0 * LOG_RADIUS))
			for i in rows:
				var y := LOG_RADIUS + 2.0 * LOG_RADIUS * i
				Treehouse.add_log(st, line - along * h + Vector3(0.0, y, 0.0), line + along * h + Vector3(0.0, y, 0.0),
						LOG_RADIUS, Treehouse.WOOD.darkened(rng.randf_range(-0.05, 0.1)), 8)
			piece.add_child(Treehouse.mesh(st, Treehouse.bark_material(), "Logs"))
			if cell in windows:
				var face := c + e * (h - LOG_INSET - LOG_RADIUS - 0.005)
				piece.add_child(Treehouse.round_window(face + Vector3(0.0, 1.5, 0.0), -e, 0.42, Treehouse.SKY))
			walls.add_child(piece)
	# The trunk in the back-left corner and its branch along the back wall.
	var corner := Vector3(-ROOM_SIZE.x * h, 0.0, -ROOM_SIZE.y * h)
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_r := 0.5
	# Half buried in the corner, clear of furniture standing against the walls.
	var trunk := corner + Vector3(1.0, 0.0, 1.0) * (WALL_CLEARANCE - 0.05 - trunk_r)
	Treehouse.add_branch(bark, trunk + Vector3(0.0, 0.02, 0.0), trunk + Vector3(0.05, WALL_HEIGHT + 0.6, 0.05), trunk_r, trunk_r * 0.85, Vector3(0.05, 0.0, 0.05), Treehouse.BARK, 6)
	var branch_z := corner.z + LOG_INSET
	var a := Vector3(trunk.x + 0.2, WALL_HEIGHT - 0.25, branch_z)
	var b := Vector3(corner.x + ROOM_SIZE.x * Grid.TILE * 0.62, WALL_HEIGHT + 0.05, branch_z)
	Treehouse.add_branch(bark, a, b, 0.16, 0.06, Vector3(0.0, 0.12, 0.0), Treehouse.BARK, 8)
	for k in 7:
		var t := 0.12 + 0.13 * k
		var p := a.lerp(b, t) + Vector3(0.0, 0.12 * sin(PI * t) - 0.08, 0.0)
		Treehouse.add_leaf_blob(leaves, p, Vector3(0.34, 0.22, 0.1), [Treehouse.LEAF, Treehouse.LEAF_DARK, Treehouse.LEAF_LIGHT][k % 3], rng)
	var tree := Node3D.new()
	tree.name = "wall_trunk"
	tree.add_child(Treehouse.mesh(bark, Treehouse.bark_material(), "Trunk"))
	tree.add_child(Treehouse.mesh(leaves, Treehouse.flat_material(), "Leaves"))
	walls.add_child(tree)


## Leafwind's plank floor, tinted warm wood (the boards' mesh has no vertex
## colours, so a copy of the floor material with a fixed tint is used).
func _treehouse_floor() -> Material:
	if not has_meta("floor_mat"):
		var m := (Treehouse.floor_material("deck").duplicate() as ShaderMaterial)
		m.set_shader_parameter("tint", Treehouse.DECK)
		m.set_shader_parameter("force_axis", 0)
		m.set_shader_parameter("edge_moss", false)
		m.set_shader_parameter("leaves", false)
		m.set_shader_parameter("dapple", false)
		set_meta("floor_mat", m)
	return get_meta("floor_mat")


func _wall_box(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


## Exit door frame on the front edge of the exit tile, a doormat, and the
## trigger that takes the player back outside.
func _build_exit() -> void:
	var exit_root := Node3D.new()
	exit_root.name = "Exit"
	add_child(exit_root)
	var centre := cell_center(EXIT_CELL)
	var door: Array = ModelLib.placed("F:doorwayOpen", 0.0, INTERIOR_SCALE)
	var door_node: Node3D = door[0]
	var door_size: Vector3 = door[1]
	door_node.name = "ExitDoor"
	door_node.position = centre + Vector3(0.0, 0.0, Grid.TILE / 2.0 - door_size.z / 2.0)
	exit_root.add_child(door_node)
	var mat: Array = ModelLib.placed("F:rugDoormat", 0.0, INTERIOR_SCALE)
	var mat_node: Node3D = mat[0]
	mat_node.name = "Doormat"
	mat_node.position = centre + Vector3(0.0, 0.0, Grid.TILE / 2.0 - door_size.z - (mat[1] as Vector3).z / 2.0 - PART_GAP)
	exit_root.add_child(mat_node)
	var trigger := Area3D.new()
	trigger.set_script(preload("res://scripts/door_trigger.gd"))
	trigger.name = "ExitTrigger"
	exit_root.add_child(trigger)
	trigger.setup(centre, Vector3(0.0, 2.6, Grid.TILE / 2.0), Game.exit_house)


# ---------------------------------------------------------------- objects

func _build_objects(data: Dictionary) -> void:
	var objects := Node3D.new()
	objects.name = "Objects"
	add_child(objects)
	var index := 0
	for o: Dictionary in data["objects"]:
		var cell: Vector2i = o["cell"]
		var size: Vector2i = o.get("size", Vector2i.ONE)
		var label := _label(o)
		var obj_name := "%s_%d" % [label, index]
		index += 1
		if not _claim(cell, size, obj_name):
			continue
		var node: Node3D
		if o.get("type", "") == "fireplace":
			node = _build_fireplace()
		elif o.get("type", "") == "deco":
			node = _build_deco(o)
		else:
			node = _build_object(o)
		node.name = obj_name
		node.position = Grid.footprint_center(cell, size, ROOM_SIZE)
		_fit_into_footprint(node, size, o.get("against", []))
		if not o.get("flat", false):
			_collider_from_model(node)
		else:
			node.set_meta("solid", false)
		if o.get("light", false):
			_add_lamp_light(node)
		node.set_meta("cell", cell)
		node.set_meta("size", size)
		objects.add_child(node)


func _label(o: Dictionary) -> String:
	if o.has("deco"):
		return o["deco"]
	if o.has("type"):
		return o["type"]
	if o.has("row"):
		return "row"
	return (o["id"] as String).get_slice(":", 1)


## One footprint can't hold two objects, and the entrance/exit stay clear.
func _claim(cell: Vector2i, size: Vector2i, obj_name: String) -> bool:
	for dz in size.y:
		for dx in size.x:
			var c := cell + Vector2i(dx, dz)
			if not in_room(c):
				push_error("%s at %s is outside the room (tile %s)" % [obj_name, cell, c])
				return false
			if c == ENTRANCE_CELL or c == EXIT_CELL:
				push_error("%s at %s blocks the entrance/exit (tile %s)" % [obj_name, cell, c])
				return false
			if occupied.has(c):
				push_error("%s at %s overlaps %s (tile %s)" % [obj_name, cell, occupied[c], c])
				return false
	for dz in size.y:
		for dx in size.x:
			occupied[cell + Vector2i(dx, dz)] = obj_name
	return true


## Builds an object's models around its own origin; `_fit_into_footprint`
## then moves the whole group into place.
func _build_object(o: Dictionary) -> Node3D:
	var root := _object_root()
	var model := root.get_node("Model") as Node3D
	if o.has("row"):
		var axis: String = o.get("axis", "x")
		var cursor := 0.0
		for entry: Array in o["row"]:
			var piece := _add_piece(model, entry[0], entry[1], entry[2])
			var size: Vector3 = piece.get_meta("size")
			var length := size.x if axis == "x" else size.z
			if axis == "x":
				piece.position.x = cursor + length / 2.0
			else:
				piece.position.z = cursor + length / 2.0
			_move_tops(piece)  # keep its small items on top of it
			cursor += length + PART_GAP
		return root
	var flat: bool = o.get("flat", false)
	var main := _add_piece(model, o["id"], o.get("rot", 0.0), o.get("top", []), flat, o.get("size", Vector2i.ONE))
	# Parts stand next to the main piece, centred on it, with a small gap;
	# a side starting with "next-" puts it next to the previous part instead.
	var previous := main
	for p: Array in o.get("parts", []):
		var piece := _add_piece(model, p[0], p[1], p[3])
		var side: String = p[2]
		var anchor := main
		if side.begins_with("next-"):
			anchor = previous
			side = side.substr(5)
		var a: Vector3 = anchor.get_meta("size")
		var b: Vector3 = piece.get_meta("size")
		var pos := anchor.position
		match side:
			"west":
				pos.x -= a.x / 2.0 + PART_GAP + b.x / 2.0
			"east":
				pos.x += a.x / 2.0 + PART_GAP + b.x / 2.0
			"north":
				pos.z -= a.z / 2.0 + PART_GAP + b.z / 2.0
			"south":
				pos.z += a.z / 2.0 + PART_GAP + b.z / 2.0
		piece.position = Vector3(pos.x, 0.0, pos.z)
		_move_tops(piece)
		previous = piece
	return root


## One model (centred, on the floor) plus the small items on its top.
## Rugs (`flat`) are scaled to fill their footprint instead.
func _add_piece(model: Node3D, id: String, rot: float, top: Array, flat := false, footprint := Vector2i.ONE) -> Node3D:
	var scale_mult := INTERIOR_SCALE
	if flat:
		var probe: Array = ModelLib.placed(id, rot)
		var raw: Vector3 = probe[1]
		(probe[0] as Node).free()
		var room_for := Vector2(footprint) * Grid.TILE * RUG_FILL
		scale_mult = minf(room_for.x / raw.x, room_for.y / raw.z)
	var placed: Array = ModelLib.placed(id, rot, scale_mult)
	var node: Node3D = placed[0]
	var size: Vector3 = placed[1]
	node.set_meta("size", size)
	model.add_child(node)
	# Small items stand on the top surface, spread evenly along its width.
	var tops: Array[Node3D] = []
	for i in top.size():
		var t: Array = top[i]
		var item: Array = ModelLib.placed(t[0], t[1], INTERIOR_SCALE)
		var item_node: Node3D = item[0]
		var spread := 0.0
		if top.size() > 1:
			spread = (float(i) / float(top.size() - 1) - 0.5) * size.x * 0.5
		item_node.set_meta("on_top_offset", Vector3(spread, size.y, 0.0))
		model.add_child(item_node)
		tops.append(item_node)
	node.set_meta("tops", tops)
	_move_tops(node)
	return node


func _move_tops(piece: Node3D) -> void:
	for item: Node3D in piece.get_meta("tops", []):
		item.position = piece.position + (item.get_meta("on_top_offset") as Vector3)


## Moves the object's models so the group sits inside its footprint:
## centred, or pushed back against the given walls (keeping WALL_CLEARANCE).
func _fit_into_footprint(root: Node3D, size: Vector2i, against: Array) -> void:
	var model := root.get_node("Model") as Node3D
	var box := ModelUtil.aabb_in(model, root)
	var half := Vector2(size) * Grid.TILE / 2.0
	var shift := Vector3(-box.get_center().x, 0.0, -box.get_center().z)
	if "north" in against:
		shift.z = -half.y + WALL_CLEARANCE - box.position.z
	if "west" in against:
		shift.x = -half.x + WALL_CLEARANCE - box.position.x
	if "east" in against:
		shift.x = half.x - WALL_CLEARANCE - box.end.x
	model.position += shift
	box = ModelUtil.aabb_in(model, root)
	if box.size.x > half.x * 2.0 or box.size.z > half.y * 2.0:
		push_error("%s (%s) doesn't fit its %s tile footprint" % [root.name, box.size, size])


## A Leafwind prop used as furniture. Its own collider is dropped: the room
## makes one after fitting it into its footprint.
func _build_deco(o: Dictionary) -> Node3D:
	var p := o.duplicate()
	p["type"] = o["deco"]
	var node := LeafwindProps.build(p)
	for cs in node.get_node("Body").get_children():
		cs.free()
	return node


## Fireplace (no pack has one): a stone chimney stack from the Fantasy Town
## Kit against the back wall, with a Survival Kit fire pit on its hearth.
func _build_fireplace() -> Node3D:
	var root := _object_root()
	var model := root.get_node("Model") as Node3D
	var chimney := _add_piece(model, "T:chimney-base", 90.0, [])
	var fire := _add_piece(model, "S:campfire-pit", 0.0, [])
	var a: Vector3 = chimney.get_meta("size")
	var b: Vector3 = fire.get_meta("size")
	fire.position.z = a.z / 2.0 + PART_GAP + b.z / 2.0
	var glow := OmniLight3D.new()
	glow.name = "FireGlow"
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.light_energy = 2.0
	glow.omni_range = 6.0
	glow.position = Vector3(0.0, 0.6, 0.3)
	fire.add_child(glow)
	return root


func _add_lamp_light(root: Node3D) -> void:
	var box := ModelUtil.aabb_in(root.get_node("Model"), root)
	var lamp := OmniLight3D.new()
	lamp.name = "LampLight"
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 2.2
	lamp.omni_range = 6.0
	lamp.position = Vector3(box.get_center().x, box.end.y + 0.15, box.get_center().z)
	root.add_child(lamp)


func _object_root() -> Node3D:
	var root := Node3D.new()
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	return root


## Box collider matching the object's models.
func _collider_from_model(root: Node3D) -> void:
	var box := ModelUtil.aabb_in(root.get_node("Model"), root)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = box.get_center()
	root.get_node("Body").add_child(cs)
	root.set_meta("solid", true)


## The room's villager stands on their own tile (claimed like furniture, so
## they never share a tile or stand on the entrance / exit).
func _place_villager(data: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Villagers"
	add_child(root)
	if not data.has("villager"):
		return
	var v: Dictionary = data["villager"]
	var cell: Vector2i = v["cell"]
	if not _claim(cell, Vector2i.ONE, "villager_" + v["id"]):
		return
	var villager := Villager.create(v["id"], cell_center(cell), v.get("facing", 0.0))
	if villager:
		villager.set_meta("cell", cell)
		root.add_child(villager)


func _spawn_player() -> void:
	Game.take_spawn()  # interiors always start at the entrance
	var player := get_node_or_null(player_path)
	if player:
		player.spawn_at(cell_center(ENTRANCE_CELL), PI)  # facing into the room
