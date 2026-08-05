local enabled = lunar.storage.get("enabled", true)
local box_color = lunar.storage.get("box_color", { 1.0, 0.35, 0.55, 1.0 })

local function save()
    lunar.storage.set("enabled", enabled)
    lunar.storage.set("box_color", box_color)
end

return {
    api = 1,
    name = "Example overlay",
    version = "1.0.0",

    on_load = function()
        lunar.log.info("example overlay loaded")
    end,

    on_tick = function()
        if lunar.input.pressed(lunar.keys.f8) then
            enabled = not enabled
            lunar.storage.set("enabled", enabled)
        end
    end,

    on_draw = function(draw)
        if not enabled then return end
        for _, entity in ipairs(lunar.game.entities("survivor")) do
            if not entity.is_self and entity.has_box then
                draw.rect(entity.x, entity.y, entity.width, entity.height,
                    box_color, 1.5, 3.0)
                draw.text(entity.x + entity.width * 0.5, entity.y - 18,
                    entity.player_name ~= "" and entity.player_name or entity.label,
                    { color = box_color, size = 15, outline = true, align = "center" })
            end
        end
    end,

    on_event = function(name, payload)
        if name == "scene_changed" then
            lunar.log.info("scene: " .. payload.previous .. " -> " .. payload.current)
        end
    end,

    on_unload = function(reason)
        lunar.log.info("unloaded: " .. reason)
    end,

    tabs = {
        {
            id = "settings",
            title = "Example",
            render = function(ui)
                local changed
                enabled, changed = ui.checkbox("enabled", "Enable overlay", enabled)
                if changed then save() end

                box_color, changed = ui.color_edit("box_color", "Box color", box_color)
                if changed then save() end

                ui.separator()
                ui.text("F8 toggles this overlay while the menu is closed.")
            end
        }
    }
}
