-- Lunar Lua API v1 中文示例
-- 功能：可配置状态面板、实体计数、玩家方框、F8 快捷开关和持久化设置。

local enabled = lunar.storage.get("enabled", true)
local show_panel = lunar.storage.get("show_panel", true)
local show_boxes = lunar.storage.get("show_boxes", false)
local panel_position = lunar.storage.get("panel_position", 2)
local panel_scale = lunar.storage.get("panel_scale", 1.0)
local accent_color = lunar.storage.get("accent_color", { 0.81, 0.66, 0.70, 1.0 })
local panel_title = lunar.storage.get("panel_title", "Lunar Lua 示例")

local function save_settings()
    lunar.storage.set("enabled", enabled)
    lunar.storage.set("show_panel", show_panel)
    lunar.storage.set("show_boxes", show_boxes)
    lunar.storage.set("panel_position", panel_position)
    lunar.storage.set("panel_scale", panel_scale)
    lunar.storage.set("accent_color", accent_color)
    lunar.storage.set("panel_title", panel_title)
end

local scene_names = {
    unknown = "未知",
    login = "登录界面",
    hall = "大厅",
    loading = "加载中",
    game = "游戏中"
}

local function collect_stats()
    local entities = lunar.game.entities()
    local stats = {
        total = #entities,
        survivors = 0,
        hunters = 0,
        copycats = 0
    }

    for _, entity in ipairs(entities) do
        if entity.kind == "survivor" then
            stats.survivors = stats.survivors + 1
        elseif entity.kind == "hunter" then
            stats.hunters = stats.hunters + 1
        elseif entity.kind == "copycat" then
            stats.copycats = stats.copycats + 1
        end
    end
    return entities, stats
end

local function draw_status_panel(draw, stats)
    local viewport = lunar.game.viewport()
    local scale = panel_scale
    local width = 260 * scale
    local height = 116 * scale
    local margin = 24
    local x = margin
    local y = 48

    if panel_position == 2 then
        x = viewport.width - width - margin
    elseif panel_position == 3 then
        x = (viewport.width - width) * 0.5
    end

    draw.rect_filled(x, y, width, height, { 0.07, 0.07, 0.08, 0.90 }, 7)
    draw.rect(x, y, width, height, { 0.22, 0.22, 0.25, 1.0 }, 1, 7)
    draw.rect_filled(x, y, 4 * scale, height, accent_color, 7)

    local text_x = x + 16 * scale
    draw.text(text_x, y + 12 * scale, panel_title, {
        color = { 0.93, 0.93, 0.94, 1.0 },
        size = 16 * scale,
        shadow = true
    })
    draw.text(text_x, y + 39 * scale,
        "场景：" .. (scene_names[lunar.game.scene()] or lunar.game.scene()), {
            color = { 0.70, 0.70, 0.74, 1.0 },
            size = 13 * scale
        })
    draw.text(text_x, y + 61 * scale,
        string.format("实体：%d  求生者：%d  监管者：%d",
            stats.total, stats.survivors, stats.hunters), {
            color = { 0.82, 0.82, 0.85, 1.0 },
            size = 13 * scale
        })
    draw.text(text_x, y + 86 * scale, "F8：快速显示 / 隐藏", {
        color = accent_color,
        size = 12 * scale
    })
end

local function draw_player_boxes(draw, entities)
    if not show_boxes then return end

    for _, entity in ipairs(entities) do
        local is_player = entity.kind == "survivor"
            or entity.kind == "hunter"
            or entity.kind == "copycat"
        if is_player and not entity.is_self and entity.has_box then
            draw.rect(entity.x, entity.y, entity.width, entity.height,
                accent_color, 1.5, 3)

            local name = entity.player_name
            if name == nil or name == "" then
                name = entity.label or entity.kind
            end
            draw.text(entity.x + entity.width * 0.5, entity.y - 18, name, {
                color = accent_color,
                size = 14,
                outline = true,
                align = "center"
            })
        end
    end
end

return {
    api = 1,
    name = "中文示例脚本",
    version = "1.0.0",

    on_load = function()
        lunar.log.info("中文示例脚本已加载")
    end,

    on_tick = function(_dt)
        if lunar.input.pressed(lunar.keys.f8) then
            enabled = not enabled
            lunar.storage.set("enabled", enabled)
        end
    end,

    on_draw = function(draw)
        if not enabled then return end
        local entities, stats = collect_stats()
        if show_panel then
            draw_status_panel(draw, stats)
        end
        draw_player_boxes(draw, entities)
    end,

    on_event = function(name, payload)
        if name == "scene_changed" then
            lunar.log.info("场景切换：" .. payload.previous .. " -> " .. payload.current)
        end
    end,

    on_unload = function(reason)
        lunar.log.info("中文示例脚本已卸载：" .. reason)
    end,

    tabs = {
        {
            id = "settings",
            title = "示例设置",
            render = function(ui)
                local changed

                enabled, changed = ui.checkbox("enabled", "启用示例脚本", enabled)
                if changed then save_settings() end

                show_panel, changed = ui.checkbox("show_panel", "显示状态面板", show_panel)
                if changed then save_settings() end

                show_boxes, changed = ui.checkbox("show_boxes", "标记其他玩家", show_boxes)
                if changed then save_settings() end

                panel_position, changed = ui.combo("panel_position", "面板位置",
                    panel_position, { "左上角", "右上角", "顶部居中" })
                if changed then save_settings() end

                panel_scale, changed = ui.slider_float("panel_scale", "面板缩放",
                    panel_scale, 0.75, 1.50, "%.2f")
                if changed then save_settings() end

                accent_color, changed = ui.color_edit("accent_color", "强调色", accent_color)
                if changed then save_settings() end

                panel_title, changed = ui.input_text("panel_title", "面板标题", panel_title, 96)
                if changed then save_settings() end

                ui.separator()
                if ui.button("show_toast", "显示测试通知", 130, 28) then
                    ui.toast("Lua UI 和通知工作正常")
                end
                ui.text("关闭菜单后按 F8，可快速显示或隐藏面板。")
            end
        },
        {
            id = "data_preview",
            title = "数据预览",
            render = function(ui)
                local _, stats = collect_stats()
                local viewport = lunar.game.viewport()
                local local_player = lunar.game.local_player()

                ui.text("当前场景：" .. (scene_names[lunar.game.scene()] or lunar.game.scene()))
                ui.text(string.format("视口尺寸：%.0f × %.0f", viewport.width, viewport.height))
                ui.text("实体总数：" .. stats.total)
                ui.text("求生者：" .. stats.survivors .. "    监管者：" .. stats.hunters)
                ui.text("模仿者：" .. stats.copycats)
                ui.separator()

                if local_player then
                    local name = local_player.player_name
                    if name == nil or name == "" then name = "未命名玩家" end
                    ui.text("本地玩家：" .. name)
                    ui.text(string.format("距离参考值：%.1f 米", local_player.distance_m or 0))
                else
                    ui.text("当前未读取到本地玩家数据")
                end
            end
        }
    }
}
