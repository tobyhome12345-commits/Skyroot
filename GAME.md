# Skyroot — game concept

- **What:** a cozy 3D open world of floating sky-island villages, seen from a fixed camera angle. You play a human.
- **Goal:** fix 4 islands (**Rootholm, Barkton, Leafwind, Seedhaven**), then heal the **Great Tree** and face the **Hollow Keeper**.
- **Travel:** flying between islands is a cutscene, not something you play.
- **Rules:**
  - Grid-based placement: everything snaps to whole tile coordinates.
  - Small steps.
  - One island per scene.

## Lore

- **The Great Tree** is the source of joy in the sky world and the mother of every tree. Its roots hold the islands up, and its gladness flows out into the world as colour, music and laughter.
- **The Old Promise:** long ago each island gave the tree a gift to keep it glad: **water** (Rootholm), **strength** (Barkton), **breath** (Leafwind) and **new life** (Seedhaven).
- **The Forgetting:** as the tree's gladness faded, so did people's joy. They forgot why they celebrated, the rituals became empty traditions, and the gifts stopped.
- **The Fading:** now colour is draining from the world, everyone is quiet and tired, and each of the four islands has a problem. Rumour says the tree's first caretaker still wanders its roots, lonely (a hint only, never named yet).
- **The traveller** (the player) is a human from far below the clouds, carrying a withered seed from the Great Tree that has been passed down in their family. It glows when they are near an island that needs help.
- **Colour level:** the world's colour is one value (`Game.colour_level`, 0 = drained, 1 = full). For now only the opening scene uses it; later the world's joy will drive it.

## Stages

1. **Pebblenook** (start island, working name): a grid-built island with houses, trees, a well, a notice board, a walkable player and a fixed follow camera.
   - **Asset pass:** placeholders replaced with Kenney CC0 models, and decoration added (see `Assets/CREDITS.md`).
   - **Interiors:** each of the 4 houses has its own room (elder's home, bedroom, workshop, library), entered with E.
   - **Villagers:** Elder Moss, Pip, Wren the Tinkerer and Scholar Quill indoors; Fennel the Gardener and Juniper the Traveller outside. Their lines live in `data/dialogue/*.json`: warm, a little funny, with hints of the fading Great Tree, the forgotten Promise of Root and Sky, festivals nobody remembers the reason for, and gossip about the other islands.
   - **Launch point:** a roped wooden ramp on Pebblenook's east edge, ending in a plank lip that overhangs the edge, with a flag and signpost beside it. "Press E" opens the destination menu (islands in `data/islands.json`; unknown ones are greyed out, the current one is tagged "You are here").
2. **Travel** between islands with the glide cutscene (the old Test Island has been removed).
   - **Glide cutscene:** about 8 s in two halves: run up the ramp, the glider opens, glide over the clouds; then the island drifts into view and the player lands on the landing tile. The shot list is in `data/cutscenes/glide.json`, played by the reusable `Cutscene` system (later: returning gifts to the Great Tree). Esc / Space skip.
   - **One game state** (`Game.state`): current island, visited islands, villager conversation progress and trip count carry across every trip.
3. **Opening lore scene** (`data/cutscenes/intro.json`, lines in `data/dialogue/elder_intro.json`): plays once, the first time a new game starts on Pebblenook. Elder Moss meets the traveller, the seed glows, and he tells of the Great Tree, the Old Promise, the Forgetting and the Fading, then points to the launch point. Esc / Space skip it. Afterwards Elder Moss gives short recaps.
4. **Small islands** (8 x 8 each, all reachable by gliding):
   - **Lookout Isle:** a bench and a low fence looking out at the withered Great Tree; E at the bench reads a wistful line.
   - **Trader's Rock:** Marigold the travelling trader at her red stall (cycling lines, no shop yet).
   - **Seed Isle:** a faintly glowing seed in soft earth, ringed by flowers; E reads a line hinting that something wants to grow there (it can't be collected yet).
