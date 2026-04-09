# Project Structure

## Purpose
This project structure is designed for a small Godot farming game demo that can grow into a more data-driven and mod-friendly project without forcing an early full rewrite.

## Top-Level Folders
- `assets/`: art, audio, and other raw game assets.
- `content/base/`: future home for official gameplay content data meant to become more moddable over time.
- `docs/`: architecture notes, phase docs, and project guidance.
- `mods/`: future player mod entry folder.
- `prompts/`: AI task prompts and build phases.
- `resources/`: Godot resource files and structured gameplay data.
- `scenes/`: Godot scenes organized by game role.
- `scripts/`: gameplay code organized by runtime role.
- `tools/`: editor scripts and content-generation tools.

## Scenes
- `scenes/app/`: app entry scenes such as the main playable scene.
- `scenes/actors/`: player and future NPC or enemy scenes.
- `scenes/world/`: farm tiles, interactables, and future exploration map scenes.
- `scenes/ui/`: user interface scenes.
- `scenes/systems/`: autoload or global system scenes.

## Scripts
- `scripts/app/`: scene controllers for top-level app flow.
- `scripts/actors/`: player and future actor behavior scripts.
- `scripts/world/`: world objects, farm logic, and interactables.
- `scripts/ui/`: UI logic.
- `scripts/systems/`: global managers and cross-scene systems.
- `scripts/data/`: typed Godot resource scripts and data definitions.

## Resources
- `resources/data/`: current gameplay config resources such as crops, tools, seasons, and shop data.

## Rules
- Put runtime gameplay code in `scripts/`, not `tools/`.
- Put editor-only generation scripts in `tools/`.
- Put reusable content definitions in `resources/data/` now, and gradually move player-editable content toward `content/base/`.
- Keep systems thin. Avoid turning one manager into a catch-all owner of every rule.
- New folders should be added by gameplay role, not by development phase.
