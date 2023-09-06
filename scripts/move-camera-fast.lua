function update(frame)
    local startx = 0
    local starty = 0
    local startz = 0

    local endx = 10
    local endy = 0
    local endz = 0

    local alpha = frame / 10

    local x = (1 - alpha) * startx + alpha * endx
    local y = (1 - alpha) * starty + alpha * endy
    local z = (1 - alpha) * startz + alpha * endz

    raylee.set_camera_position(x, y, z)
    raylee.set_done(frame >= 10)
end
