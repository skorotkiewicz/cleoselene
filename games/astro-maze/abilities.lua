local Config = require("config")
local State = require("state")
local Utils = require("utils")
local Entities = require("entities")

local M = {}
local insert = table.insert
local random = math.random
local cos, sin = math.cos, math.sin
local pi = math.pi

function M.fire_laser(p)
    Utils.play_sound_at("laser", p.x, p.y)
    local rad = p.angle * (pi/180)
    
    -- Recoil
    local recoil = 80
    p.vx = p.vx - cos(rad) * recoil
    p.vy = p.vy - sin(rad) * recoil

    local sx, sy = p.x + cos(rad) * 35, p.y + sin(rad) * 35
    
    local hx, hy, obj = Utils.cast_ray(sx, sy, p.angle, p.id)
    
    insert(State.shots, {x1=sx, y1=sy, x2=hx, y2=hy, life=0.5})
    
    if obj then 
        if obj == p then return end
        if obj.inputs then -- Player
            obj.hp = obj.hp - 25
            obj.damage_timer = 0.3
            if obj.hp <= 0 then Entities.respawn_player(obj) end 
        elseif obj.active then -- Enemy
            Entities.kill_enemy(obj)
        end 
    end
end

function M.activate_dash(p)
    p.is_dashing = true
    p.dash_timer = 0.25
    local rad = p.angle * (pi/180)
    p.vx = p.vx + cos(rad) * 650
    p.vy = p.vy + sin(rad) * 650
    Utils.play_sound_at("dash", p.x, p.y)
    
    for i=1, 8 do 
        insert(State.particles, {
            x=p.x, y=p.y, 
            angle=p.angle + 3.14 + (random()-0.5), 
            life=0.6, max_life=0.6, size_factor=1.5
        }) 
    end
end

function M.spawn_bomb(p)
    Utils.play_sound_at("laser-ready", p.x, p.y)
    local b = {
        x=p.x, y=p.y, vx=p.vx, vy=p.vy, 
        radius=8, timer=2.5, max_timer=2.5, 
        owner_id=p.id, color={r=255, g=255, b=255}
    }
    insert(State.bombs, b)
    Entities.register(b, "circle", b.radius, "bomb")
end

function M.spawn_minion(p)
    Utils.play_sound_at("minion", p.x, p.y)
    local e = {
        x=p.x, y=p.y, vx=p.vx, vy=p.vy, 
        radius=20, active=true, points=6, spin=0, spin_speed=4, 
        owner_p=p, color=p.color,
        waiting_separation = true
    }
    insert(State.enemies, e)
    Entities.register(e, "circle", e.radius, "enemy")
end

return M
