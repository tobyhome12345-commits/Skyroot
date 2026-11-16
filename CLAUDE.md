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
- Check the version: `godot_console --version`

## Language

- **GDScript only.** No C#, no GDExtension, no other languages.

## Grid world

- Build the world on a grid. Every wall, floor and object snaps to **whole tile coordinates**.
- **No freeform decimal positions.** Positions come from integer tile coords (e.g. `Vector2i` / `Vector3i`) multiplied by a single tile-size constant — never hand-typed decimals.

## Work style

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
