"""The galleon's layout: a copy of game/ship/ship_shape.gd for the Blender scripts.

The game plays on those numbers (decks, rails, hit boxes, stations); the model must sit on the
same ones. Keep the two in step: tests/test_models.gd checks the exported hull against
ShipShape.
"""

import math

HALF_LENGTH = 13.0
BEAM = 7.5
KEEL_Y = -2.2
DECK_Y = 3.0
BOW_DECK_Z = -12.4
STERN_Z = 12.6

RAIL_HEIGHT = 1.0
RAIL_BLOCK = 0.75
RAIL_THICKNESS = 0.18

QUARTER_Z = 6.0
QUARTER_Y = 5.2
STAIR_BOTTOM_Z = 2.4
STAIR_HALF_WIDTH = 1.1

LOWER_Y = -0.8
LOWER_Z0 = -9.5
LOWER_Z1 = 5.8
WALL_INSET = 0.1

HATCH_Z0 = -5.5
HATCH_Z1 = -4.0
HATCH_X = 0.55
COAMING = 0.4

MAST_Z = [-6.5, 0.8]
MAST_HEIGHT = [18.0, 22.0]
MAST_RADIUS = 0.35

LADDER_Z = -2.5
LADDER_GAP = 0.75

CAPSTAN = (0.0, DECK_Y, -3.2)
WHEEL = (0.0, QUARTER_Y, 9.0)
MAP_TABLE = (-2.1, QUARTER_Y, 9.4)
CLUTTER = [
    ((-2.35, DECK_Y + 0.45, -7.8), (0.38, 0.45, 0.38), "barrel"),
    ((-1.75, DECK_Y + 0.45, -8.55), (0.38, 0.45, 0.38), "barrel"),
    ((2.0, DECK_Y + 0.35, -8.2), (0.4, 0.35, 0.4), "crate"),
    ((2.05, DECK_Y + 0.95, -8.2), (0.3, 0.25, 0.3), "crate"),
    ((-2.7, DECK_Y + 0.1, 1.6), (0.45, 0.1, 0.45), "rope"),
    ((2.7, DECK_Y + 0.1, 0.6), (0.45, 0.1, 0.45), "rope"),
]
BANANA_BARREL = (1.0, LOWER_Y, 4.6)

CANNON_Z = [-1.2, 3.6]
CANNON_PIVOT_INSET = 1.15
CANNON_STAND_INSET = 2.25
CANNON_HEIGHT = 1.2
BARREL_LENGTH = 2.3


def half_width(z, y):
    t = z / HALF_LENGTH
    plan = 1.0 - 0.92 * max(0.0, -t) ** 2 - 0.25 * max(0.0, t) ** 4
    v = min(1.0, max(0.0, (y - KEEL_Y) / (DECK_Y - KEEL_Y)))
    return 0.5 * BEAM * plan * (0.35 + 0.65 * v ** 0.6)


def rail_top(z, gaps=True):
    if gaps and abs(z - LADDER_Z) < LADDER_GAP:
        return DECK_Y + 0.12
    if z > QUARTER_Z:
        return QUARTER_Y + RAIL_HEIGHT
    t = z / HALF_LENGTH
    return DECK_Y + RAIL_HEIGHT + 0.45 * t * t


def floor_y(z, x):
    if z >= QUARTER_Z:
        return QUARTER_Y
    if z > STAIR_BOTTOM_Z and abs(x) <= STAIR_HALF_WIDTH:
        return DECK_Y + (QUARTER_Y - DECK_Y) * (z - STAIR_BOTTOM_Z) / (QUARTER_Z - STAIR_BOTTOM_Z)
    return DECK_Y


def lower_wall_x(z):
    return half_width(z, LOWER_Y) - WALL_INSET


def sail_post(mast):
    return (1.6, DECK_Y, MAST_Z[mast] + 0.9)


def cannon_side(gun):
    return 1 if gun % 2 == 1 else -1


def cannon_pivot(pair, side):
    z = CANNON_Z[pair]
    return (side * (half_width(z, DECK_Y) - CANNON_PIVOT_INSET), DECK_Y + CANNON_HEIGHT, z)


def cannon_pivot_of(gun):
    return cannon_pivot(gun // 2, cannon_side(gun))


def cannon_count():
    return len(CANNON_Z) * 2


def sails_for(mast):
    """Lower and upper sail per mast: (top height above deck, height, width) as ShipMesh."""
    h = MAST_HEIGHT[mast]
    return [
        (0.55 * h, 0.55 * h - 0.2 * h, 9.0 + mast * 1.0),
        (0.85 * h, 0.85 * h - 0.6 * h - 0.3, 7.0 + mast * 1.0),
    ]


def side_normal(z, y, side):
    """Outward normal of the hull side at (z, y) (Godot axes), for placing things on it."""
    e = 0.01
    dy = (half_width(z, y + e) - half_width(z, y - e)) / (2 * e)
    dz = (half_width(z + e, y) - half_width(z - e, y)) / (2 * e)
    n = (side, -dy, -dz)
    length = math.sqrt(sum(c * c for c in n))
    return tuple(c / length for c in n)
