# Tune the player armed-cover pose

The movement playground uses a rifle, not the separate bow-range rig. Its player cover hold is now authored in animations/armed_cover.tscn with AnimationPlayer. The one-second looping animation currently has one pose key at time zero. Existing cover tint/scale transitions and arm/leg IK remain procedural. The shared player rig also uses this pose in the main game; enemies retain their previous poses.

1. Open animations/armed_cover.tscn in Godot and switch to the 2D workspace. The actual character artwork appears at the scene origin; zoom in around it. If this scene was open before the preview update, close and reopen its tab.
2. Select AnimationPlayer and choose armed_cover (not RESET) in the Animation panel.
3. Find the Torso/RightShoulder:position track and click its key at 0 seconds.
4. In the Inspector, edit that key's Vector2 value. The default is (-9, 9). Try (-9, 3) to raise the shoulder six local units. Smaller Y moves up; larger X moves forward when facing right. Facing left mirrors the pose.
5. The body updates directly in the editor as the pose changes. Scrub the timeline to inspect the selected time (click 0 seconds again after changing the hold key if needed). No game restart is required. Save the scene with Ctrl+S. Edit the animation key, not just the node's Transform: playback overwrites the node from its key.
6. Optionally check the pose in gameplay: open debug_movement.tscn and press F6. Keep the weapon drawn (S toggles it), then hold Up to take cover. Press P while holding Up to freeze the pose; Z changes zoom.
7. To check the mirrored pose in the editor, select the ArmedCover root and toggle Preview Face Left. This preview setting does not change the gameplay facing.

The editor preview uses the same rig and artwork renderer as the game, with cover fully applied. It runs no gameplay or physics and never plays or seeks the animation itself; the Animation panel remains in control. Use the key's numeric value for tuning: control nodes are data anchors consumed by the procedural rig, not a directly draggable character skeleton. RightShoulder is the near, weapon-gripping arm. Its coordinates are offsets from the torso anchor. The elbow is solved toward the weapon grip, so moderate shoulder changes preserve hand contact.

You can add more keys to the same track to animate the shoulder over the one-second loop. The current migration authors the cover hold, not a new entering-cover transition.

Validation: tests/cover_animation.gd checks animation binding, key edits, and exit/re-entry. With --capture it also checks that the rendered upper arm starts at the animated shoulder and writes preview-cover-animation.png.

Editor validation: tests/cover_editor_preview.gd (run with --editor) checks automatic preview creation, timeline scrubbing, facing, and that preview nodes are not serialized. Add -- --capture to check the rendered arm and save preview-cover-editor.png.
