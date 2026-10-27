class_name DirectorConfig
extends Resource
## The director's rule table (`data/ai/director_rules.tres`): one DirectorRule per play style.
## Tuning the AI means editing this file, not the code.

## Style key ("aggressive", "stealth", "balanced") -> DirectorRule. The extra key "ranged" is not a
## style: it is added on top of the style's reaction when the player keeps shooting from afar.
@export var rules: Dictionary = {}
## `|aggression - stealth|` at which the reaction reaches full strength; below it, it scales
## linearly (a player who is only slightly aggressive gets a slight reaction).
@export_range(0.05, 1.0) var full_intensity_difference := 0.6
## The "balanced" style has no clear direction, so its rule applies at this fixed strength.
@export_range(0.0, 1.0) var balanced_intensity := 1.0

## Distance score (0 = shoots up close, 1 = from afar) at which the "ranged" rule starts to apply;
## it reaches full strength at 1.
@export_range(0.0, 0.95) var ranged_threshold := 0.6

@export_group("Texts")
## Player-facing texts (Spanish).
@export var texts: Dictionary = {}
