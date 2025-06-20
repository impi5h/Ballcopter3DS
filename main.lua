local imgLogo = love.graphics.newImage("logo.png") -- 258 x 61
local imgGameOver = love.graphics.newImage("gameOver.png") -- 271 x 67
local imgBall = love.graphics.newImage("ball.png") -- 32 x 32
local imgShaft = love.graphics.newImage("shaft.png") -- 4 x 5
local albFace = {                                     -- 10 x 15
    love.graphics.newImage("0w0.png"),
    love.graphics.newImage("^w^.png"),
    love.graphics.newImage("DX.png")
}
local albCopter = {                                   -- 32 x 6
    love.graphics.newImage("copter1.png"),
    love.graphics.newImage("copter2.png"),
    love.graphics.newImage("copter3.png"),
    love.graphics.newImage("copter4.png"),
    love.graphics.newImage("copter5.png"),
    love.graphics.newImage("copter6.png"),
}
local font = love.graphics.newFont("Nunito-ExtraBold.ttf", 110)
local fontSmall = love.graphics.newFont ("Nunito-ExtraBold.ttf", 30)

local sfxJump = love.audio.newSource("Retro Jump Classic 08.wav", "static")
sfxJump:setVolume(0.3)
local sfxScore = love.audio.newSource("Retro PickUp Coin 04.wav", "static")
sfxScore:setVolume(0.3)
local sfxHit = love.audio.newSource("Retro FootStep Krushed Landing 01.wav", "static")
sfxHit:setVolume(0.3)

local palette = {
    blue = {
        top = {0.4, 1, 1},
        front = {0.3, 0.8, 1},
        side = {0.1, 0.6, 0.9},
        bottom = {0, 0.4, 0.8},
    },
    gold = {
        top = {1, 1, 0.8},
        front = {1, 0.8, 0.3},
        side = {0.9, 0.6, 0.1},
        bottom = {0.8, 0.4, 0},
    }
}

local ds = love.joystick.getJoysticks()[1]

local player = {}

local world = {
    speed = 60,
}

local walls = {}

local score
local hiScore
local newRecord
local eraseTime
local scoreErased
local idleCycle
local floor
local deadPan
local deathTime
local gameOver

local taps = {}
local rng


function love.load()
    reStart()
    love.graphics.setBackgroundColor(0, 0.1, 0.2)
    if love.filesystem.getInfo("hiScore") then
        hiScore = tonumber(love.filesystem.read("hiScore"), 10)
    else
        hiScore = 0
    end
end

