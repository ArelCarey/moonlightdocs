-- Lunar Lua API v1
-- 疯眼自定义放墙：Lua 负责筛选、预测、方向与高度，宿主只提交一段精确墙线。
local enabled = lunar.storage.get("enabled", false)
local prediction = lunar.storage.get("prediction", 0.55)
local half_length = lunar.storage.get("half_length", 3.0)
local height_offset = lunar.storage.get("height_offset", 0.0)
local height_slope = lunar.storage.get("height_slope", 0.0)
local console_range = lunar.storage.get("console_range", 480.0)
local cooldown_ms = lunar.storage.get("cooldown_ms", 650)
local exit_after = lunar.storage.get("exit_after", true)

local last_place_ms = 0
local last_status = "等待启用"
local preview_start = nil
local preview_finish = nil
local disabled_builtin = false

local function save()
    lunar.storage.set("enabled", enabled)
    lunar.storage.set("prediction", prediction)
    lunar.storage.set("half_length", half_length)
    lunar.storage.set("height_offset", height_offset)
    lunar.storage.set("height_slope", height_slope)
    lunar.storage.set("console_range", console_range)
    lunar.storage.set("cooldown_ms", cooldown_ms)
    lunar.storage.set("exit_after", exit_after)
end

local function distance2(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return dx * dx + dz * dz
end

local function target_is_valid(target)
    return target.root ~= nil and target.root.valid
        and not target.is_self
        and not target.is_dead
        and not target.is_downed
        and not target.is_mirror_survivor
end

local function build_candidate()
    local targets = lunar.mad_eyes.targets()
    local consoles = lunar.mad_eyes.consoles()
    local best = nil
    local range2 = console_range * console_range

    for _, target in ipairs(targets) do
        if target_is_valid(target) then
            local velocity = target.motion.velocity
            local px = target.root.x + velocity.x * prediction
            local py = target.root.y + velocity.y * prediction + height_offset
            local pz = target.root.z + velocity.z * prediction

            for _, console in ipairs(consoles) do
                if console.root and console.root.valid then
                    local d2 = distance2(px, pz, console.root.x, console.root.z)
                    if d2 < range2 and (best == nil or d2 < best.score) then
                        best = {
                            target = target,
                            console = console,
                            x = px, y = py, z = pz,
                            score = d2
                        }
                    end
                end
            end
        end
    end
    if best == nil then return nil end

    -- 优先按实际速度垂直拦截；静止时退回角色朝向。
    local vx = best.target.motion.velocity.x
    local vz = best.target.motion.velocity.z
    local speed = math.sqrt(vx * vx + vz * vz)
    if speed < 0.20 then
        vx = best.target.motion.direction.x
        vz = best.target.motion.direction.z
        speed = math.sqrt(vx * vx + vz * vz)
    end
    if speed < 0.001 then
        vx, vz, speed = 1.0, 0.0, 1.0
    end

    local nx, nz = -vz / speed, vx / speed
    local half_slope = height_slope * 0.5
    best.start = {
        x = best.x - nx * half_length,
        y = best.y - half_slope,
        z = best.z - nz * half_length
    }
    best.finish = {
        x = best.x + nx * half_length,
        y = best.y + half_slope,
        z = best.z + nz * half_length
    }
    return best
end

local function restore_builtin()
    if disabled_builtin then
        lunar.mad_eyes.set_auto_enabled(true)
        disabled_builtin = false
    end
end

return {
    api = 1,
    requires = { "mad_eyes", "mad_eyes.place_wall" },
    name = "疯眼自定义放墙",
    version = "1.0.0",

    on_load = function()
        if type(lunar.mad_eyes) ~= "table"
            or type(lunar.mad_eyes.place_wall) ~= "function" then
            error("需要更新 DLL：缺少 lunar.mad_eyes API")
        end
        lunar.log.info("疯眼 Lua 算法已加载，默认保持关闭")
    end,

    on_tick = function()
        if not enabled then
            restore_builtin()
            return
        end
        if lunar.game.scene() ~= "game" then return end

        if lunar.mad_eyes.auto_enabled() then
            local ok, status = lunar.mad_eyes.set_auto_enabled(false)
            if not ok then
                last_status = status
                return
            end
            disabled_builtin = true
        end

        local candidate = build_candidate()
        if candidate == nil then
            last_status = "范围内没有可用目标或控制台"
            preview_start, preview_finish = nil, nil
            return
        end
        preview_start, preview_finish = candidate.start, candidate.finish

        local now = lunar.system.now_ms()
        if now - last_place_ms < cooldown_ms then return end
        local ok, status = lunar.mad_eyes.place_wall(
            candidate.console.uid, candidate.start, candidate.finish, exit_after)
        last_status = status
        if ok then last_place_ms = now end
    end,

    on_draw = function(draw)
        if not enabled or preview_start == nil then return end
        local points = lunar.game.project({ preview_start, preview_finish })
        if #points == 2 and points[1].visible and points[2].visible then
            draw.line(points[1].x, points[1].y, points[2].x, points[2].y,
                { 0.81, 0.66, 0.70, 0.95 }, 2.0)
            draw.circle_filled(points[1].x, points[1].y, 3.0, { 0.35, 0.90, 0.65, 1.0 })
            draw.circle_filled(points[2].x, points[2].y, 3.0, { 0.35, 0.90, 0.65, 1.0 })
        end
    end,

    on_unload = function()
        restore_builtin()
    end,

    tabs = {
        {
            id = "algorithm",
            title = "自定义放墙",
            render = function(ui)
                local changed
                enabled, changed = ui.checkbox("enabled", "启用 Lua 放墙算法", enabled)
                if changed then save() end

                prediction, changed = ui.slider_float("prediction", "预测时间（秒）",
                    prediction, 0.0, 1.5, "%.2f")
                if changed then save() end

                half_length, changed = ui.slider_float("half_length", "墙体半长",
                    half_length, 0.5, 12.0, "%.2f")
                if changed then save() end

                height_offset, changed = ui.slider_float("height_offset", "整体高度偏移",
                    height_offset, -10.0, 10.0, "%.2f")
                if changed then save() end

                height_slope, changed = ui.slider_float("height_slope", "两端高度差",
                    height_slope, -10.0, 10.0, "%.2f")
                if changed then save() end

                console_range, changed = ui.slider_float("console_range", "控制台作用距离",
                    console_range, 50.0, 499.0, "%.0f")
                if changed then save() end

                cooldown_ms, changed = ui.slider_int("cooldown_ms", "放墙间隔（毫秒）",
                    cooldown_ms, 100, 3000)
                if changed then save() end

                exit_after, changed = ui.checkbox("exit_after", "每次放墙后退出控制台", exit_after)
                if changed then save() end

                ui.separator()
                ui.text("状态：" .. last_status)
                ui.text("start.y / finish.y 会原样提交，可自行重写高度与坡度算法。")
            end
        }
    }
}
