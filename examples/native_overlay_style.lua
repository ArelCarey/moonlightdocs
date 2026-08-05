local enabled = lunar.storage.get("native_style_enabled", true)
local accent = lunar.storage.get("native_style_accent", { 0.25, 0.82, 1.0, 1.0 })

local function save()
    lunar.storage.set("native_style_enabled", enabled)
    lunar.storage.set("native_style_accent", accent)
end

return {
    api = 1,
    name = "Native overlay style",
    version = "1.0.0",

    -- This processor receives only the native in-game ESP/HUD command model.
    -- Lunar's main menu and script manager never enter this pipeline.
    native_overlay = {
        priority = 100,
        process = function(frame)
            if not enabled then return end

            for _, element in ipairs(frame.elements) do
                if element.tag == "esp.player.box" then
                    element.style.color = accent
                    element.style.thickness = 2.5
                    element.style.rounding = 5.0
                elseif element.tag == "esp.player.label" and element.primitive == "text" then
                    element.text = "[LUA] " .. element.text
                    element.style.color = accent
                    element.style.font_size = 17.0
                    element.style.outline = true
                    element.style.outline_size = 1.5
                elseif element.tag == "esp.player.progress" then
                    element.visible = false
                end
            end
        end
    },

    tabs = {
        {
            id = "native_style",
            title = "Native style",
            render = function(ui)
                local changed
                enabled, changed = ui.checkbox("enabled", "Process native game overlay", enabled)
                if changed then save() end

                accent, changed = ui.color_edit("accent", "Accent color", accent)
                if changed then save() end

                ui.separator()
                ui.text("The Lunar main menu is always rendered by the native client.")
            end
        }
    }
}
