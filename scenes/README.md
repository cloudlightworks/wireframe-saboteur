# Wireframe Saboteur — Gameplay Tutorial

## Install

Copy these files into the matching project folders:

- `scripts/tutorial_controller.gd` → `res://scripts/tutorial_controller.gd`
- `scripts/tutorial_overlay.gd` → `res://scripts/tutorial_overlay.gd`
- `scripts/tutorial_data.gd` → `res://scripts/tutorial_data.gd`
- `scenes/tutorial.tscn` → `res://scenes/tutorial.tscn`
- `scripts/menu_root.gd` → replace the current `res://scripts/menu_root.gd`

Then use **Project → Reload Current Project** before running.

The existing How to Play page already emits `tutorial_requested`. The patched
`menu_root.gd` replaces its placeholder handler with an instance of
`res://scenes/tutorial.tscn`. The tutorial emits `finished` to return to the menu.

## What it contains

The tutorial is a deterministic sequence of staged positions:

1. Croce placement of one A, B, C, General, and Objective
2. Optional B rotation with R or the on-screen button
3. A, B, C, and General movement
4. Objective capture
5. A>C, C>B, B>A
6. Same-type mutual destruction
7. C double capture and two-card reward
8. General capture and General immunity
9. Type + Chart Saboteur declaration
10. Saboteur capture of a General
11. Close Call deployment and altered mutual result
12. Ten-card hand and discard-to-nine exercise
13. C overlap blocked by an A
14. Brief explanations of remaining power-card and movement exceptions
15. Return to the menu

## Architecture

The tutorial uses the existing:

- `res://scenes/board.tscn`
- `Piece`
- `PieceView`
- `MoveHighlight`
- board and piece art
- card textures

It does not call or modify the normal match controller. Tutorial outcomes are
staged by `tutorial_controller.gd`; tutorial copy and setups are centralized in
`tutorial_data.gd`.

## Editing

Most wording, focus rectangles, destinations, and staged piece arrangements are
in `tutorial_data.gd`.

The right-side panel styling is in `tutorial_overlay.gd`.

Board zoom/cropping, clicks, card selection, and scene progression are in
`tutorial_controller.gd`.

## Validation note

The files were checked for internal path consistency and balanced GDScript
delimiters. Godot was not installed in the file-generation environment, so run
the project once after copying the files and report the first parser/runtime
error verbatim if Godot exposes one.
