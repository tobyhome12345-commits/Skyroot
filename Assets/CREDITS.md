# Credits

All 3D models in Skyroot come from free asset packs by **Kenney** (https://kenney.nl).
Every pack is released under **Creative Commons Zero (CC0 1.0)**:
https://creativecommons.org/publicdomain/zero/1.0/
Credit isn't required, but it's given here gladly. Thank you, Kenney!

## Packs used in the game

| Pack (version) | Folder | Used for | Source | Licence |
|---|---|---|---|---|
| Fantasy Town Kit (2.0) | `Assets/Houses/` | House walls, doors, windows and roofs; pine and round trees; lanterns; back fence; rocks; cart; well parts (stone basin, wooden posts, pointed roof); notice board parts (posts, plank board, roof); interior walls, floor boards, and the stone chimney of the library fireplace; the plank lip of the launch point | kenney.nl | CC0 |
| Platformer Kit (4.1) | `Assets/Platformer Kit/` | Bushy round trees, flowers, tall flowers, grass tufts, mushrooms; the launch point's wooden ramp (`platform-ramp`), rope rails (`fence-rope`) and flag (`flag`) | kenney.nl | CC0 |
| Mini Forest (1.0) | `Assets/Mini Forest/` | Small leafy plants; Fennel the Gardener (`character-archer`) | kenney.nl | CC0 |
| Survival Kit (2.0) | `Assets/Survival Kit/` | Barrels, crates, the well's bucket; workshop workbenches, anvil, grinder, tools, chest and bottles; the fire pit in the library fireplace; the launch point's signpost (`signpost-single`) | kenney.nl | CC0 |
| Furniture Kit (2.0) | `Assets/Furniture Kit/` | All house-interior furniture: kitchen, beds, desks, chairs, sofas, tables, bookcases, lamps, rugs, plants, books, radio, laptop, teddy bear, the floor base and the exit doorways | kenney.nl | CC0 |
| Mini Characters (2.0) | `Assets/Mini Characters/` | Player character (`character-male-a`) with its walk and idle animations; villagers Elder Moss (`character-male-g`), Pip (`character-female-b`), Wren (`character-worker`), Scholar Quill (`character-male-e`) and Juniper (`character-female-c`) | kenney.nl | CC0 |
| Modular Cave Kit (1.0) | `Assets/Modular Cave/` | Carved rock cliff walls around the island rim, dirt-and-stone path tiles, and the stone texture on the island ground and underside | kenney.nl | CC0 |
| Skyboxes (1.0) | `Assets/Skyboxes/` | The sky (`skybox-day` panorama) | kenney.nl | CC0 |

## Packs in the project but not used yet

All CC0, from kenney.nl: Nature Kit (2.1), Hexagon Kit (2.0), Mini Arena (1.1),
Food Kit (2.0).

## Notes

- The glider in the glide cutscene (`scripts/glider.gd`) and the two wooden braces under the launch point's lip are built in code from simple shapes, not taken from a pack.

- Only the GLB/GLTF versions of the models are imported. The other formats
  (FBX, OBJ, DAE, STL) and preview images are skipped by Godot via `.gdignore` files.
- The ground's stone texture is the 128 x 128 px stone square cut from the Modular
  Cave colour atlas in code (`ModelLib.stone_texture()`).
- The red roofs use a recoloured copy of the Fantasy Town Kit colour atlas,
  made in code (`scripts/model_lib.gd`) from the pack's own red swatch.
