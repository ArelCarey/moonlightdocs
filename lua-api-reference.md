# Lunar Lua 开发者 API 完整参考

本文档对应宿主 **Lua API v1**（`lunar.api_version == 1`），以
`src/runtime/lua_script_system.cpp` 中实际注册的接口为准。当前共有 65 个函数，另有
`lunar.keys` 常量表和全局 `print`。

- 入门与设计说明：[lua-scripting.md](lua-scripting.md)
- 基础示例：[example_overlay.lua](examples/lua/example_overlay.lua)
- 中文 UI 示例：[chinese_demo.lua](examples/lua/chinese_demo.lua)
- 疯眼算法示例：[mad_eyes_custom.lua](examples/lua/mad_eyes_custom.lua)

## 目录

1. [运行环境与文件位置](#1-运行环境与文件位置)
2. [最小脚本与模块格式](#2-最小脚本与模块格式)
3. [生命周期、调用上下文与预算](#3-生命周期调用上下文与预算)
4. [通用数据类型](#4-通用数据类型)
5. [`lunar.game` 游戏数据](#5-lunargame-游戏数据)
6. [`lunar.mad_eyes` 疯眼算法](#6-lunarmad_eyes-疯眼算法)
7. [`lunar.draw` 绘制](#7-lunardraw-绘制)
8. [`lunar.ui` 菜单控件](#8-lunarui-菜单控件)
9. [`lunar.input` 输入](#9-lunarinput-输入)
10. [`lunar.storage` 持久化](#10-lunarstorage-持久化)
11. [`lunar.log`、`print` 与 `lunar.system`](#11-lunarlogprint-与-lunarsystem)
12. [`lunar.keys` 键值常量](#12-lunarkeys-键值常量)
13. [沙箱与资源限制](#13-沙箱与资源限制)
14. [错误处理与调试](#14-错误处理与调试)
15. [完整示例骨架](#15-完整示例骨架)

---

## 1. 运行环境与文件位置

脚本使用 UTF-8 编码并以 `.lua` 为扩展名。

```text
%LOCALAPPDATA%\LunarClient\lua\scripts   脚本目录
%LOCALAPPDATA%\LunarClient\lua\data      每脚本持久化数据
%LOCALAPPDATA%\LunarClient\lua\lua.log   运行日志
```

每个文件拥有独立的 Lua 5.4 VM、全局环境、回调和存储命名空间。`script_id` 从文件名生成：
扩展名被移除，字母、数字、`_`、`-` 保留，其余字符替换为 `_`，最长 64 字节；重名时追加
`_2`、`_3` 等后缀。

### 管理器行为

- DLL 会在本次会话的首次扫描中加载已有脚本。
- “重新扫描”只同步文件列表；已有脚本的 VM 及加载/卸载状态保持原样。
- 手动扫描中新发现的脚本先进入未加载状态，由用户点击“加载”。
- 修改已加载脚本后，点击该脚本的“重载”应用新源码。
- 删除文件并重新扫描会以 `removed` 原因卸载对应脚本。
- 加载状态只存在于当前会话，不写入配置；`lunar.storage` 只保存脚本自己的业务数据。

---

## 2. 最小脚本与模块格式

脚本块必须返回一个模块表，且 `api` 必须为整数 `1`：

```lua
return {
    api = 1,
    name = "最小脚本",
    version = "1.0.0"
}
```

完整模块字段：

| 字段 | 类型 | 必填 | 说明 |
|---|---:|:---:|---|
| `api` | integer | 是 | 当前固定为 `1` |
| `requires` | string[] | 否 | 加载前校验的 API 路径，最多 16 项 |
| `name` | string | 否 | 菜单显示名，默认 `script_id`，最多读取 128 字节 |
| `version` | string | 否 | 显示版本，默认 `1.0.0`，最多读取 128 字节 |
| `on_load` | function | 否 | 模块验证完成后的初始化回调 |
| `on_tick` | function | 否 | 20 Hz 逻辑回调 |
| `on_draw` | function | 否 | Present 绘制回调 |
| `on_event` | function | 否 | 事件回调 |
| `on_unload` | function | 否 | VM 关闭前回调 |
| `tabs` | table[] | 否 | 脚本菜单页，最多读取 16 项 |

### API 依赖声明

`requires` 使用 `lunar` 之后的点路径，不带 `lunar.` 前缀：

```lua
return {
    api = 1,
    requires = {
        "game.entities",
        "draw.text",
        "mad_eyes.place_wall"
    }
}
```

每条路径最长 96 字节，单个路径段最长 48 字节。缺少任意声明项时，本次加载在回调注册前结束，
脚本卡片显示缺失项。推荐只声明脚本真正依赖、且缺少后没有降级路径的接口。

### 菜单页格式

```lua
tabs = {
    {
        id = "settings",       -- 稳定、脚本内唯一；默认 tab_1
        title = "设置",         -- 显示标题；默认使用 id
        render = function(ui)  -- ui 与 lunar.ui 是同一张 API 表
            ui.text("内容")
        end
    }
}
```

只注册带 `render` 函数的项。`id` 和 `title` 最多读取 128 字节。

---

## 3. 生命周期、调用上下文与预算

### 回调签名

```lua
on_load   = function() end
on_tick   = function(dt) end
on_draw   = function(draw) end
on_event  = function(name, payload) end
on_unload = function(reason) end
```

| 阶段 | 调用时机 | 参数 | 指令预算 | 时间预算 |
|---|---|---|---:|---:|
| 脚本块 / `on_load` | 加载或重载 | 无 | 500,000 | 5 ms |
| `on_tick` | 约 20 Hz | `dt`，秒，最大按 0.25 s 计 | 150,000 | 8 ms |
| `on_draw` | 每个被调度到的 Present | `draw == lunar.draw` | 250,000 | 2 ms |
| Tab `render` | Lua 页面中该 Tab 可见 | `ui == lunar.ui` | 250,000 | 2 ms |
| `on_event` | 事件发生 | `name, payload` | 100,000 | 1 ms |
| `on_unload` | VM 关闭前 | `reason` | 500,000 | 5 ms |

每帧所有 Lua 脚本共享 4 ms 调度预算，并采用轮转起点。脚本较多或单帧耗时较高时，某个脚本可能
在这一帧后移到下一轮，因此业务逻辑应依赖 `dt` 或时间戳，而非假定每次 Present 都执行。

当前事件：

```lua
on_event = function(name, payload)
    if name == "scene_changed" then
        -- payload.previous / payload.current
    end
end
```

场景值为 `unknown`、`login`、`hall`、`loading`、`game`。

常见卸载原因包括 `reload`、`disabled`、`removed`、`shutdown`、`on_load_error`。回调发生 Lua
异常、指令超额或超时后，宿主在第一次错误时停止脚本并保留错误文本。

### API 上下文标记

后文使用以下标记：

- **通用**：脚本块或任一回调执行期间可调用。游戏快照建议在 `on_tick`/`on_draw` 中读取。
- **Tick**：只在 `on_tick` 中调用。
- **Draw**：只在 `on_draw` 中调用。
- **Menu**：只在 Tab 的 `render` 中调用。

---

## 4. 通用数据类型

### `WorldPoint`

```lua
{
    x = 0.0,
    y = 0.0,
    z = 0.0,
    valid = true
}
```

读取世界坐标前先检查 `valid`。

### `ScreenPoint`

```lua
{ x = 0.0, y = 0.0, visible = true }
```

### `DrawPoint`

```lua
{ x = 100.0, y = 200.0 }
```

折线和多边形使用 `DrawPoint[]`。

### `Color`

绘制接口接受以下任一形式，分量会限制到 `0.0..1.0`：

```lua
{ r = 1.0, g = 0.5, b = 0.7, a = 1.0 }
{ 1.0, 0.5, 0.7, 1.0 }
0xFFFFFFFF -- ImGui ABGR packed integer
```

`ui.color_edit` 的输入、输出使用数组形式 `{r, g, b, a}`。

### 缺省数据约定

- 世界点、屏幕点和骨骼均带显式有效标志。
- 可选标识和计数通常用 `0` 表示未知。
- `health`、`max_health`、部分进度类数据使用 `-1` 表示未知。
- 可选字符串返回空串。
- 所有返回表均为当前帧复制到 Lua VM 的快照；修改表不会修改宿主数据。

---

## 5. `lunar.game` 游戏数据

除 `project` 外，本节接口均为**通用**上下文。

### API 索引

| 函数 | 返回值 | 说明 |
|---|---|---|
| `lunar.game.scene()` | `string` | 当前场景 |
| `lunar.game.viewport()` | `Viewport` | 当前渲染尺寸 |
| `lunar.game.time()` | `GameTime` | 帧号、帧间隔与单调毫秒数 |
| `lunar.game.entities(kind?)` | `Entity[]` | 全部实体或按种类精确筛选 |
| `lunar.game.local_player()` | `Entity?` | 本地实体；未取得时为 `nil` |
| `lunar.game.talents()` | `TalentRow[]` | 天赋面板数据 |
| `lunar.game.hunter_prediction()` | `string` | 赛前监管者预测文本 |
| `lunar.game.opponents()` | `OpponentRow[]` | 对局玩家统计 |
| `lunar.game.knight_predictions()` | `KnightPrediction[]` | 骑士预测状态 |
| `lunar.game.copycat_players()` | `CopycatPlayer[]` | 模仿者玩家数据 |
| `lunar.game.copycat_events()` | `CopycatEvent[]` | 模仿者事件日志 |
| `lunar.game.copycat_speakers()` | `CopycatSpeaker[]` | 模仿者语音状态 |
| `lunar.game.copycat_task_progress()` | `TaskProgress` | 任务胜利进度 |
| `lunar.game.navigation()` | `Navigation` | 导航目标、避障点和路径 |
| `lunar.game.project(points)` | `ScreenPoint[]` | **Draw**；批量世界坐标投影 |

### `scene()`

```lua
local scene = lunar.game.scene()
-- "unknown" | "login" | "hall" | "loading" | "game"
```

### `viewport()`

```lua
local viewport = lunar.game.viewport()
-- { width = number, height = number }
```

### `time()`

```lua
local t = lunar.game.time()
-- {
--   frame = integer,       -- Lua 快照帧序号
--   delta = number,        -- 当前 Present 间隔，0.0..0.25 秒
--   milliseconds = integer -- Windows 单调启动毫秒计时
-- }
```

### `entities(kind?)`

```lua
local all = lunar.game.entities()
local survivors = lunar.game.entities("survivor")
```

筛选为精确字符串匹配。已注册种类：

```text
unknown, survivor, hunter, copycat, generator, panel, hook, crate,
wood, cave, door, goldrush_monster, goldrush_drop, goldrush_box,
goldrush_trap, imper_cursor, terrain_console
```

#### `Entity` 完整字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `kind` | string | 上述实体种类 |
| `is_self` | boolean | 是否本地实体 |
| `uid` | integer | 实体 UID，`0` 为未知 |
| `role_id` | integer | 角色 ID |
| `unit_type` | integer | 底层单位类型 |
| `class_name` | string | 底层类名 |
| `label` | string | 角色/实体显示名 |
| `player_name` | string | 玩家昵称 |
| `has_box` | boolean | `x/y/width/height` 是否有效 |
| `x`, `y` | number | 屏幕包围框左上角 |
| `width`, `height` | number | 屏幕包围框尺寸 |
| `has_world_box` | boolean | 是否带世界空间包围框数据 |
| `root`, `top` | `WorldPoint` | 根部和顶部世界坐标 |
| `distance_m` | number | 与本地观察点的距离，米 |
| `progress` | number | 实体进度；未知通常为 `-1` |
| `head_bone` | integer | `bones` 中头部索引；未知为 `-1` |
| `bones` | `Bone[]` | 骨骼点列表 |
| `has_ground_rect` | boolean | 地面四边形屏幕点是否有效 |
| `has_ground_world` | boolean | 地面四边形世界点是否有效 |
| `ground` | `GroundPoint[4]` | 地面四角 |
| `skill_name` | string | 技能显示名 |
| `skill_cd` | integer | 技能冷却数据 |
| `camp_id` | integer | 阵营 ID；`0` 未知 |
| `status_extra` | string | 模式附加状态文本 |
| `firework_left` | number | 烟花炸弹剩余秒数；`0` 表示无 |
| `is_mirror_survivor` | boolean | 是否镜像中的求生者 |
| `is_mary_mirror_projection` | boolean | 是否红夫人镜像投影 |
| `self_revive_used` | boolean | 本局自起是否已消耗 |
| `state_ids` | string | 原始状态 ID 串 |
| `states` | `(integer|string)[]` | 从 `state_ids` 解析的最多 32 项 |
| `is_dead` | boolean | 归一化死亡状态 |
| `is_downed` | boolean | 归一化倒地状态 |
| `health`, `max_health` | number | 生命值；未知为 `-1` |
| `move_speed` | number | 移动速度快照 |
| `velocity_x/y/z` | number | 宿主按世界坐标采样计算的速度 |
| `velocity_speed` | number | 三维速度长度 |
| `attack_reach` | number | 攻击距离/范围值 |
| `attack_angle_min/max` | number | 攻击角度边界 |
| `attack_skill_id` | integer | 当前攻击技能 ID |
| `is_attacking` | boolean | 是否处于攻击状态 |
| `state` | `EntityState` | 状态字段的分组视图 |
| `motion` | `EntityMotion` | 朝向、速度和移动速度的分组视图 |
| `attack` | `EntityAttack` | 攻击字段的分组视图 |

顶层 `move_speed`、`velocity_*`、`attack_*` 与对应分组字段内容相同，便于简单脚本直接访问。

```lua
-- Bone
{
    parent = -1,
    x = 0.0, y = 0.0, valid = false,             -- 屏幕点
    world_x = 0.0, world_y = 0.0, world_z = 0.0,
    world_valid = false
}

-- GroundPoint
{
    x = 0.0, y = 0.0, valid = false,
    world = { x = 0.0, y = 0.0, z = 0.0, valid = false }
}

-- EntityState
{
    raw = "...", dead = false, downed = false,
    health = -1.0, max_health = -1.0
}

-- EntityMotion
{
    direction = { x = 0.0, y = 0.0, z = 0.0 },
    velocity = { x = 0.0, y = 0.0, z = 0.0, speed = 0.0 },
    move_speed = 0.0
}

-- EntityAttack
{
    reach = 0.0,
    angle_min = 0.0,
    angle_max = 0.0,
    skill_id = 0,
    active = false
}
```

速度由连续世界坐标样本计算并平滑；实体静止超过约 300 ms 后归零。它适合轨迹预测，仍应对
`root.valid`、首次样本和瞬时跳点做业务判断。

### `local_player()`

返回第一个 `is_self == true` 的完整 `Entity`，没有匹配项时返回 `nil`。

### `talents()`

```lua
{
    player_name = string,
    role_name = string,
    talents = string,
    is_butcher = boolean
}[]
```

### `hunter_prediction()`

返回赛前监管者预测文本；没有数据时为空串。

### `opponents()`

```lua
{
    player_name = string,
    role_name = string,
    best_role_name = string,
    support_skill_name = string,
    rank_name = string,
    star = integer,
    best_role_score = integer,
    win_rate = number,
    is_teammate = boolean
}[]
```

### `knight_predictions()`

```lua
{
    uid = integer,
    use_id = integer,
    sub_id = integer,
    action = integer,
    state = integer,
    left_time = number,
    total_time = number
}[]
```

`action`、`state`、`use_id`、`sub_id` 保留底层整数，便于脚本实现自己的映射和预测规则。

### `copycat_players()`

```lua
{
    player_name = string,
    role_name = string,
    camp_name = string,
    camp_id = integer,           -- 0 未知，常见：1 好人、2 狼人、3 中立
    is_self = boolean,
    is_dead = boolean,
    uid = integer,
    seat = integer,              -- 1 起始，0 未知
    has_hunter_knife = boolean,
    hunter_knife_open = boolean,
    boxer_alert = boolean,
    protect_target = string,
    firework_left = number,
    wolf_skill_cd = number,
    chess_guess = integer,       -- -1 表示该项不适用
    detective_checked = integer  -- -1 表示该项不适用
}[]
```

### `copycat_events()`

```lua
{ kind = integer, text = string }[]
```

`kind` 常见值：`0` 其他、`1` 击杀、`2` 报案、`3` 投票、`4` 任务、`5` 技能、`6` 回合。

### `copycat_speakers()`

```lua
{
    is_live = boolean,
    seat = integer,
    uid = integer,
    distance_m = number,
    energy = number,
    ago_s = number,
    raw = integer,
    audible = integer,
    name = string,
    text = string
}[]
```

### `copycat_task_progress()`

```lua
local p = lunar.game.copycat_task_progress()
-- { done = integer, total = integer }
-- 0/0 表示当前没有有效数据
```

### `navigation()`

```lua
{
    active = boolean,
    target_room_index = integer,
    target_world_x = number,
    target_world_y = number,
    target_world_z = number,
    target_world_valid = boolean,
    target_x = number,
    target_y = number,
    target_valid = boolean,
    avoidance_entry = NavigationPoint,
    avoidance_exit = NavigationPoint,
    path = NavigationPoint[] -- 最多 192 点
}
```

`NavigationPoint`：

```lua
{
    world_x = number, world_y = number, world_z = number,
    world_valid = boolean,
    x = number, y = number,
    valid = boolean
}
```

### `project(points)` — Draw

一次最多投影 256 个世界点，输入必须是带命名字段的数组：

```lua
local screen = lunar.game.project({
    { x = 10, y = 2, z = 20 },
    { x = 12, y = 2, z = 20 }
})

if screen[1].visible and screen[2].visible then
    lunar.draw.line(screen[1].x, screen[1].y,
                    screen[2].x, screen[2].y,
                    {1, 1, 1, 1}, 2)
end
```

返回数组长度和顺序与输入一致，每项为 `{x, y, visible}`。该函数只在 `on_draw` 中注册有效上下文。

---

## 6. `lunar.mad_eyes` 疯眼算法

该命名空间提供“只读高精度快照 + 固定动作原语”。Lua 可自行实现目标筛选、移动预测、控制台评分、
墙段方向、整体高度、两端高度差、冷却和失败重试。

| 函数 | 上下文 | 返回值 | 说明 |
|---|---|---|---|
| `lunar.mad_eyes.targets()` | 通用 | `Entity[]` | 所有 `survivor` 完整实体 |
| `lunar.mad_eyes.consoles()` | 通用 | `Entity[]` | 所有 `terrain_console` 完整实体 |
| `lunar.mad_eyes.auto_enabled()` | 通用 | `boolean` | 内置自动放墙开关 |
| `lunar.mad_eyes.set_auto_enabled(enabled)` | 通用 | `ok, status` | 设置内置自动放墙 |
| `lunar.mad_eyes.status()` | 通用 | `string` | 最近一次疯眼操作状态 |
| `lunar.mad_eyes.place_wall(console_uid, start, finish, exit_after?)` | **Tick** | `ok, status` | 提交一段精确墙线 |

### `place_wall` 参数

```lua
local ok, status = lunar.mad_eyes.place_wall(
    console_uid,                            -- integer；0 自动选最近控制台
    { x = sx, y = sy, z = sz },             -- 也接受 {sx, sy, sz}
    { x = ex, y = ey, z = ez },             -- 也接受 {ex, ey, ez}
    true                                    -- 默认 true
)
```

- `start.y` 与 `finish.y` 独立提交，可形成高度差和斜率。
- 六个坐标必须是有限数，绝对值不超过 `1,000,000`。
- 三维墙段长度范围为 `0.05..30.0`。
- `console_uid == 0` 时由动作原语选择覆盖墙段且离墙段中点最近的控制台。
- 动作层要求控制台到墙段中点小于 `500`。
- 每个脚本最多提交 12 次/秒；算法还应使用自己的冷却，避免重复墙段。
- 调用时游戏窗口需位于前台、主菜单关闭、功能执行门有效。
- 自定义放墙前应先将内置自动放墙设为 `false`，避免两个调度器竞争。
- `exit_after` 为 `true` 时动作完成后退出控制台交互。
- `status` 是面向显示和日志的诊断文本；控制流以 `ok` 布尔值为准。

推荐模式：

```lua
on_tick = function(dt)
    if lunar.mad_eyes.auto_enabled() then
        local ok = lunar.mad_eyes.set_auto_enabled(false)
        if not ok then return end
    end

    -- 读取 targets/consoles，自行计算 start/finish
    local ok, status = lunar.mad_eyes.place_wall(0, start_point, finish_point, true)
    if not ok then lunar.log.warn(status) end
end
```

完整可调算法见 `examples/lua/mad_eyes_custom.lua`。

---

## 7. `lunar.draw` 绘制

除 `set_layer` 外，每次调用计为一个绘制命令。本命名空间只在 **Draw** 上下文使用。
`on_draw(draw)` 中的 `draw` 与 `lunar.draw` 相同。

### API 索引与签名

```lua
lunar.draw.set_layer(layer)
lunar.draw.line(x1, y1, x2, y2, color, thickness?)
lunar.draw.rect(x, y, width, height, color, thickness?, rounding?)
lunar.draw.rect_filled(x, y, width, height, color, rounding?)
lunar.draw.rect_gradient(x, y, width, height,
                   top_left, top_right, bottom_right, bottom_left)
lunar.draw.circle(x, y, radius, color, thickness?, segments?)
lunar.draw.circle_filled(x, y, radius, color, segments?)
lunar.draw.triangle(x1, y1, x2, y2, x3, y3, color, filled?, thickness?)
lunar.draw.polyline(points, color, closed?, thickness?)
lunar.draw.polygon(points, color)
lunar.draw.bezier(x1, y1, x2, y2, x3, y3, x4, y4,
            color, thickness?, segments?)
lunar.draw.text(x, y, text, options?)
lunar.draw.push_clip(min_x, min_y, max_x, max_y)
lunar.draw.pop_clip()
```

### 参数默认值与行为

| 函数 | 说明 |
|---|---|
| `set_layer("background"|"foreground")` | 默认前景层；切层前裁剪栈深度必须为 0 |
| `line` | `thickness = 1.0`，最小 0.1 |
| `rect` | `thickness = 1.0`，`rounding = 0.0` |
| `rect_filled` | `rounding = 0.0` |
| `rect_gradient` | 四角颜色顺序为左上、右上、右下、左下 |
| `circle` | `thickness = 1.0`，`segments = 0` 表示自动 |
| `circle_filled` | `segments = 0` 表示自动 |
| `triangle` | `filled = false`；非填充时使用 `thickness = 1.0` |
| `polyline` | `closed = false`，`thickness = 1.0`；少于 2 点时无图元 |
| `polygon` | 凸多边形填充；少于 3 点时无图元 |
| `bezier` | 三次贝塞尔；`thickness = 1.0`，`segments = 0` 表示自动 |
| `push_clip` | 与现有裁剪区相交；每次都需配对 `pop_clip` |

点数组格式：

```lua
draw.polyline({
    { x = 100, y = 100 },
    { x = 150, y = 130 },
    { x = 220, y = 110 }
}, { 1, 0.5, 0.7, 1 }, false, 2)
```

### `text` 选项

```lua
draw.text(960, 80, "标题", {
    color = { r = 1, g = 1, b = 1, a = 1 },
    size = 16,           -- 限制到 6..96
    outline = true,
    shadow = false,
    align = "center"    -- "left" | "center" | "right"
})
```

`x` 是对齐锚点；`y` 是文本顶部。单条文本最多 4096 字节。每脚本每帧最多 4096 个绘制命令，
单个折线/多边形最多 1024 点。回调结束时宿主会修复仍未关闭的裁剪栈，但脚本应保持显式配对。

---

## 8. `lunar.ui` 菜单控件

控件 API 只在 **Menu** 上下文使用；`toast` 为**通用**接口。Tab `render(ui)` 的 `ui` 与
`lunar.ui` 相同。每个控件先传稳定、脚本内唯一的 `id`，显示文本使用 `label`。

```lua
lunar.ui.text(text)
lunar.ui.separator()
lunar.ui.same_line(offset_x?, spacing?)
lunar.ui.button(id, label, width?, height?) -> clicked
lunar.ui.checkbox(id, label, value) -> new_value, changed
lunar.ui.slider_int(id, label, value, min, max, format?) -> new_value, changed
lunar.ui.slider_float(id, label, value, min, max, format?) -> new_value, changed
lunar.ui.combo(id, label, selected, items) -> new_selected, changed
lunar.ui.input_text(id, label, value, capacity?) -> new_value, changed
lunar.ui.color_edit(id, label, color) -> new_color, changed
lunar.ui.collapsing_header(id, label) -> open
lunar.ui.begin_child(id, width?, height?, border?) -> visible
lunar.ui.end_child()
lunar.ui.toast(message)
```

### 控件说明

| 函数 | 细节 |
|---|---|
| `text` | 输出一行原始文本 |
| `separator` | 分隔线 |
| `same_line` | 默认 `offset_x=0`、`spacing=-1`（使用主题间距） |
| `button` | 默认宽度为文字宽度 + 24，高度 28；返回本帧是否点击 |
| `checkbox` | 返回新值及本帧是否改变 |
| `slider_int` | 整数滑条；当前显示固定为十进制整数，`format` 参数保留兼容 |
| `slider_float` | 支持 `%.0f`、`%.1f`、`%.2f`、`%.3f`，其他格式按 `%.3f` |
| `combo` | `selected` 为 Lua 风格 1 起始索引；最多读取 128 个选项 |
| `input_text` | `capacity` 默认 512，限制到 16..2048 字节 |
| `color_edit` | 数组颜色 `{r,g,b,a}`；返回同格式新数组 |
| `collapsing_header` | 返回当前是否展开 |
| `begin_child` | 默认 `width=0,height=0,border=false`；最大嵌套 8 层 |
| `toast` | 屏幕顶部显示约 3 秒，自动加脚本名；总文本最多 512 字节 |

有值控件的典型写法：

```lua
enabled, changed = ui.checkbox("enabled", "启用", enabled)
if changed then lunar.storage.set("enabled", enabled) end

scale, changed = ui.slider_float("scale", "缩放", scale, 0.5, 2.0, "%.2f")
if changed then lunar.storage.set("scale", scale) end
```

`begin_child` 调用后，无论 `visible` 返回值为何，都要在同次 `render` 中执行一次 `end_child`：

```lua
local visible = ui.begin_child("list", 0, 220, true)
if visible then ui.text("列表内容") end
ui.end_child()
```

每个 Tab 每帧最多调用 256 个 UI 控件函数；`same_line`、`separator`、`end_child` 也计数。

---

## 9. `lunar.input` 输入

```lua
lunar.input.is_down(vk) -> boolean
lunar.input.pressed(vk) -> boolean
lunar.input.tap(vk) -> queued
lunar.input.key_down(vk) -> queued
lunar.input.key_up(vk) -> queued
lunar.input.mouse_move(dx, dy) -> queued
lunar.input.mouse_button(name, down) -> queued
lunar.input.release_all()
```

### 读取

- `is_down(vk)`：当前允许输入且按键物理状态为按下时返回 `true`。
- `pressed(vk)`：每脚本独立的按下边沿；持续按住只在第一次观察时返回 `true`。
- VK 有效范围为 `1..255`，常用值见 `lunar.keys`。

### 模拟

- `tap`、`key_down`、`key_up` 返回是否成功加入本脚本队列，不代表游戏已经处理该输入。
- `mouse_move` 使用相对位移，`dx`、`dy` 各自范围为 `-32767..32767`。
- `mouse_button` 的 `name` 为 `left`、`right`、`middle`、`x1`、`x2`。
- 每脚本队列最多 64 项，每秒最多实际发送 100 项。
- 只有游戏窗口在前台、主菜单关闭且功能执行门有效时才会发送。
- 窗口失焦、打开菜单、脚本卸载或 DLL 退出时，宿主释放该脚本持有的键盘键和鼠标键。
- `release_all()` 会清空待发送队列并立即释放该脚本记录的所有按住状态。

推荐将 `key_down` 与 `key_up` 配对；短按直接使用 `tap`。

---

## 10. `lunar.storage` 持久化

```lua
lunar.storage.get(key, default?) -> value
lunar.storage.set(key, value) -> true
lunar.storage.delete(key) -> removed
```

- 存储按 `script_id` 隔离，文件位于 `lua\data\<script_id>.bin`。
- `get` 在键不存在时返回传入的 `default`；未传默认值时返回 `nil`。
- `delete` 在键存在并删除成功时返回 `true`，键不存在时返回 `false`。
- 顶层键长度为 `1..128` 字节。
- 值支持 `nil`、boolean、有限 number、string、字符串键 table。
- table 最多嵌套 4 层，总条目最多 256，嵌套键最长 128 字节。
- 每脚本序列化数据上限 64 KiB；`set` 与 `delete` 同步原子写入。
- 数组的整数键不属于持久化格式；需要保存列表时可转换成字符串键，如 `"1"`、`"2"`。
- 函数、线程、userdata、循环引用和 NaN/Infinity 不属于持久化值类型。

业务数据持久化与管理器加载状态相互独立。示例：

```lua
local settings = lunar.storage.get("settings", {
    enabled = true,
    color = { r = 1.0, g = 0.4, b = 0.7, a = 1.0 }
})

lunar.storage.set("settings", settings)
```

---

## 11. `lunar.log`、`print` 与 `lunar.system`

### 日志

```lua
lunar.log.info(message)
lunar.log.warn(message)
lunar.log.error(message)
print(value1, value2, ...)
```

三种日志函数单条最多写入 4096 字节。`print` 使用 Lua `tostring` 规则转换参数，以 Tab 分隔，
同样写入 INFO 日志。输出同时发送到调试输出和：

```text
%LOCALAPPDATA%\LunarClient\lua\lua.log
```

日志格式：

```text
[Lua][script_id][INFO] message
```

### 系统

```lua
lunar.system.now_ms() -> integer
lunar.system.script_id() -> string
```

- `now_ms()` 返回单调的系统启动毫秒数，适合冷却和间隔计算，不是 Unix 时间。
- `script_id()` 返回当前脚本的稳定存储 ID。
- `lunar.api_version` 当前为整数 `1`。

---

## 12. `lunar.keys` 键值常量

```text
backspace  tab      enter    shift    control  alt      escape   space
page_up    page_down end      home     left     up       right    down
insert     delete
f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12
```

示例：

```lua
if lunar.input.pressed(lunar.keys.f8) then
    enabled = not enabled
end
```

未列出的键可直接传 Windows VK 整数（`1..255`）。

---

## 13. 沙箱与资源限制

### 已开放标准库

```text
base, table, string, math, utf8
```

### 从全局环境移除

```text
dofile, load, loadfile, collectgarbage, require, package,
io, os, debug, coroutine, string.dump
```

Lua 环境没有注册 Python、系统命令、文件、网络、动态库、原生地址或进程访问接口。宿主功能只通过
本文列出的固定 `lunar.*` 函数暴露。

### 限制汇总

| 项目 | 上限 |
|---|---:|
| 同时列出的脚本 | 32 |
| 单脚本源码 | 1 MiB |
| 单 VM 内存 | 16 MiB |
| 单脚本持久化 | 64 KiB |
| `requires` | 16 项 |
| 脚本 Tab | 16 项 |
| 单帧绘制命令 | 4096 |
| 单折线/多边形点 | 1024 |
| 单次世界投影点 | 256 |
| 单 Tab UI 控件 | 256 |
| UI child 嵌套 | 8 |
| 输入待发送队列 | 64 |
| 输入发送速率 | 100 项/秒/脚本 |
| 疯眼墙提交速率 | 12 次/秒/脚本 |
| 所有 Lua 每帧调度预算 | 4 ms |

---

## 14. 错误处理与调试

### 加载验证顺序

1. 文件存在且不超过 1 MiB。
2. 以文本块编译 Lua 源码。
3. 在 500,000 指令 / 5 ms 预算内执行脚本块。
4. 返回值为 table。
5. `api == 1`。
6. `requires` 中每项存在。
7. 读取回调和 Tabs。
8. 执行 `on_load`；成功后保持加载。

语法、模块格式、API 依赖或 `on_load` 的错误会让本次加载失败。运行期任一回调首次出错后，脚本
立即进入卸载流程，脚本卡片保留具体文件、行号或 `callback budget exceeded` 信息。

### 调试建议

```lua
local function assert_world(point, name)
    assert(type(point) == "table" and point.valid, name .. " world point invalid")
end

on_tick = function(dt)
    local ok, err = pcall(function()
        -- 对可预期、可恢复的算法分支做局部保护
    end)
    if not ok then lunar.log.warn(err) end
end
```

- 加载前先写 `requires`，让版本问题显示为明确的缺失 API。
- 读取坐标先检查 `valid`/`visible`，读取本地玩家先检查 `nil`。
- 高频回调中复用 Lua table，减少 VM 分配和 GC 压力。
- 批量投影优先使用一次 `game.project(points)`，避免逐点业务调用。
- 日志只记录状态变化，避免每帧大量写盘。
- 源码修改后使用单脚本“重载”；“重新扫描”保持现有 VM。

---

## 15. 完整示例骨架

```lua
local enabled = lunar.storage.get("enabled", true)
local color = lunar.storage.get("color", { 1.0, 0.4, 0.7, 1.0 })

local function save()
    lunar.storage.set("enabled", enabled)
    lunar.storage.set("color", color)
end

return {
    api = 1,
    requires = {
        "game.entities",
        "draw.rect",
        "ui.checkbox"
    },
    name = "开发者示例",
    version = "1.0.0",

    on_load = function()
        lunar.log.info("loaded: " .. lunar.system.script_id())
    end,

    on_tick = function(dt)
        if lunar.input.pressed(lunar.keys.f8) then
            enabled = not enabled
            save()
            lunar.ui.toast(enabled and "已启用" or "已停用")
        end
    end,

    on_draw = function(draw)
        if not enabled then return end
        for _, entity in ipairs(lunar.game.entities("survivor")) do
            if not entity.is_self and entity.has_box then
                draw.rect(entity.x, entity.y, entity.width, entity.height,
                          color, 1.5, 3.0)
                local title = entity.player_name ~= "" and entity.player_name or entity.label
                draw.text(entity.x + entity.width * 0.5, entity.y - 18, title, {
                    color = color,
                    size = 15,
                    outline = true,
                    align = "center"
                })
            end
        end
    end,

    on_event = function(name, payload)
        if name == "scene_changed" then
            lunar.log.info(payload.previous .. " -> " .. payload.current)
        end
    end,

    on_unload = function(reason)
        lunar.input.release_all()
        lunar.log.info("unloaded: " .. reason)
    end,

    tabs = {
        {
            id = "settings",
            title = "示例设置",
            render = function(ui)
                local changed
                enabled, changed = ui.checkbox("enabled", "启用绘制", enabled)
                if changed then save() end

                color, changed = ui.color_edit("color", "框体颜色", color)
                if changed then save() end

                ui.separator()
                ui.text("关闭菜单后按 F8 快速切换。")
            end
        }
    }
}
```

