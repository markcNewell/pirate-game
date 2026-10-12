"""The sloop's layout: a copy of game/ship/sloop_hull.gd for the Blender scripts.

The game plays on those numbers (deck, rails, hit box, stations); the model must sit on the
same ones. tests/test_models.gd checks the exported hull against SloopHull. The names match
shipshape.py where they mean the same, so ship.py's builders can draw her too (sloop.py).
"""

import math

HALF_LENGTH = 5.6
BEAM = 3.6
KEEL_Y = -0.9
DECK_Y = 1.2
BOW_DECK_Z = -4.9
STERN_Z = 5.1

RAIL_HEIGHT = 0.7
RAIL_BLOCK = 0.55
RAIL_THICKNESS = 0.12

# No quarterdeck: past the stern, so nothing ever rises to one.
QUARTER_Z = 99.0
QUARTER_Y = DECK_Y

MAST_Z = [-1.3]
MAST_HEIGHT = [10.0]
MAST_RADIUS = 0.2

LADDER_Z = 0.9
LADDER_GAP = 0.6

WHEEL = (0.0, DECK_Y, 3.8)
CAPSTAN = (0.0, DECK_Y, -3.6)
MAP_TABLE = (-0.85, DECK_Y, 2.1)
BANANAS = (0.9, DECK_Y, 2.2)
SAIL_POST = (0.0, DECK_Y, MAST_Z[0])  # the pin rail round the mast's foot

# The one square sail: its yard's height above the deck, the sail's height and width.
SAIL_TOP = 7.4
SAIL_HEIGHT = 5.2
SAIL_WIDTH = 4.6


def half_width(z, y):
    t = z / HALF_LENGTH
    plan = 1.0 - 0.85 * max(0.0, -t) ** 2 - 0.3 * max(0.0, t) ** 4
    v = min(1.0, max(0.0, (y - KEEL_Y) / (DECK_Y - KEEL_Y)))
    return 0.5 * BEAM * plan * (0.35 + 0.65 * v ** 0.6)


def rail_top(z, gaps=True):
    if gaps and abs(z - LADDER_Z) < LADDER_GAP:
        return DECK_Y + 0.08
    return DECK_Y + RAIL_HEIGHT


def floor_y(z, x):
    return DECK_Y


def side_normal(z, y, side):
    """Outward normal of the hull side at (z, y) (Godot axes), for placing things on it."""
    e = 0.01
    dy = (half_width(z, y + e) - half_width(z, y - e)) / (2 * e)
    dz = (half_width(z + e, y) - half_width(z - e, y)) / (2 * e)
    n = (side, -dy, -dz)
    length = math.sqrt(sum(c * c for c in n))
    return tuple(c / length for c in n)
