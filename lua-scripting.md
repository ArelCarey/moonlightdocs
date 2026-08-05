# Lunar Lua 脚本 API v1

> **完整开发者参考：** [lua-api-reference.md](lua-api-reference.md)  
> 该参考包含全部 67 个函数签名、实体字段、回调上下文、默认值、限制与错误行为；本文保留为快速入门。

## 安装与管理

DLL 首次进入渲染循环时会创建：

```text
%LOCALAPPDATA%\LunarClient\lua\scripts
%LOCALAPPDATA%\LunarClient\lua\data
```

把 UTF-8 编码的 `.lua` 文件放入 `scripts`，然后在菜单的 **Lua → Script manager** 中重新扫描。加载/卸载状态只保存在当前会话内；重新扫描会保留已有脚本的状态和 VM，新发现的文件进入列表后保持未加载，源码更新通过单个脚本的“重载”按钮应用。每个文件运行在独立 Lua 5.4 VM 中，文件名会转换成稳定的 `script_id`。

脚本必须返回模块表。可用 `requires` 声明加载前必须存在的 API；缺项时 VM 会在执行回调前关闭：

```lua
return {
    api = 1,
    requires = { "mad_eyes", "mad_eyes.place_wall" },
    name = "My script",
    version = "1.0.0",
    on_load = function() end,
    on_tick = function(dt) end,
    on_draw = function(draw) end,
    on_event = function(name, payload) end,
    on_unload = function(reason) end,
    native_overlay = {
        priority = 100,
        process = function(frame) end
    },
    tabs = {
        { id = "main", title = "Main", render = function(ui) end }
    }
}
```

`on_tick` 以 20 Hz 调度，`on_draw` 每个 Present 调度，Tab 的 `render` 仅在该页面可见时调度。`on_event` 当前发送 `scene_changed`，负载包含 `previous` 和 `current`。

## 游戏数据

- `lunar.game.scene()`：`unknown/login/hall/loading/game`。
- `lunar.game.viewport()`：`{width,height}`。
- `lunar.game.time()`：`{frame,delta,milliseconds}`。
- `lunar.game.camera()`：返回视口中心的实时镜头射线起点与归一化方向。
- `lunar.game.ground_raycast(x?, y?, max_distance?)`：从屏幕点检测地面/静态场景，返回命中点、法线与距离。
- `lunar.game.entities(kind?)`、`local_player()`：实体的屏幕框、世界点、骨骼、距离、进度、名称、技能和模式状态。`kind` 新增 `terrain_console`。
- 玩家实体明细：`uid`、`role_id`、`unit_type`、`states`、`state_ids`、`is_dead`、`is_downed`、`health`、`max_health`。
- 运动明细：`motion.direction.{x,y,z}`、`motion.velocity.{x,y,z,speed}`、`motion.move_speed`；同名速度字段也保留在实体顶层。
- 监管者攻击明细：`attack.{reach,angle_min,angle_max,skill_id,active}`。读取不到的可选数值使用 `0`，生命值使用 `-1`。
- `talents()`、`hunter_prediction()`、`opponents()`、`knight_predictions()`。
- `copycat_players()`、`copycat_events()`、`copycat_speakers()`、`copycat_task_progress()`。
- `navigation()`：目标、避障点和路径。
- `lunar.game.project(points)`：仅在 `on_draw` 中使用；批量投影最多 256 个 `{x,y,z}` 世界点，返回 `{x,y,visible}`。

数据均为当前帧的脚本私有副本。


## 疯眼精细控制 API

该接口采用“数据快照 → Lua 算法 → 固定动作原语”的结构：目标筛选、轨迹预测、控制台选择、墙体方向与高度全部由 Lua 决定，宿主只校验并提交一条墙段。

- `lunar.mad_eyes.targets()`：返回求生者明细实体数组。
- `lunar.mad_eyes.consoles()`：返回 `terrain_console` 实体数组。
- `lunar.mad_eyes.auto_enabled()`：内置自动放墙是否开启。
- `lunar.mad_eyes.set_auto_enabled(enabled)`：返回 `ok, status`。
- `lunar.mad_eyes.status()`：最近一次疯眼操作状态。
- `lunar.mad_eyes.place_wall(console_uid, start_point, finish_point, exit_after?)`：返回 `ok, status`。

`place_wall` 仅在 `on_tick` 中调用：

```lua
local ok, status = lunar.mad_eyes.place_wall(
    console.uid,
    { x = target.root.x - 3, y = target.root.y + height, z = target.root.z },
    { x = target.root.x + 3, y = target.root.y + height + slope, z = target.root.z },
    true
)
```

`start_point.y` 与 `finish_point.y` 会分别原样提交，因此脚本可自定义整体高度、两端高度差和斜率。`console_uid = 0` 时由原语选取离墙段中点最近的控制台。墙段长度范围为 `0.05..30.0`，控制台到墙段中点需小于 `500`，每个脚本每秒最多提交 12 次；提交时游戏窗口需位于前台且主菜单关闭。为了避免两个调度器相互竞争，自定义放墙前应关闭内置自动放墙。

