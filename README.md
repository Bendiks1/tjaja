# Deck Builder Roguelike (working title: tjaja)

Solo offline deck-building roguelike for short mobile sessions, built in Godot 4.3+.
See `docs/` (added as the project grows) for design notes; for now the source of
truth is the project structure itself:

```
game_logic/   pure GDScript game rules — no Node/scene dependencies, fully unit-testable
data/         Resource subclasses (.tres) for cards, enemies, relics, potions, events
scenes/       Godot scenes (screens + reusable components)
scripts/      controller scripts attached to scenes
state/        autoload singletons (RunState, MetaProgression, EventBus, ...)
persistence/  save/load to user:// as JSON
tests/        GUT unit tests
```

## Running tests

Requires Godot 4.3+ on your machine (the GUT addon is vendored in `addons/gut`).

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

## Running the game

Open `project.godot` in the Godot editor, or run headless/with a window via:

```sh
godot .
```
