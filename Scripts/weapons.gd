extends RefCounted

# Gun = fires bullets and uses ammo. Melee = swings in an arc and never needs ammo.
enum Type { GUN, MELEE }

# Every weapon is a dictionary. Anything left out falls back to the default shown in brackets.
#
# ---- Fields every weapon has ----
#   name             - the weapon's name; shown on screen now, and used for inventory items later
#   type             - Type.GUN or Type.MELEE
#   damage           - damage per bullet or per melee hit
#   cooldown         - seconds between attacks (for an automatic gun, the time between bullets)
#   knockback_scale  - how hard a hit shoves an enemy (1.0 = normal) [1.0]
#
# ---- Gun fields ----
#   max_ammo         - the most ammo that can be loaded at once
#   shot_rate        - bullets per click:
#                        1  = one bullet
#                        3  = three bullets (fired one after another, or all at once if spread is true)
#                       -1  = infinite: keeps firing while the button is held (rifle)
#   reload_rate      - bullets reloaded per second. Reloading is passive: it happens on its own
#                      whenever you aren't shooting (Cult of the Lamb style). There is infinite
#                      total ammo, so you never run out of reloads.
#   spread           - true = the bullets from one click fan out in a cone (shotgun) and the whole
#                      click costs 1 ammo. false = every bullet costs 1 ammo.
#   spread_angle     - width of the cone in degrees, used when spread is true [20.0]
#   inaccuracy       - random wobble in degrees for guns that don't use spread [0.0]
#   burst_delay      - seconds between bullets when shot_rate is 2 or more and spread is false [0.06]
#   reload_delay     - seconds after the last shot before reloading starts again [0.6]
#   bullet_speed     - units per second [30.0]
#   range            - how far a bullet flies before it disappears [30.0]
#
# ---- Melee fields ----
#   melee_range      - how far the swing reaches [3.0]
#   melee_arc        - width of the swing in degrees [120.0]
#   windup           - seconds between pressing attack and the hit landing; heavy weapons are slower [0.0]
#   lunge            - how far the player steps toward the target while swinging [0.0]
const LIST := [
	{
		"name": "Pistol",
		"type": Type.GUN,
		"max_ammo": 8,
		"shot_rate": 1,
		"reload_rate": 2.0,
		"spread": false,
		"damage": 10,
		"cooldown": 0.28,
		"bullet_speed": 32.0,
		"range": 30.0,
		"inaccuracy": 0.0,
		"reload_delay": 0.6,
		"knockback_scale": 1.0,
	},
	{
		"name": "Rifle",
		"type": Type.GUN,
		"max_ammo": 30,
		"shot_rate": -1,
		"reload_rate": 7.0,
		"spread": false,
		"damage": 6,
		"cooldown": 0.11,
		"bullet_speed": 36.0,
		"range": 34.0,
		"inaccuracy": 4.0,
		"reload_delay": 0.8,
		"knockback_scale": 0.5,
	},
	{
		"name": "Burst Rifle",
		"type": Type.GUN,
		"max_ammo": 18,
		"shot_rate": 3,
		"reload_rate": 3.0,
		"spread": false,
		"damage": 7,
		"cooldown": 0.45,
		"burst_delay": 0.06,
		"bullet_speed": 36.0,
		"range": 32.0,
		"inaccuracy": 2.0,
		"reload_delay": 0.7,
		"knockback_scale": 0.6,
	},
	{
		"name": "Shotgun",
		"type": Type.GUN,
		"max_ammo": 6,
		"shot_rate": 6,
		"reload_rate": 1.2,
		"spread": true,
		"spread_angle": 24.0,
		"damage": 5,
		"cooldown": 0.8,
		"bullet_speed": 28.0,
		"range": 9.0,
		"reload_delay": 1.0,
		"knockback_scale": 0.45,
	},
	{
		"name": "Sword",
		"type": Type.MELEE,
		"damage": 12,
		"cooldown": 0.4,
		"melee_range": 3.0,
		"melee_arc": 130.0,
		"windup": 0.05,
		"lunge": 0.6,
		"knockback_scale": 1.4,
	},
	{
		"name": "Spear",
		"type": Type.MELEE,
		"damage": 14,
		"cooldown": 0.65,
		"melee_range": 4.8,
		"melee_arc": 35.0,
		"windup": 0.12,
		"lunge": 1.4,
		"knockback_scale": 1.0,
	},
	{
		"name": "Hammer",
		"type": Type.MELEE,
		"damage": 25,
		"cooldown": 1.1,
		"melee_range": 2.6,
		"melee_arc": 160.0,
		"windup": 0.35,
		"lunge": 0.3,
		"knockback_scale": 2.2,
	},
]
