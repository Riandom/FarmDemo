# Findings

## Current Structure
- The project already separates `scenes`, `scripts`, `resources`, `assets`, `docs`, and `prompts`.
- Most runtime break risk comes from hardcoded `res://...` paths in `.tscn`, `.tres`, `.gd`, and `project.godot`.

## Reference Hotspots
- `project.godot` autoload section points at `scenes/systems/...`.
- `main.gd`, `crop_plot.gd`, `player.gd`, `config_manager.gd`, `farm_interaction_system.gd`, and several UI scripts contain string paths.
- Scene and resource files reference scripts directly through `ext_resource`.

## Migration Strategy
- Keep top-level folders stable.
- Standardize subfolders first to avoid rewriting unrelated asset and doc paths.
- Add `content/base` and `mods` as forward-looking directories for later data-driven and mod support.

## New Structure
- Runtime entry scene moved to `scenes/app`.
- Player assets moved under `scenes/actors/player` and `scripts/actors/player`.
- Farm world logic moved under `scenes/world/farm` and `scripts/world/farm`.
- Interactable furniture moved under `scenes/world/interactables` and `scripts/world/interactables`.
- Resource scripts consolidated under `scripts/data`.
- Data resources consolidated under `resources/data`.
- Editor tooling consolidated under top-level `tools`.
