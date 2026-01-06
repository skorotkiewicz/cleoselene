-- Test Suite for Astro Maze
-- Usage: cleoselene games/astro-maze/run_tests.lua --test

local State = require("state")
local Entities = require("entities")
local Utils = require("utils")
local Main = require("main") -- Loads globals like update(), on_connect()

-- --- MOCKS ---
-- We mock the API only if it's not present (standalone Lua), 
-- OR we force mocks because we want to test GAME LOGIC in isolation, not engine physics.
-- For unit tests, mocks are better than real engine because we control the output.

local mock_db = {
    add_circle = function() return 1 end,
    add_segment = function() return 2 end,
    remove = function() end,
    update = function() end,
    query_range = function() return {} end,
    cast_ray = function() return nil end,
    get_position = function() return 0,0 end
}
local mock_nav = {
    add_node = function() end,
    add_edge = function() end,
    find_path = function() return {1, 2} end
}
local mock_phys = {
    add_body = function() end,
    set_velocity = function() end,
    step = function() end
}

-- If running inside engine, we overwrite the global API for the duration of tests
-- or we just inject these mocks into State directly.
-- Injecting into State is safer and what the game logic uses.

State.db = mock_db
State.phys = mock_phys
State.nav = mock_nav
State.nodes_list = {[1]={x=0,y=0}, [2]={x=100,y=100}}

-- --- HELPERS ---
local function assert_true(cond, msg)
    if not cond then
        local err = "FAILED: " .. msg
        print(err)
        error(err)
    else
        print("PASS: " .. msg)
    end
end

-- --- TESTS ---

local function Test_EnemyChase()
    print("\n--- Test_EnemyChase ---")
    State.players = {}
    State.enemies = {}
    
    local p = {
        id="p1", x=0, y=0, vx=0, vy=0, radius=12, angle=0,
        keys={}, inputs={}, hp=100, active_ability="laser",
        last_shot_timer=2, damage_timer=0, shake_timer=0, blink_timer=0,
        color={r=255,g=255,b=255}
    }
    State.players["p1"] = p
    
    local e = {
        x=200, y=200, vx=0, vy=0, radius=22, active=true, 
        chase_cooldown=0, target_p=p,
        spin=0, spin_speed=2, noise_timer=10
    }
    table.insert(State.enemies, e)
    
    -- Mock has_line_of_sight via db:cast_ray returning nil (default mock)
    
    update(0.1)
    
    local moved = (math.abs(e.vx) > 0 or math.abs(e.vy) > 0)
    assert_true(moved, "Enemy should have velocity towards player")
    if moved then
        print("   VX: " .. e.vx .. " VY: " .. e.vy)
    end
end

local function Test_NaturalItemRespawn()
    print("\n--- Test_NaturalItemRespawn ---")
    State.items = {}
    State.item_respawn_queue = {}
    
    local item = {x=100, y=100, type="health", taken=false, natural=true}
    table.insert(State.items, item)
    
    Entities.pickup_item(item)
    
    assert_true(item.taken, "Item should be marked taken")
    assert_true(#State.item_respawn_queue == 1, "Should queue respawn")
    
    -- Simulate Timer Expiry
    State.item_respawn_queue[1].timer = -0.1
    
    update(0.1)
    
    assert_true(#State.items == 2, "New item should be spawned after timer")
    local new_item = State.items[2]
    assert_true(new_item.natural == true, "Respawned item should be natural")
    assert_true(new_item.taken == false, "Respawned item should not be taken")
end

local function Test_EnemyKillRespawn()
    print("\n--- Test_EnemyKillRespawn ---")
    State.enemies = {}
    State.respawn_queue = {}
    State.spawn_points = {{x=1000, y=1000}}
    State.players = {["p1"]={
        id="p1", x=0, y=0, vx=0, vy=0, radius=12, angle=0,
        keys={}, inputs={}, hp=100, active_ability="laser",
        last_shot_timer=2, damage_timer=0, shake_timer=0, blink_timer=0,
        color={r=255,g=255,b=255}
    }}
    
    local e = {x=50, y=50, vx=0, vy=0, active=true, owner_p=nil}
    table.insert(State.enemies, e)
    
    Entities.kill_enemy(e)
    
    assert_true(e.active == false, "Enemy should be inactive")
    assert_true(#State.respawn_queue == 1, "Should queue enemy respawn")
    
    State.respawn_queue[1].timer = -0.1
    local old_enemy_count = #State.enemies
    update(0.1)
    
    assert_true(#State.enemies == old_enemy_count + 1, "New enemy should be spawned")
end

-- --- ENGINE ENTRY POINT ---

function init()
    print("Running Test Suite...")
    Test_EnemyChase()
    Test_NaturalItemRespawn()
    Test_EnemyKillRespawn()
    print("\nALL TESTS PASSED")
end

-- If running standalone (CLI lua), run init manually
if not api then
    -- Mock API for standalone execution
    _G.api = {
        new_spatial_db = function() return mock_db end,
        new_physics_world = function() return mock_phys end,
        new_graph = function() return mock_nav end,
        play_sound = function() end,
        load_sound = function() end,
        set_volume = function() end,
        clear_screen = function() end,
        set_color = function() end,
        draw_line = function() end,
        fill_rect = function() end,
        draw_text = function() end
    }
    init()
end
