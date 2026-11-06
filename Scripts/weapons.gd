extends RefCounted

# How a weapon fires:
#   MANUAL  - one shot per click
#   AUTO    - keeps firing while the button is held
#   BURST   - one click fires a quick burst of shots
#   SHOTGUN - one click fires several pellets in a spread
#   MELEE   - swings in an arc in front of the player
enum Mode { MANUAL, AUTO, BURST, SHOTGUN, MELEE }

# Every weapon is a dictionary. Anything left out falls back to a default in player.gd.
#
# Shared:
#   name             - shown in the on-screen label
#   mode             - one of Mode above
#   damage           - damage per bullet / per melee hit
#   cooldown         - seconds before the next attack (for BURST, the pause after the burst ends)
#   knockback_scale  - how hard a hit shoves an enemy (1.0 = normal)
# Guns:
#   bullet_speed     - units per second
#   range            - how far a bullet flies before it disappears
#   spread           - total cone in degrees the shots land in
#   pellets          - bullets per shot (SHOTGUN)
#   burst_count      - shots per burst (BURST)
#   burst_delay      - seconds between shots in a burst (BURST)
# Melee:
#   melee_range      - how far the swing reaches
#   melee_arc        - width of the swing in degrees
const LIST := [
	{
		"name": "Pistol",
		"mode": Mode.MANUAL,
		"damage": 10,
		"cooldown": 0.28,
		"bullet_speed": 32.0,
		"range": 30.0,
		"spread": 0.0,
		"knockback_scale": 1.0,
	},
	{
		"name": "Rifle",
		"mode": Mode.AUTO,
		"damage": 6,
		"cooldown": 0.11,
		"bullet_speed": 36.0,
		"range": 34.0,
		"spread": 5.0,
		"knockback_scale": 0.5,
	},
	{
		"name": "Burst Rifle",
		"mode": Mode.BURST,
		"damage": 7,
		"cooldown": 0.5,
		"bullet_speed": 36.0,
		"range": 32.0,
		"spread": 3.0,
		"burst_count": 3,
		"burst_delay": 0.06,
		"knockback_scale": 0.6,
	},
	{
		"name": "Shotgun",
		"mode": Mode.SHOTGUN,
		"damage": 5,
		"cooldown": 0.85,
		"bullet_speed": 28.0,
		"range": 9.0,
		"spread": 24.0,
		"pellets": 6,
		"knockback_scale": 0.45,
	},
	{
		"name": "Sword",
		"mode": Mode.MELEE,
		"damage": 12,
		"cooldown": 0.4,
		"melee_range": 3.0,
		"melee_arc": 130.0,
		"knockback_scale": 1.4,
	},
	{
		"name": "Spear",
		"mode": Mode.MELEE,
		"damage": 14,
		"cooldown": 0.65,
		"melee_range": 4.8,
		"melee_arc": 35.0,
		"knockback_scale": 1.0,
	},
]
