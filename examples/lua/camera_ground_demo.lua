local last_camera = nil
local last_hit = nil

return {
    api = 1,
    requires = {
        "game.camera",
        "game.ground_raycast",
        "game.project",
        "draw.circle",
        "draw.text"
    },
    name = "镜头与地面射线",
    version = "1.0.0",

    on_tick = function()
        last_camera = lunar.game.camera()
    end,

    on_draw = function(draw)
        last_hit = lunar.game.ground_raycast()

        if last_camera and last_camera.valid then
            local d = last_camera.direction
            draw.text(24, 24, string.format("镜头方向  %.3f  %.3f  %.3f", d.x, d.y, d.z), {
                color = { 0.82, 0.68, 0.72, 1.0 },
                size = 15,
                outline = true
            })
        end

        if not last_hit or not last_hit.hit then return end
        local projected = lunar.game.project({ last_hit.position })
        local point = projected[1]
        if not point or not point.visible then return end

        local color = last_hit.is_ground
            and { 0.35, 0.90, 0.62, 1.0 }
            or { 0.95, 0.62, 0.35, 1.0 }
        draw.circle(point.x, point.y, 7, color, 2.0, 24)
        draw.text(point.x, point.y + 11,
            string.format("%.1f", last_hit.distance), {
                color = color,
                size = 13,
                outline = true,
                align = "center"
            })
    end
}
