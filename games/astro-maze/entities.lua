local Config = require("config")
local State = require("state")
local Utils = require("utils")
local M = {}

local random = math.random
local insert = table.insert
local floor = math.floor
local pairs = pairs
local ipairs = ipairs

function M.register(obj, kind, ...)
    local id
    if kind == "circle" then id = State.db:add_circle(obj.x, obj.y, ... )
    elseif kind == "segment" then id = State.db:add_segment(obj.x1, obj.y1, ... ) end
    obj.phys_id = id
    State.entity_map[id] = obj
    return id
end

function M.unregister(obj)
    if obj.phys_id then
        State.db:remove(obj.phys_id)
        State.entity_map[obj.phys_id] = nil
        obj.phys_id = nil
    end
end

function M.get_smart_spawn()
    local t = {}
    for _, p in pairs(State.players) do insert(t, p) end
    
    if #t == 0 then
        if #State.spawn_points > 0 then return State.spawn_points[random(#State.spawn_points)] end
        return {x=0, y=0}
    end
    
    local tgt = t[random(#t)]
    local sn = Utils.get_closest_node(tgt.x, tgt.y)
    
    if not sn or not State.nav_graph[sn] then
        return State.spawn_points[random(#State.spawn_points)]
    end
    
    -- BFS to find node at distance ~3
    local q = { {id=sn, d=0} }
    local v = {[sn]=true}
    local head = 1
    local cands = {}
    
    while head <= #q do
        local curr = q[head]
        head = head + 1
        insert(cands, State.nodes_list[curr.id])
        if curr.d < 3 then 
            local nb = State.nav_graph[curr.id]
            if nb then
                for _, n in ipairs(nb) do
                    if not v[n] then
                        v[n] = true
                        insert(q, {id=n, d=curr.d+1})
                    end
                end
            end
        end
    end
    
    if #cands > 0 then return cands[random(#cands)] end
    return State.spawn_points[random(#State.spawn_points)]
end

function M.spawn_explosion(x, y, vx, vy, color)
    local pts = 20
    local r = 15
    local pi2 = math.pi * 2
    local last_x, last_y
    
    for i=0, pts do
        local a = (i/pts) * pi2
        local cx, s = math.cos(a), math.sin(a)
        local px, py = x + cx*r, y + s*r
        
        if i > 0 then
            local mx, my = (last_x+px)/2, (last_y+py)/2
            local dx, dy = mx-x, my-y
            local d = math.sqrt(dx*dx + dy*dy)
            local ndx, ndy = dx/d, dy/d
            local rc, rs = math.cos((random()-0.5)*0.5), math.sin((random()-0.5)*0.5)
            local svx = vx + (ndx*rc - ndy*rs) * random(5, 25)
            local svy = vy + (ndx*rs + ndy*rc) * random(5, 25)
            
            insert(State.shards, {
                x1=last_x-mx, y1=last_y-my,
                x2=px-mx, y2=py-my,
                cx=mx, cy=my,
                vx=svx, vy=svy,
                spin=(random()-0.5)*10,
                angle=0,
                life=0.8,
                max_life=0.8,
                color=color
            })
        end
        last_x, last_y = px, py
    end
end

function M.respawn_player(p)
    Utils.play_sound_at("die", p.x, p.y)
    Utils.play_sound_at("start", p.x, p.y)
    M.spawn_explosion(p.x, p.y, p.vx, p.vy, {r=p.color.r, g=p.color.g, b=p.color.b})
    
    -- Cleanup owned minions
    for _, e in ipairs(State.enemies) do
        if e.active and e.owner_p == p then
            e.active = false
            M.unregister(e)
            M.spawn_explosion(e.x, e.y, e.vx, e.vy, e.color)
        end
    end

    p.hp = 100
    p.vx = 0
    p.vy = 0
    p.keys = {}
    p.last_shot_timer = 2.0
    p.active_ability = "laser"
    
    local sp = M.get_smart_spawn()
    p.x, p.y = sp.x, sp.y
    if p.phys_id then State.db:update(p.phys_id, p.x, p.y) end
end

function M.spawn_enemy_at(x, y)
    local e = {
        x=x, y=y, vx=0, vy=0, 
        radius=22, active=true, points=random(5,10), 
        spin=0, spin_speed=2, path_timer=0,
        noise_timer = random(3, 15) -- Random initial delay
    }
    insert(State.enemies, e)
    M.register(e, "circle", e.radius, "enemy")
    return e
end

function M.get_safe_spawn_point()
    local attempts = 10
    local safe_dist_sq = 1000 * 1000 -- 1000px safe distance
    
    for i=1, attempts do
        local sp = State.spawn_points[random(#State.spawn_points)]
        local safe = true
        for _, p in pairs(State.players) do
            if Utils.dist_sq(p.x, p.y, sp.x, sp.y) < safe_dist_sq then
                safe = false
                break
            end
        end
        if safe then return sp end
    end
    -- Fallback
    return State.spawn_points[random(#State.spawn_points)]
end

function M.spawn_random_item_at(x, y)
    local itype = Config.ITEM_KEYS[random(#Config.ITEM_KEYS)]
    -- Natural items (not dropped)
    insert(State.items, {x=x, y=y, type=itype, taken=false, natural=true})
end

function M.pickup_item(it)
    it.taken = true
    Utils.play_sound_at("health-up", it.x, it.y)
    
    if it.natural then
        -- Schedule respawn
        insert(State.item_respawn_queue, {
            x = it.x, 
            y = it.y, 
            timer = 10.0 -- 10s respawn for items
        })
    end
end

function M.kill_enemy(e)
    if not e.active then return end
    e.active = false
    M.unregister(e)
    
    Utils.play_sound_at("enemy-die", e.x, e.y)
    M.spawn_explosion(e.x, e.y, e.vx, e.vy, e.color or {r=255, g=100, b=0})
    
    -- Drop Logic (40% chance)
    -- Don't drop items from player-owned minions to prevent farming exploits
    if not e.owner_p then
        if random() < 0.4 then
            local itype = Config.ITEM_KEYS[random(#Config.ITEM_KEYS)]
            -- Dropped items are NOT natural, so they won't respawn
            insert(State.items, {x = e.x, y = e.y, type = itype, taken = false, natural = false})
        end
        
        -- Schedule Respawn for natural enemies
        insert(State.respawn_queue, {timer = 5.0}) -- 5 seconds respawn
    end
end

return M