function love.update(dt)
    if dt >= 1 then
        return
    end

    for id, tap in pairs(taps) do
        tap.t = tap.t + (dt * 50)
        if tap.t >= 50 then
            taps[id] = nil
        end
    end

    if player.state ~= "dead" then
        world.distance = world.distance + (dt * world.speed)
    end

    if #walls ~= 0 and (walls[walls.nxt].bottom.x >= player.x - 48 and walls[walls.nxt].bottom.x <= player.x) then
        floor = walls[walls.nxt].bottom.y
    else
        floor = 226
    end

    if player.state == "idle" then
        idleCycle = idleCycle + (dt * 2 * math.pi)
        if idleCycle >= 2 * math.pi then
            idleCycle = idleCycle - (2 * math.pi)
        end
        player.y = 120 + (math.sin(idleCycle) * 5)
        player.copter = math.floor(idleCycle / (math.pi / 3) + 1)

        if world.distance >= 48 then
            world.distance = world.distance - 48
        end

        if hiScore ~= 0 and ds:isGamepadDown("leftshoulder") and ds:isGamepadDown("rightshoulder") then
            eraseTime = eraseTime + dt
            if eraseTime >= 1 then
                hiScore = 0
                love.filesystem.write("hiScore", 0)
                scoreErased = true
            end
        end
    else
        if player.y >= floor - 17 then
            if player.state ~= "dead" then
                death()
            end
            if not gameOver and player.state == "dead" then
                love.audio.play(sfxHit)
                gameOver = true
            end
            player.vy = 0
        else
            player.y = player.y + player.vy * 144 *dt
            player.vy = player.vy + (3.5 * dt)
        end
        if player.copterSpin ~= 0 then
            player.copterTime = player.copterTime + dt
            if player.copterTime >= (1/30) then
                 player.copterTime = player.copterTime - (1/30)
                 if player.copter == 6 then
                    player.copter = 1
                    player.copterSpin = player.copterSpin - 1
                 else
                    player.copter = player.copter + 1
                 end
            end
        end
        if player.x < 100 and player.state ~= "dead" then
            if player.x >= 99.5 then
                player.x = 100
            else
                player.x = player.x + (10 - player.x / 10) * dt * 50
            end
        end

        if player.state == "active" then
            for i = 1, 4 do
                walls[i].top.x = walls[i].top.x - (dt * world.speed)
                walls[i].bottom.x = walls[i].top.x
            end
            if walls[walls.nxt].top.scored == false and walls[walls.nxt].top.x <= 76 then
                score = score + 1
                love.audio.play(sfxScore)
                walls[walls.nxt].top.scored = true
            end
            if walls.nxt == 1 and score == 1 and walls[1].top.x <= 36 then
                walls.nxt = 2
            end
            if walls[1].top.x <= -96 then
                table.remove(walls, 1)
                table.insert(walls, wallGen())
            end
            if (collide(walls[walls.nxt].top) or collide(walls[walls.nxt].bottom) or player.y <= 29) and player.state ~= "dead" then
                death()
                player.vy = 0.01
            end
        end

        if player.state == "dead" then
            if deathTime <= 0.5 then
                deathTime = deathTime + dt
            end
            if player.vy == 0 and world.distance < deadPan then
                local vx =  (deadPan - world.distance) * dt * 10
                world.distance = world.distance + vx
                player.x = player.x - vx
                for i = 1, 4 do
                    walls[i].top.x = walls[i].top.x - vx
                    walls[i].bottom.x = walls[i].top.x
                end
            end
        end
    end
end