完整可改写算法见 `examples/lua/mad_eyes_custom.lua`。示例在 Lua 内完成速度预测、垂直拦截、控制台评分、冷却、整体高度和两端高度差计算。

## 绘制 API

`on_draw(draw)` 的 `draw` 支持：

```text
line, rect, rect_filled, rect_gradient
circle, circle_filled, triangle
polyline, polygon, bezier, text
push_clip, pop_clip
```

`draw.set_layer("background")` 与 `draw.set_layer("foreground")` 用于切换绘制层，默认使用前景层；切换前应结束当前裁剪区域。

颜色使用 `{r,g,b,a}` 或 `{r,g,b,a}` 数组，分量范围为 `0.0..1.0`；也可传 ImGui `ABGR` packed integer。`text` 的第四个参数是选项表：

```lua
draw.text(x, y, "text", {
    color = {1, 1, 1, 1},
    size = 16,
    outline = true,
    shadow = false,
    align = "left" -- left/center/right
})
```

每脚本每帧最多 4096 个图元，折线/多边形最多 1024 个点。

## 原生游戏覆盖层处理器

脚本可以显式声明 `native_overlay.process(frame)`，在原生 ESP/HUD 写入 ImGui 之前修改其语义化绘制元素。该管线只包含游戏表层；Lunar 主菜单、Lua 管理器、脚本 Tab 和系统菜单控件始终由宿主绘制。

```lua
native_overlay = {
    priority = 100,
    process = function(frame)
        for _, element in ipairs(frame.elements) do
            if element.tag == "esp.player.box" then
                element.style.color = { 0.25, 0.82, 1.0, 1.0 }
                element.style.thickness = 2.5
                element.style.rounding = 5.0
            elseif element.tag == "esp.player.label" and element.primitive == "text" then
                element.text = "[LUA] " .. element.text
                element.style.font_size = 17.0
            elseif element.tag == "esp.player.progress" then
                element.visible = false
            end
        end
    end
}
```

未声明 `native_overlay.process` 时不会创建 Lua 元素表或进入处理回调。多个脚本声明处理器时只选择一个：`priority` 较高者优先，同优先级按稳定 `script_id` 排序。处理器每帧预算为 500,000 条指令 / 4 ms。

`frame` 包含只读的 `width`、`height` 和固定长度的 `elements`。元素可修改字段：`visible`、`layer`、`order`、`x/y/x2/y2/x3/y3`、`radius`、文本元素的 `text`，以及 `style.color/color2/color3/color4/outline_color/thickness/rounding/font_size/outline/outline_size/shadow/segments/closed`。`tag`、`primitive`、`entity_uid`、`distance_m` 用于识别来源。隐藏元素请设置 `visible = false`，不要改变数组长度。

处理结果会先完整校验再提交；回调异常或数据无效时使用未修改的原生帧，并停止对应脚本。完整示例见 [`native_overlay_style.lua`](examples/native_overlay_style.lua)。

## UI、输入、存储和日志

- UI：`text`、`separator`、`same_line`、`button`、`checkbox`、`slider_int`、`slider_float`、`combo`、`input_text`、`color_edit`、`collapsing_header`、`begin_child/end_child`、`toast`。
- 有值控件返回 `new_value, changed`；控件签名以 `id, label` 开头，ID 自动按脚本隔离。
- `combo` 的选中索引遵循 Lua 惯例，从 `1` 开始。
- 输入读取：`lunar.input.is_down(vk)`、`pressed(vk)`。
- 输入模拟：`tap`、`key_down`、`key_up`、`mouse_move`、`mouse_button`、`release_all`。
- 常用键位位于 `lunar.keys`，例如 `lunar.keys.f8`、`lunar.keys.space`。
- 存储：`lunar.storage.get(key, default)`、`set(key, value)`、`delete(key)`；支持布尔、有限数字、字符串及最多四层的字符串键表。
- 日志：`lunar.log.info/warn/error`，`print` 会写入同一日志；文件位于 `%LOCALAPPDATA%\LunarClient\lua\lua.log`。

模拟输入仅在游戏窗口位于前台且主菜单关闭时发送。窗口失焦、打开菜单、脚本停止或 DLL 退出都会释放脚本持有的键位。

## 沙箱与资源限制

- 每个脚本 16 MiB VM 配额，源码上限 1 MiB，同时加载上限 32 个。
- 标准库为裁剪后的 `base/table/string/math/utf8`。
- 文本模式加载 `.lua`；Python、系统命令、文件、网络、动态库、原生地址和进程 API 均未注册到 Lua 全局环境。
- 回调具有指令和时间预算；任一回调发生异常后脚本会立即卸载，错误保留在脚本卡片；点击加载或重载后重新验证。

完整示例见 `examples/lua/example_overlay.lua`、`examples/lua/chinese_demo.lua` 与 `examples/lua/mad_eyes_custom.lua`。
