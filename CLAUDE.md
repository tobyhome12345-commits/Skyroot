# First Game — rules for all work

This is a **Godot 4.7** project.

## Godot console

The Godot console exe is:

```
"C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
```

`godot_console` in these notes means that full path (it is not on PATH, so always use the full quoted path).

- Check for script errors after **every** change:
  `godot_console --headless --path . --editor --quit`
  (loads and parses every script; works even before a main scene exists).
  Once a main scene exists, also run it briefly: `godot_console --headless --path . --quit-after 60`
  Read the output; fix any `SCRIPT ERROR` / `ERROR` / `Parse Error` lines before moving on.
- Gameplay test (movement, blocking, F3 debug): `godot_console --headless --path . --script res://tools/test_movement.gd` — must print `RESULT: ALL PASSED`.
- Fit check (tiles, flush on ground, overlaps, colliders, gaps): `godot_console --headless --path . --script res://tools/check_fit.gd` must print `RESULT: ALL PASSED`. Run it after any change to props or models.
- Interior check (all 4 house interiors: tiles, flush stacking, overlaps, walls, colliders, floor, entrance→exit path, physics walk): `godot_console --headless --path . --script res://tools/check_interiors.gd` must print `RESULT: ALL PASSED`. Run it after any interior change.
- Door test (every house: prompt, E, fade, interior, exit, back in front of the same door): `godot_console --headless --path . --script res://tools/test_doors.gd`
- Window test (not headless; start maximized, F11 fullscreen, Esc untouched): `godot_console --path . --script res://tools/test_fullscreen.gd`
- Check the version: `godot_console --version`

## Display

- Base resolution is 1920x1080 with `canvas_items` stretch and `keep` aspect. The game starts maximized.
- F11 toggles fullscreen (`WindowControls` autoload). **Esc is reserved for the pause menu**, so don't bind it to anything else.
- Screen effects must look the same at any resolution, so size them by screen fraction, not pixels (see `shaders/tilt_shift.gdshader`).

## Assets

- Kenney CC0 packs live in `Assets/`. Credits are in `Assets/CREDITS.md`, so update it when a new pack is used.
- Use the GLB/GLTF files only. The other formats are skipped via `.gdignore`.
- Place models through `ModelLib` (`scripts/model_lib.gd`), which scales them to the tile footprint and sits them flush on the ground.

## Language

- **GDScript only.** No C#, no GDExtension, no other languages.

## Grid world

- Build the world on a grid. Every wall, floor and object snaps to **whole tile coordinates**.
- **No freeform decimal positions.** Positions come from integer tile coords (e.g. `Vector2i` / `Vector3i`) multiplied by a single tile-size constant — never hand-typed decimals.

## Work style

- **Never delete anything without asking the user first** and getting a yes. That includes generated files such as Godot `.import` files. The project is in OneDrive, so bulk deletes pop up alarming prompts.
- **Small steps only.** Do one small change at a time.
- **Test after each step** (at minimum the headless error check above).

## Git & GitHub

- Repo: https://github.com/tobyhome12345-commits/Skyroot (branch `main`, remote `origin`).
- **Always save, commit and push after every update** — no exceptions, however small the change.
  1. Save the game: make sure every changed scene (`.tscn`), resource (`.tres`) and script is written to disk.
  2. Run the error check.
  3. `git add`, commit with a clear message, then `git push`.
- **Never commit passwords, tokens or keys.** Check `git status` / `git diff --cached` before every commit.
- Show the user the push result (terminal output or the GitHub page) after each step.

## Screenshots

- Take screenshots while working and show them to the user.
- At least **one screenshot after each step**, plus extra ones after any big change.
- How: `godot_console --path . --script res://tools/screenshot.gd -- screenshots/<name>.png`
  This runs the project's main scene (if set) for a few frames and saves a PNG
  (not headless — it needs the GPU to render).
- Save them in `screenshots/` with a numbered name (e.g. `step03_walls.png`), then show them to the user.
