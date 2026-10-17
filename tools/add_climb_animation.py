import re

def main():
    with open("characters/run_sheathed.tscn", "r", encoding="utf-8") as f:
        content = f.read()

    # Extract tracks from sub_resource run
    run_match = re.search(r'(\[sub_resource type="Animation" id="run"\].*?)(?=\n\[sub_resource type="AnimationLibrary")', content, re.DOTALL)
    if not run_match:
        print("Could not find run animation")
        return

    run_text = run_match.group(1)

    # Find all track paths
    track_blocks = re.findall(r'tracks/(\d+)/path = NodePath\("([^"]+)"\)', run_text)
    print(f"Found {len(track_blocks)} tracks in run_sheathed")

    climb_times = [round(1.083308 * i / 12.0, 8) for i in range(13)]
    times_str = ", ".join(str(t) if t != 0 else "0" for t in climb_times)
    trans_str = ", ".join(["1"] * 13)
    phase_vals = [0.0, 0.08333333325, 0.1666666665, 0.24999999975, 0.333333333, 0.4166666665, 0.5, 0.5833333335, 0.666666667, 0.75000000025, 0.8333333335, 0.91666666675, 1.0]

    lines = [
        '[sub_resource type="Animation" id="climb"]',
        'resource_name = "climb_sheathed"',
        'length = 1.083308',
        'loop_mode = 1',
        'step = 0.016666668'
    ]

    for idx, (track_idx, path) in enumerate(track_blocks):
        lines.append(f'tracks/{idx}/type = "value"')
        lines.append(f'tracks/{idx}/imported = false')
        lines.append(f'tracks/{idx}/enabled = true')
        lines.append(f'tracks/{idx}/path = NodePath("{path}")')
        lines.append(f'tracks/{idx}/interp = 1')
        lines.append(f'tracks/{idx}/loop_wrap = true')
        lines.append(f'tracks/{idx}/keys = {{')
        lines.append(f'"times": PackedFloat32Array({times_str}),')
        lines.append(f'"transitions": PackedFloat32Array({trans_str}),')
        lines.append(f'"update": 0,')
        if path == ".:phase":
            lines.append(f'"values": {phase_vals}')
        elif path.endswith(":scale"):
            vals = ", ".join(["Vector2(1, 1)"] * 13)
            lines.append(f'"values": [{vals}]')
        elif path.endswith(":position") or path in [".:hip_offset", ".:torso_offset", ".:front_foot_offset", ".:back_foot_offset", ".:weapon_offset"]:
            vals = ", ".join(["Vector2(0, 0)"] * 13)
            lines.append(f'"values": [{vals}]')
        else:
            vals = ", ".join(["0.0"] * 13)
            lines.append(f'"values": [{vals}]')
        lines.append('}')

    climb_text = "\n".join(lines)

    # Insert climb animation before library
    new_content = content.replace(
        '[sub_resource type="AnimationLibrary" id="library"]',
        climb_text + '\n\n[sub_resource type="AnimationLibrary" id="library"]'
    )

    # Update library _data to include climb and climb_sheathed
    old_library_data = '&"run_sheathed": SubResource("run")'
    new_library_data = '&"climb": SubResource("climb"),\n&"climb_sheathed": SubResource("climb"),\n&"run_sheathed": SubResource("run")'
    new_content = new_content.replace(old_library_data, new_library_data)

    # Update instruction label
    old_label = 'text = "SHEATHED RUN — procedural motion + AnimationPlayer edits\nEditor: select Controls/AnimationPlayer, choose run_sheathed, and scrub.\nSelect a bone, move/rotate it, and key its transform. Neutral bones reproduce the original motion.\nF6 plays the loop. See RUN-ANIMATION-EDITING.md for controls and examples."'
    new_label = 'text = "SHEATHED RUN & CLIMB — procedural motion + AnimationPlayer edits\nEditor: select Controls/AnimationPlayer, choose run_sheathed or climb_sheathed, and scrub.\nSelect a bone, move/rotate it, and key its transform. Neutral bones reproduce the original motion.\nF6 plays the loop. See RUN-ANIMATION-EDITING.md for controls and examples."'
    new_content = new_content.replace(old_label, new_label)

    with open("characters/run_sheathed.tscn", "w", encoding="utf-8") as f:
        f.write(new_content)

    print("Successfully added climb animation to run_sheathed.tscn")

if __name__ == "__main__":
    main()
