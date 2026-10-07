class_name GameConfig
extends RefCounted
## Game-wide numbers shared by client and server.

const VERSION := "0.1.0"
const DEFAULT_PORT := 24565
const MAX_PLAYERS := 4

## Snapshots per second from the server, and player updates per second from clients.
const SNAPSHOT_RATE := 30.0
const PLAYER_SEND_RATE := 30.0

## Remote things are drawn this far in the past so there are always two snapshots to blend.
const RENDER_DELAY := 0.1

## Swim further than this from your ship and the menu offers a respawn on deck.
const RESPAWN_DISTANCE := 500.0
