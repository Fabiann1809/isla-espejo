class_name ProfileConfig
extends Resource
## Tuning of the player profile (AI layer 1). Lives in `data/ai/profile_config.tres`, so the
## behaviour can be adjusted without touching code. Also holds every player-facing text of the
## profile summary screen (Spanish).

@export_group("Learning")
## How strongly one full run moves the saved profile (0 = never learns, 1 = forgets the past).
@export_range(0.0, 1.0) var learning_rate := 0.5
## Runs shorter than this are ignored (the player barely played).
@export var min_run_seconds := 15.0
## A run this long (or longer) counts with full confidence.
@export var full_confidence_seconds := 120.0
## Seconds of the current run needed for the live estimate to lean fully on it.
@export var live_full_seconds := 60.0
## Maximum share of the current run in the live estimate (the rest is the saved profile).
@export_range(0.0, 1.0) var live_weight := 0.7

@export_group("Classification")
## `aggression - stealth` beyond this distance from 0 makes the player aggressive or stealthy.
@export_range(0.0, 1.0) var style_threshold := 0.15

@export_group("Normalization")
## Melee attacks per minute that count as "fully aggressive".
@export var attacks_per_minute_max := 30.0
## Fraction of the run spent hidden that counts as "fully stealthy".
@export_range(0.01, 1.0) var stealth_fraction_max := 0.25
## Detections per enemy room at or above which the player counts as "always seen".
@export var detections_per_room_max := 2.0

@export_group("Aggression weights")
@export var w_attack_rate := 0.35
@export var w_fight_ratio := 0.35
@export var w_aggressive_skills := 0.15

@export_group("Stealth weights")
@export var w_evasion_ratio := 0.35
@export var w_stealth_time := 0.25
@export var w_low_detection := 0.2
@export var w_stealth_skills := 0.2

@export_group("Skill styles")
## Skill id -> "aggressive" or "stealth". Skills not listed are neutral.
@export var skill_styles: Dictionary = {}

@export_group("Texts")
## Player-facing texts (Spanish) of the profile summary screen.
@export var texts: Dictionary = {}
