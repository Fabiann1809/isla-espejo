"""Shared palette of the Templo del Eclipse (island 3), measured from the concept images in
docs/referencias/templo_* and trimmed. Every temple art tool imports it so tiles, props and effects
read as one set. Light comes from the upper left; outlines are OUTLINE (never pure black).
Import from a tool in tools/:  from temple_palette import *"""


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


CLEAR = (0, 0, 0, 0)
OUTLINE = rgb("#1a0c10")

# Temple stone: warm rosy grey, darkest in joints and cliff bases. STONE_0 is the ground level's
# slab (a dusty, darker rose between STONE_1 and STONE_2), so the three floors read as three heights.
STONE_D = rgb("#302221")
STONE_0 = rgb("#5f403c")
STONE_1 = rgb("#523337")
STONE_2 = rgb("#70483f")
STONE_3 = rgb("#8f5f59")
STONE_4 = rgb("#a8766a")
STONE_HI = rgb("#c99a86")
JOINT = rgb("#3e2024")

# Cliff faces: the same stone, darker and redder; lit from below by the lava near their foot.
CLIFF_D = rgb("#201216")
CLIFF_1 = rgb("#331518")
CLIFF_2 = rgb("#4f2221")
CLIFF_3 = rgb("#663631")
CLIFF_LAVA_LIT = rgb("#9f260e")

# Lava: from the cooled crust at the rim to the white-hot core.
CRUST_D = rgb("#1c0d0d")
CRUST_1 = rgb("#3a1712")
LAVA_D = rgb("#6a2219")
LAVA_1 = rgb("#9f260e")
LAVA_2 = rgb("#e42d03")
LAVA_3 = rgb("#fb4b03")
LAVA_4 = rgb("#ff8a1e")
LAVA_HI = rgb("#ffd36a")
LAVA_CORE = rgb("#fff3c4")

# Fire (torches, braziers, jets) shares the lava's top end.
FIRE_D = rgb("#cf4b13")
FIRE_1 = rgb("#fb6a10")
FIRE_2 = rgb("#ffa632")
FIRE_HI = rgb("#ffe68a")

# Moss and vines.
MOSS_D = rgb("#2f3a14")
MOSS_1 = rgb("#4f5e1c")
MOSS_2 = rgb("#7a8a2a")
MOSS_HI = rgb("#b4c04a")

# Bronze and dull gold for reliefs, braziers and runes; red for banners.
BRONZE_D = rgb("#5b4430")
BRONZE_1 = rgb("#8b694e")
BRONZE_2 = rgb("#be7c48")
GOLD_HI = rgb("#e1a349")
RUNE_GLOW = rgb("#ffb347")
BANNER_D = rgb("#4f1418")
BANNER_1 = rgb("#8a1e22")
BANNER_2 = rgb("#c43a2c")

# Smoke and ash.
SMOKE_D = rgb("#2a2224")
SMOKE_1 = rgb("#4a3e3e")
SMOKE_2 = rgb("#6e6060")
ASH = rgb("#9a8a82")
