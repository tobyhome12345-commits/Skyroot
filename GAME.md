# Skyroot — game concept

- **What:** a cozy 3D open world of floating sky-island villages, seen from a fixed camera angle. You play a human.
- **Goal:** fix 4 islands (**Rootholm, Barkton, Leafwind, Seedhaven**), then heal the **Great Tree** and face the **Hollow Keeper**.
- **Travel:** flying between islands is a cutscene, not something you play.
- **Rules:**
  - Grid-based placement: everything snaps to whole tile coordinates.
  - Small steps.
  - One island per scene.

## Stages

1. **Pebblenook** (start island, working name): a grid-built island with houses, trees, a well, a notice board, a walkable player and a fixed follow camera.
   - **Asset pass:** placeholders replaced with Kenney CC0 models, and decoration added (see `Assets/CREDITS.md`).
   - **Interiors:** each of the 4 houses has its own room (elder's home, bedroom, workshop, library), entered with E.
   - **Villagers:** Elder Moss, Pip, Wren the Tinkerer and Scholar Quill indoors; Fennel the Gardener and Juniper the Traveller outside. Their lines live in `data/dialogue/*.json`: warm, a little funny, with hints of the fading Great Tree, the forgotten Promise of Root and Sky, festivals nobody remembers the reason for, and gossip about the other islands.
