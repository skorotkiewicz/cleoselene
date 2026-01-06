local M = {}

-- Engine Systems (Singleton Instances)
M.db = nil
M.phys = nil
M.nav = nil

-- Game Entities
M.players = {}
M.walls = {}
M.keys = {}
M.asteroids = {}
M.enemies = {}
M.shots = {}
M.spawn_points = {}
M.items = {}
M.particles = {}
M.shards = {}
M.bombs = {}
M.respawn_queue = {} -- Timers for enemy respawn
M.item_respawn_queue = {} -- Timers for natural item respawn

-- Nav & Grid
M.nav_graph = {}
M.nodes_list = {}
M.grid_nodes = {}

-- Lookup
M.entity_map = {}

-- Runtime
M.global_time = 0
M.frame_sounds = {}

return M
