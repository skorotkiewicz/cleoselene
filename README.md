# Game Engine Manual

This document describes the architecture and API of the custom Rust-based Game Engine with Lua scripting.

## Architecture

The engine uses a hybrid architecture:
- **Rust (Host):** Handles High-Performance Physics (SpatialDb), Networking (WebRTC/WebSocket), and Resource Management.
- **Lua (Script):** Handles Game Logic, State Management, and Drawing Commands.

## Lua API (`api` global)

The `api` table is exposed to the Lua environment to interact with the engine.

### Graphics & Sound

| Method | Description |
| :--- | :--- |
| `api.clear_screen(r, g, b)` | Clears the frame with a background color. |
| `api.set_color(r, g, b, [a])` | Sets the current drawing color. |
| `api.fill_rect(x, y, w, h)` | Draws a filled rectangle. |
| `api.draw_line(x1, y1, x2, y2, [width])` | Draws a line. |
| `api.draw_text(text, x, y)` | Draws text at position. |
| `api.load_sound(name, url)` | Preloads a sound from a URL/path. |
| `api.play_sound(name, [loop])` | Plays a loaded sound. |
| `api.stop_sound(name)` | Stops a sound. |
| `api.set_volume(name, volume)` | Sets volume (0.0 to 1.0). |

### Spatial Physics (`SpatialDb`)

The engine provides a high-performance Spatial Hash Grid for collision detection and physics integration.

#### Creation
```lua
local db = api.new_spatial_db(cell_size) -- e.g., 250
```

#### Object Management
| Method | Description | Returns |
| :--- | :--- | :--- |
| `db:add_circle(x, y, radius, tag)` | Registers a circular entity. | `id` (int) |
| `db:add_segment(x1, y1, x2, y2, tag)` | Registers a line segment (wall). | `id` (int) |
| `db:remove(id)` | Removes an entity from the DB. | `nil` |
| `db:update(id, x, y)` | Manually updates position (teleport). | `nil` |

#### Physics & Movement
| Method | Description |
| :--- | :--- |
| `db:set_velocity(id, vx, vy)` | Sets the velocity for automatic integration. |
| `db:get_position(id)` | Returns `x, y` of the entity. |
| `db:step(dt)` | Advances physics simulation by `dt` seconds. Integrates `x += vx * dt`. |

#### Queries (Sensors)
| Method | Description | Returns |
| :--- | :--- | :--- |
| `db:query_range(x, y, r, [tag])` | Finds entity IDs within radius `r`. | `{id1, id2...}` |
| `db:query_rect(x1, y1, x2, y2, [tag])` | Finds entity IDs within AABB (Culling). | `{id1, id2...}` |
| `db:cast_ray(x, y, angle, dist, [tag])` | Casts a ray. | `id, frac, hit_x, hit_y` or `nil` |

## Debugging

The engine supports a remote debug endpoint when started with the `--debug` flag.

### Debug Endpoint (`/debug`)

You can send POST requests with Lua code to `http://localhost:3425/debug`. The code will be executed within the game loop, and the result of the last expression (or a `return` statement) will be returned as text.

**Example using `curl`:**

```bash
# Inspect an enemy state
curl -X POST -d "return State.enemies[1].vx" http://localhost:3425/debug

# Modify state at runtime
curl -X POST -d "State.enemies[1].vx = 500" http://localhost:3425/debug
```

## Testing

The engine includes a headless test mode to verify script integrity without starting a network server.

### Test Mode (`--test`)

Run the engine with the `--test` flag to perform a sanity check on your Lua script.

```bash
cleoselene games/my-game/main.lua --test
```

This will:
1.  Load and parse the Lua script.
2.  Execute the `init()` function.
3.  Execute a single `update(0.1)` cycle.
4.  Exit with code 0 if successful, or code 1 if a runtime error occurs.

## Game Callbacks (Lua)

The Lua script must implement these functions:

```lua
function init() 
    -- Called once on startup
end

function update(dt)
    -- Called every frame (30fps)
    -- Update game logic here
end

function draw(session_id)
    -- Called for EACH client connected
    -- Issue drawing commands here
end

function on_connect(session_id)
    -- Called when a new player joins
end

function on_disconnect(session_id)
    -- Called when a player leaves
end

function on_input(session_id, key_code, is_down)
    -- Called on input events
end
```