function love.touchpressed(id, x, y)
    taps[#taps + 1] = {x = x, y = y, t = 0}
    if player.state == "idle" then
        player.state = "active"
        rng:setSeed(math.floor(world.distance * 10) + x + y)
        for i = 1, 4 do
            table.insert(walls, wallGen())
        end
    end
    if player.state ~= "dead" then
        if player.y >= floor - 17 then
            player.y = floor - 17.01
        end
        player.vy = -1
        player.copterSpin = 2
        if sfxJump:isPlaying() then
            love.audio.stop(sfxJump)
        end
        love.audio.play(sfxJump)
    elseif gameOver == true and deathTime >= 0.5 then
        reStart()
    end
end

function love.gamepadreleased(j, b)
    if b == "leftshoulder" or b == "rightshoulder" then
        eraseTime = 0
    end
end

function love.draw(screen)
    if screen == "bottom" then
        for id, tap in pairs(taps) do
            love.graphics.setColor(0.5, 1, 1, 1 - (tap.t / 50))
            love.graphics.circle("fill", tap.x, tap.y, tap.t * 1.5)
        end
        love.graphics.setColor(0.5, 1, 1)
        local string = score
        if player.state == "idle" then
            string = "Tap!"
        elseif gameOver == true then
            string = "Retry?"
        end
        local string2 = "Hold L + R to reset high score"
        if scoreErased then
            string2 = "High score reset successfully."
        end
        love.graphics.printf(string, font, 0, 64, 320, "center")
        if player.state == "idle" and (hiScore > 0 or scoreErased) then
            love.graphics.printf(string2, fontSmall, 0, 160, 320, "center")
        end
    else
        local depth = love.graphics.getDepth()
        if screen == "right" then
            depth = -depth
        end
        local mid = depth * 2.5
        local far = depth * 22
        local cntr = {x = 200 - far, y = 120}
        local p3d = math.floor(player.x - mid)
        local ceilingTrick = player.y <= 40
        love.graphics.setColor(palette.blue.top)
        love.graphics.rectangle("fill", 0, 215, 400, 25)
        love.graphics.setColor(palette.blue.bottom)
        if ceilingTrick then
            love.graphics.rectangle("fill", 0, 0, player.x - 16, 25)
            love.graphics.rectangle("fill", player.x + 16, 0, 400, 25)
            love.graphics.rectangle("fill", player.x - 16, 13, player.x + 16, 12)
        else
            love.graphics.rectangle ("fill", 0, 0, 400, 25)
        end
        drawWorld2("bg", cntr, mid, farW)
        drawShadow(floor, p3d)
        --draw player
        love.graphics.setColor(player.color)
        love.graphics.draw(imgBall, p3d - 16, player.y - 16)
        love.graphics.draw(albCopter[player.copter], p3d - 16, player.y - 27)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(imgShaft, p3d - 2, player.y - 21)
        love.graphics.draw(albFace[player.face], p3d + 3, player.y - 6)
        if ceilingTrick then
            love.graphics.setColor(palette.blue.bottom)
            love.graphics.rectangle("fill", player.x - 16, 0, player.x + 16, 13)
        end
        drawWorld2("fg", cntr, mid, farW)
        if player.state == "idle" then
            love.graphics.setColor(1,1,1)
            love.graphics.draw(imgLogo, 120 + depth, 90)
        elseif gameOver == true then
            love.graphics.setColor(1,1,1)
            love.graphics.draw(imgGameOver, 114 + depth, 30)
            love.graphics.print("Score: "..score, fontSmall, 200 + depth, 120)
            love.graphics.print("High Score: "..hiScore, fontSmall, 200 + depth, 140)
            if newRecord then
                love.graphics.setColor({1, 0.1, 0.25})
                love.graphics.print("New Record!!!", fontSmall, 200 + depth, 160)
            end
        end
    end
end

-- CUSTOM FUNCTIONS

function reStart()
    player.x = 70
    player.y = 120
    player.vx = 0
    player.vy = 0
    player.color = {1, 0.1, 0.25}
    player.face = 1
    player.copter = 1
    player.copterSpin = 0
    player.copterTime = 0
    player.state = "idle"

    world.distance = 0

    walls = {}
    walls.nxt = 1

    score = 0
    newRecord = false
    eraseTime = 0
    scoreErased = false
    idleCycle = 0
    deadPan = 0
    deathTime = 0
    gameOver = false

    taps = {}
    rng = love.math.newRandomGenerator(0)
end

function wallGen()
    local height = rng:random(40, 140)
    local x
    if #walls == 0 then
        x = 456 - world.distance
    else
        x = walls[#walls].top.x + 144
    end
    r = {
        top = {
            x = x,
            y = 13,
            w = 48,
            h = height - 13,
            scored = false
        },
        bottom = {
            x = x,
            y = height + 60,
            w = 48,
            h = 167 - height,
        },
    }
    if score % 10 == 7 then
        r.top.pal = palette.gold
        r.bottom.pal = palette.gold
    else
        r.top.pal = palette.blue
        r.bottom.pal = palette.blue
    end
    return r
end

function collide(rectangle)
    local p = {
        x = math.min(math.max(player.x, rectangle.x), rectangle.x + rectangle.w),
        y = math.min(math.max(player.y, rectangle.y), rectangle.y + rectangle.h)
    }
    return math.abs(player.x - p.x) <= 15 and math.abs(player.y - p.y) <= 15
end

function death()
    player.state = "dead"
    player.color = {0.8, 0.8, 0.8}
    player.face = 3
    love.audio.play(sfxHit)
    deadPan = world.distance + 30
    if score > hiScore then
        hiScore = score
        newRecord = true
        love.filesystem.write("hiScore", hiScore)
    end
end

function singlePoint(p1, p2, length)
    return p1 + ((p2 - p1) / length)
end

function drawShadow(height, x)
    if height <= 120 then
        return
    end
    local ph = player.y / height
    local w = (height - 120) / 10.6
    love.graphics.setColor(0, 0.1, 0.2, ph * 0.75)
    love.graphics.ellipse("fill", x, height, 20 * ph, w * ph)
end

function drawWorld2(type, cntr, mid, far)
    for i = 1, #walls do
        for key, val in pairs(walls[i]) do
            local nuX = val.x - mid
            local x = nuX
            local y = val.y
            local palY
            if x <= cntr.x then
                x = x + val.w
            end
            if y <= cntr.y then
                y = y + val.h
                if y >= cntr.y then
                    palY = {0,0,0,0}
                else
                    palY = val.pal.bottom
                end
            else
                palY = val.pal.top
            end
            if i == walls.nxt then                      -- complex wall
                if type == "bg" then
                    love.graphics.setColor(val.pal.side)
                    love.graphics.polygon("fill", {
                        singlePoint(x, cntr.x, 9), singlePoint(val.y, cntr.y, 9),
                        singlePoint(x, cntr.x, 9), singlePoint(val.y + val.h, cntr.y, 9),
                        x, val.y + val.h,
                        x, val.y,
                    })
                    love.graphics.setColor(palY)
                    if key == "bottom" and player.y <= y and nuX <= 120 then
                        love.graphics.polygon("fill", {
                            singlePoint(nuX, cntr.x, -8), singlePoint(y, cntr.y, -8),
                            singlePoint(nuX + val.w, cntr.x, -8), singlePoint(y, cntr.y, -8),
                            singlePoint(nuX + val.w, cntr.x, 9), singlePoint(y, cntr.y, 9),
                            singlePoint(nuX, cntr.x, 9), singlePoint(y, cntr.y, 9),
                        })
                    else
                        love.graphics.polygon("fill", {
                            nuX, y,
                            nuX + val.w, y,
                            singlePoint(nuX + val.w, cntr.x, 9), singlePoint(y, cntr.y, 9),
                            singlePoint(nuX, cntr.x, 9), singlePoint(y, cntr.y, 9),
                        })
                    end
                else
                    love.graphics.setColor(val.pal.side)
                    love.graphics.polygon("fill", {
                        singlePoint(x, cntr.x, -8), singlePoint(val.y, cntr.y, -8),
                        singlePoint(x, cntr.x, -8), singlePoint(val.y + val.h, cntr.y, -8),
                        x, val.y + val.h,
                        x, val.y,
                    })
                    if key == "top" or (key == "bottom" and (player.y > y or nuX > 120))then
                        love.graphics.setColor(palY)
                        love.graphics.polygon("fill", {
                            nuX, y,
                            nuX + val.w, y,
                            singlePoint(nuX + val.w, cntr.x, -8), singlePoint(y, cntr.y, -8),
                            singlePoint(nuX, cntr.x, -8), singlePoint(y, cntr.y, -8),
                        })
                    end
                end                
            else                                        -- simple wall
                if type == "bg" then
                    love.graphics.setColor(val.pal.side)
                    love.graphics.polygon("fill", {
                        singlePoint(x, cntr.x, 9), singlePoint(val.y, cntr.y, 9),
                        singlePoint(x, cntr.x, 9), singlePoint(val.y + val.h, cntr.y, 9),
                        singlePoint(x, cntr.x, -8), singlePoint(val.y + val.h, cntr.y, -8),
                        singlePoint(x, cntr.x, -8), singlePoint(val.y, cntr.y, -8),
                    })
                    love.graphics.setColor(palY)
                    love.graphics.polygon("fill", {
                        singlePoint(nuX, cntr.x, -8), singlePoint(y, cntr.y, -8),
                        singlePoint(nuX + val.w, cntr.x, -8), singlePoint(y, cntr.y, -8),
                        singlePoint(nuX + val.w, cntr.x, 9), singlePoint(y, cntr.y, 9),
                        singlePoint(nuX, cntr.x, 9), singlePoint(y, cntr.y, 9),
                    })
                end
            end
            if type == "fg" then
                love.graphics.setColor(val.pal.front)
                love.graphics.rectangle("fill", singlePoint(nuX, cntr.x, -8), singlePoint(val.y, cntr.y, -8), 54, val.h * 1.125)
            end
        end
    end
end