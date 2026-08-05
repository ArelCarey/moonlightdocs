(() => {
  "use strict";

  const api = {
    game: [
      ["scene()", "string", "通用", "返回当前场景：unknown、login、hall、loading 或 game。"],
      ["viewport()", "{ width: number, height: number }", "通用", "返回当前 ImGui 渲染视口尺寸。"],
      ["time()", "{ frame: integer, delta: number, milliseconds: integer }", "通用", "返回 Lua 快照帧序号、0..0.25 秒帧间隔与单调启动毫秒数。"],
      ["entities(kind?)", "Entity[]", "通用", "返回本帧完整实体副本；kind 为可选的精确种类过滤字符串。"],
      ["local_player()", "Entity | nil", "通用", "返回第一个 is_self 实体；本帧未取得时返回 nil。"],
      ["talents()", "TalentRow[]", "通用", "每项包含 player_name、role_name、talents 与 is_butcher。"],
      ["hunter_prediction()", "string", "通用", "返回赛前监管者预测文本，当前无数据时为空串。"],
      ["opponents()", "OpponentRow[]", "通用", "返回角色、辅助技能、段位、星数、角色分、胜率及同阵营标志。"],
      ["knight_predictions()", "KnightPrediction[]", "通用", "返回 uid、use_id、sub_id、action、state、left_time 与 total_time。"],
      ["copycat_players()", "CopycatPlayer[]", "通用", "返回模仿者玩家身份、阵营、座位、技能和模式附加状态。"],
      ["copycat_events()", "{ kind: integer, text: string }[]", "通用", "返回模仿者事件日志；kind 常见 1..6 对应击杀、报案、投票、任务、技能、回合。"],
      ["copycat_speakers()", "CopycatSpeaker[]", "通用", "返回实时/历史发言、座位、距离、能量、可听状态与显示文本。"],
      ["copycat_task_progress()", "{ done: integer, total: integer }", "通用", "返回任务胜利进度；0/0 表示当前没有有效数据。"],
      ["navigation()", "Navigation", "通用", "返回导航目标、屏幕/世界坐标、避障入口出口与最多 192 个路径点。"],
      ["project(points)", "{ x: number, y: number, visible: boolean }[]", "Draw", "批量投影最多 256 个命名字段 {x,y,z} 世界点，返回顺序与输入一致。"]
    ],
    mad_eyes: [
      ["targets()", "Entity[]", "通用", "返回所有 survivor 类型的完整高精度实体快照。"],
      ["consoles()", "Entity[]", "通用", "返回所有 terrain_console 类型的完整实体快照。"],
      ["auto_enabled()", "boolean", "通用", "读取宿主内置自动放墙开关。"],
      ["set_auto_enabled(enabled)", "boolean ok, string status", "通用", "设置内置自动放墙状态；自定义算法提交墙段前应先关闭内置调度器。"],
      ["status()", "string", "通用", "读取最近一次疯眼操作的诊断状态文本。"],
      ["place_wall(console_uid, start, finish, exit_after?)", "boolean ok, string status", "Tick", "提交精确三维墙段。console_uid=0 自动选最近控制台；exit_after 默认 true。"]
    ],
    draw: [
      ["set_layer(layer)", "nil", "Draw", "切换 background 或 foreground；切换前裁剪栈深度必须为 0。"],
      ["line(x1, y1, x2, y2, color, thickness?)", "nil", "Draw", "绘制线段；thickness 默认 1.0，最小 0.1。"],
      ["rect(x, y, width, height, color, thickness?, rounding?)", "nil", "Draw", "绘制矩形轮廓；厚度默认 1.0，圆角默认 0。"],
      ["rect_filled(x, y, width, height, color, rounding?)", "nil", "Draw", "绘制填充矩形；rounding 默认 0。"],
      ["rect_gradient(x, y, width, height, top_left, top_right, bottom_right, bottom_left)", "nil", "Draw", "使用左上、右上、右下、左下四角颜色绘制渐变矩形。"],
      ["circle(x, y, radius, color, thickness?, segments?)", "nil", "Draw", "绘制圆形轮廓；segments=0 时自动分段。"],
      ["circle_filled(x, y, radius, color, segments?)", "nil", "Draw", "绘制填充圆；segments 默认自动。"],
      ["triangle(x1, y1, x2, y2, x3, y3, color, filled?, thickness?)", "nil", "Draw", "绘制三角形；filled 默认 false，轮廓厚度默认 1.0。"],
      ["polyline(points, color, closed?, thickness?)", "nil", "Draw", "绘制 {x,y} 点列；最多 1024 点，closed 默认 false。"],
      ["polygon(points, color)", "nil", "Draw", "填充凸多边形；至少 3 点，最多 1024 点。"],
      ["bezier(x1, y1, x2, y2, x3, y3, x4, y4, color, thickness?, segments?)", "nil", "Draw", "绘制三次贝塞尔曲线；segments=0 时自动分段。"],
      ["text(x, y, text, options?)", "nil", "Draw", "绘制文本；options 支持 color、size 6..96、outline、shadow、left/center/right 对齐。"],
      ["push_clip(min_x, min_y, max_x, max_y)", "nil", "Draw", "压入与现有区域相交的裁剪矩形，需与 pop_clip 配对。"],
      ["pop_clip()", "nil", "Draw", "弹出一层裁剪区域；空栈调用会触发脚本错误。"]
    ],
    ui: [
      ["text(text)", "nil", "Menu", "在脚本 Tab 中输出一行原始文本。"],
      ["separator()", "nil", "Menu", "绘制横向内容分隔线。"],
      ["same_line(offset_x?, spacing?)", "nil", "Menu", "将下一控件放到同一行；默认 offset_x=0、spacing=-1。"],
      ["button(id, label, width?, height?)", "boolean clicked", "Menu", "绘制按钮并返回本帧点击状态；默认高度 28。"],
      ["checkbox(id, label, value)", "new_value, changed", "Menu", "绘制开关，返回新布尔值和本帧变化标志。"],
      ["slider_int(id, label, value, min, max, format?)", "new_value, changed", "Menu", "整数滑条；当前显示固定为十进制，format 参数保留兼容。"],
      ["slider_float(id, label, value, min, max, format?)", "new_value, changed", "Menu", "浮点滑条；支持 %.0f、%.1f、%.2f、%.3f。"],
      ["combo(id, label, selected, items)", "new_selected, changed", "Menu", "1 起始选择索引；最多读取 128 个字符串选项。"],
      ["input_text(id, label, value, capacity?)", "new_value, changed", "Menu", "文本输入；capacity 默认 512，限制到 16..2048 字节。"],
      ["color_edit(id, label, color)", "{r,g,b,a}, changed", "Menu", "编辑数组形式的 RGBA 浮点颜色并返回新数组。"],
      ["collapsing_header(id, label)", "boolean open", "Menu", "绘制折叠标题并返回当前展开状态。"],
      ["begin_child(id, width?, height?, border?)", "boolean visible", "Menu", "开始子区域，最大嵌套 8 层；每次调用都要配对 end_child。"],
      ["end_child()", "nil", "Menu", "结束最近的子区域；空栈调用会触发脚本错误。"],
      ["toast(message)", "nil", "通用", "显示约 3 秒的顶部通知，自动加脚本名，总长度最多 512 字节。"]
    ],
    input: [
      ["is_down(vk)", "boolean", "通用", "输入条件有效且 VK 当前按下时返回 true；VK 范围 1..255。"],
      ["pressed(vk)", "boolean", "通用", "每脚本独立的按下边沿；持续按住只在第一次观察时返回 true。"],
      ["tap(vk)", "boolean queued", "通用", "将一次按下+释放加入脚本输入队列。"],
      ["key_down(vk)", "boolean queued", "通用", "将按键按下加入队列并由宿主跟踪持有状态。"],
      ["key_up(vk)", "boolean queued", "通用", "将按键释放加入队列并清除对应持有状态。"],
      ["mouse_move(dx, dy)", "boolean queued", "通用", "加入相对鼠标位移；每轴范围 -32767..32767。"],
      ["mouse_button(name, down)", "boolean queued", "通用", "name 为 left、right、middle、x1 或 x2。"],
      ["release_all()", "nil", "通用", "清空待发送队列并释放该脚本记录的全部键盘和鼠标按住状态。"]
    ],
    storage: [
      ["get(key, default?)", "value", "通用", "读取脚本私有值；键不存在时返回 default，未传默认值时返回 nil。"],
      ["set(key, value)", "true", "通用", "原子保存 nil、布尔、有限数字、字符串或最多四层的字符串键表。"],
      ["delete(key)", "boolean removed", "通用", "删除键；键存在并成功保存时返回 true，不存在时返回 false。"]
    ],
    log: [
      ["info(message)", "nil", "通用", "写入 INFO 日志和调试输出；单条最多 4096 字节。"],
      ["warn(message)", "nil", "通用", "写入 WARN 日志和调试输出；适合可恢复状态。"],
      ["error(message)", "nil", "通用", "写入 ERROR 日志；记录消息本身不会停止脚本。"]
    ],
    system: [
      ["now_ms()", "integer", "通用", "返回单调系统启动毫秒数，适合冷却计算，不是 Unix 时间。"],
      ["script_id()", "string", "通用", "返回从文件名生成的稳定脚本 ID，也是持久化命名空间名称。"]
    ]
  };

  const namespaceLabel = {
    game: "lunar.game",
    mad_eyes: "lunar.mad_eyes",
    draw: "lunar.draw",
    ui: "lunar.ui",
    input: "lunar.input",
    storage: "lunar.storage",
    log: "lunar.log",
    system: "lunar.system"
  };

  const escapeHtml = (value) => String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

  const slug = (value) => value
    .replace(/\(.*/, "")
    .replaceAll("_", "-")
    .replace(/[^a-z0-9-]/gi, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .toLowerCase();

  function renderApi() {
    document.querySelectorAll("[data-namespace]").forEach((container) => {
      const name = container.dataset.namespace;
      const prefix = namespaceLabel[name];
      const records = api[name] || [];
      container.innerHTML = records.map(([signature, returns, context, description]) => {
        const contextClass = context.toLowerCase() === "通用" ? "common" : context.toLowerCase();
        const searchable = `${prefix}.${signature} ${returns} ${context} ${description}`.toLowerCase();
        return `
          <details class="api-card" id="api-${name}-${slug(signature)}" data-search="${escapeHtml(searchable)}">
            <summary>
              <span class="api-signature"><span class="namespace">${escapeHtml(prefix)}.</span>${escapeHtml(signature)}</span>
              <span class="context-tag ${contextClass}">${escapeHtml(context)}</span>
            </summary>
            <div class="api-details">
              <p>${escapeHtml(description)}</p>
              <div class="api-return"><span>返回</span><code>${escapeHtml(returns)}</code></div>
            </div>
          </details>`;
      }).join("");
    });
  }

  function buildOutline() {
    const outline = document.getElementById("page-outline");
    const sections = [...document.querySelectorAll("main > .doc-section")];
    outline.innerHTML = sections.map((section) =>
      `<a href="#${section.id}" data-target="${section.id}">${escapeHtml(section.dataset.title || section.id)}</a>`
    ).join("");
  }

  function setupSearch() {
    const input = document.getElementById("api-search");
    const result = document.getElementById("search-result");
    const cards = [...document.querySelectorAll(".api-card")];
    const namespaceSections = [...document.querySelectorAll(".namespace-section")];
    const staticSections = [...document.querySelectorAll("main > .doc-section:not(.namespace-section)")];

    const apply = () => {
      const query = input.value.trim().toLowerCase();
      document.body.classList.toggle("searching", query.length > 0);
      let count = 0;
      cards.forEach((card) => {
        const match = !query || card.dataset.search.includes(query);
        card.hidden = !match;
        card.open = Boolean(query && match);
        if (match && query) count += 1;
      });
      namespaceSections.forEach((section) => {
        const hasMatch = [...section.querySelectorAll(".api-card")].some((card) => !card.hidden);
        section.hidden = Boolean(query && !hasMatch);
        section.querySelectorAll(".schema-block, .callout, .key-cloud").forEach((extra) => {
          extra.hidden = Boolean(query);
        });
      });
      staticSections.forEach((section) => { section.hidden = Boolean(query); });
      result.textContent = query ? `找到 ${count} 个 API` : "";
      if (query) window.scrollTo({ top: 0, behavior: "smooth" });
    };

    input.addEventListener("input", apply);
    input.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        input.value = "";
        apply();
        input.blur();
      }
    });
    document.addEventListener("keydown", (event) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        input.focus();
        input.select();
      }
    });
  }

  function setupCopyButtons() {
    const toast = document.getElementById("copy-toast");
    let timer = 0;
    document.querySelectorAll(".copy-button").forEach((button) => {
      button.addEventListener("click", async () => {
        const code = button.closest(".code-window")?.querySelector("pre code")?.textContent || "";
        try {
          await navigator.clipboard.writeText(code);
          button.textContent = "已复制";
          toast.classList.add("show");
          clearTimeout(timer);
          timer = window.setTimeout(() => {
            toast.classList.remove("show");
            button.textContent = "复制";
          }, 1500);
        } catch {
          button.textContent = "选择代码复制";
        }
      });
    });
  }

  function setupMobileNavigation() {
    const menu = document.getElementById("mobile-menu");
    const backdrop = document.getElementById("sidebar-backdrop");
    const close = () => {
      document.body.classList.remove("nav-open");
      menu.setAttribute("aria-expanded", "false");
    };
    menu.addEventListener("click", () => {
      const open = document.body.classList.toggle("nav-open");
      menu.setAttribute("aria-expanded", String(open));
    });
    backdrop.addEventListener("click", close);
    document.querySelectorAll(".side-nav a").forEach((link) => link.addEventListener("click", close));
    window.addEventListener("resize", () => { if (window.innerWidth > 900) close(); });
  }

  function setupScrollSpy() {
    const links = [...document.querySelectorAll(".side-nav a[href^='#'], #page-outline a")];
    const sections = [...document.querySelectorAll("main > .doc-section")];
    const activate = (id) => links.forEach((link) => {
      link.classList.toggle("active", link.getAttribute("href") === `#${id}`);
    });
    const observer = new IntersectionObserver((entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting && !entry.target.hidden)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio);
      if (visible[0]) activate(visible[0].target.id);
    }, { rootMargin: "-15% 0px -68% 0px", threshold: [0, .05, .2] });
    sections.forEach((section) => observer.observe(section));
  }

  renderApi();
  buildOutline();
  setupSearch();
  setupCopyButtons();
  setupMobileNavigation();
  setupScrollSpy();
})();
