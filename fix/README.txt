Replace these two files in res://scripts/, then reload the Godot project.

Fixes:
- adds the missing setup_pieces("croce") preview;
- clears the preview before interactive placement starts;
- derives BoardArea geometry from the viewport when Control layout is zero;
- removes the unsuccessful recursive focus retry.
