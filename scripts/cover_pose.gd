extends RefCounted
## Single source of truth for the bow pose.
## Tune here (save the file, then reload the scene); scripts/plasma_bow.gd,
## scripts/bow_range_rig.gd and the Skeleton2D pilot all read these values,
## so a pose change is exactly ONE edit in ONE place.
## Discovery workflow: freeze a pose in the pilot (TUNE mode), drag bones
## freely, press C to print the joints, paste the block below.
const AIM := 0.6
const GRIP := Vector2(18, -100)
const FAR_SHOULDER := Vector2(2, -114)
const FAR_ELBOW := Vector2(-4, -72)
const NEAR_SHOULDER := Vector2(-13, -106)
const NEAR_ELBOW := Vector2(-9.7, -73.2)
const NOCK_OFFSET := Vector2(2.6, -5.1)
# Aim-mode bases (grip sweep center, far shoulder, draw shoulder).
const AIM_SHOULDER := Vector2(8, -126)
const FAR_BASE := Vector2(8, -116)
const DRAW_SHOULDER := Vector2(-11, -126)
