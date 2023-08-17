function vunit(x, y, z)
    d = math.pow(x * x + y * y + z * z, 0.5)
    return x / d, y / d, z / d
end

function lerp(alpha, v1, v2)
    return alpha * v2 + (1 - alpha) * v1
end

function update(frame)
    print('frame #' .. frame)

    local startx, starty, startz
    local endx, endy, endz
    local x, y, z
    local alpha

    if frame < 120 then
        startx, starty, startz = vunit(1.0, 0.0, 0.0)
        endx,   endy,   endz   = vunit(0.0, 0.0, 1.0)
        alpha = frame / 120
    elseif frame < 240 then
        startx, starty, startz = vunit(0.0, 0.0, 1.0)
        endx,   endy,   endz   = vunit(1.0, 0.0, -1.0)
        alpha = (frame - 120) / 120
    elseif frame < 360 then
        startx, starty, startz = vunit(1.0, 0.0, -1.0)
        endx,   endy,   endz   = vunit(0.0, 1.0, 0.0)
        alpha = (frame - 240) / 120
    elseif frame < 480 then
        startx, starty, startz = vunit(0.0, 1.0, 0.0)
        endx,   endy,   endz   = vunit(1.0, 0.0, 0.0)
        alpha = (frame - 360) / 120
    else
        raylee.set_done(true)
        return
    end

    local x = lerp(alpha, startx, endx)
    local y = lerp(alpha, starty, endy)
    local z = lerp(alpha, startz, endz)

    raylee.set_light_direction(x, y, z)
end
