function update(frame)
    local startx = 0
    local starty = 0
    local startz = -1

    local endx = 2
    local endy = 2
    local endz = -1

    local alpha = frame / 300

    local x = (1 - alpha) * startx + alpha * endx
    local y = (1 - alpha) * starty + alpha * endy
    local z = (1 - alpha) * startz + alpha * endz

    raylee.set_camera_position(x, y, z)
    raylee.set_done(frame >= 300)
end

print('running scripts/move_camera')
update(0)
