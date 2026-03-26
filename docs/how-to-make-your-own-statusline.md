# 如何自定义 Claude Code 状态栏

本教程将从零开始，手把手教你创建自定义 Claude Code 状态栏（Status Line）。状态栏是 Claude Code 底部的一条可自定义信息栏，它运行你指定的 shell 脚本，通过 stdin 接收 JSON 会话数据，并将脚本的 stdout 输出展示在界面底部。

本教程包含两个部分：

1. **手动配置** — 直接创建脚本并写入 `settings.json`，适合快速上手
2. **插件方式** — 以本仓库的 `ide-status` 插件为范例，将状态栏封装为可分发的插件

---

## 前置要求

- 已安装 Claude Code CLI
- 已安装 [`jq`](https://jqlang.github.io/jq/)（用于在 shell 脚本中解析 JSON）
- 基本的 Bash 脚本知识

---

## 第一部分：理解状态栏的工作原理

### 数据流

```
Claude Code 会话数据 (JSON) ──→ stdin ──→ 你的脚本 ──→ stdout ──→ 状态栏显示
```

每次状态栏刷新时，Claude Code 会将当前会话的 JSON 数据通过 stdin 传入你的脚本。脚本读取 JSON、提取所需字段、格式化后 `echo` 输出。Claude Code 会把你脚本打印的内容展示在底部。

### 刷新时机

脚本在以下时机运行：
- 每条新的 assistant 消息之后
- 权限模式切换时
- vim 模式切换时

刷新有 300ms 的防抖机制——快速连续变化会合并，脚本只在稳定后执行一次。

### 可用的 JSON 字段

Claude Code 通过 stdin 传入的 JSON 结构如下（列出常用字段）：

**模型与工作区**

- `model.id` / `model.display_name` — 当前模型的标识符和显示名称
- `workspace.current_dir` — 当前工作目录
- `workspace.project_dir` — Claude Code 启动时的目录

**费用与时间**

- `cost.total_cost_usd` — 当前会话的累计 API 费用（美元）
- `cost.total_duration_ms` — 会话总耗时（毫秒）
- `cost.total_api_duration_ms` — 等待 API 响应的总耗时（毫秒）
- `cost.total_lines_added` / `cost.total_lines_removed` — 代码变更行数

**上下文窗口**

- `context_window.used_percentage` — 上下文窗口已用百分比
- `context_window.remaining_percentage` — 上下文窗口剩余百分比
- `context_window.context_window_size` — 上下文窗口最大 token 数
- `context_window.total_input_tokens` — 累计输入 token
- `context_window.total_output_tokens` — 累计输出 token

**速率限制**

- `rate_limits.five_hour.used_percentage` — 5 小时滚动窗口的速率限制使用比例
- `rate_limits.seven_day.used_percentage` — 7 天速率限制使用比例

**其他**

- `session_id` — 会话唯一标识符
- `version` — Claude Code 版本
- `vim.mode` — vim 模式状态（`NORMAL` / `INSERT`），仅启用 vim 模式时存在

完整的 JSON 示例：

```json
{
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/Users/you/project",
    "project_dir": "/Users/you/project"
  },
  "cost": {
    "total_cost_usd": 0.0523,
    "total_duration_ms": 120000,
    "total_api_duration_ms": 8500,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "used_percentage": 42,
    "remaining_percentage": 58,
    "context_window_size": 200000,
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "session_id": "abc123",
  "version": "1.0.80"
}
```

> **注意**：部分字段可能不存在或为 `null`（例如首次 API 调用前 `context_window.current_usage` 为 `null`，`rate_limits` 仅对 Claude.ai 订阅用户可见）。脚本中应使用 `jq` 的 `// 默认值` 语法做兜底处理。

---

## 第二部分：手动创建状态栏

### 步骤 1：编写脚本

创建文件 `~/.claude/statusline.sh`：

```bash
#!/bin/bash
# 从 stdin 读取 Claude Code 传入的 JSON 数据
input=$(cat)

# 使用 jq 提取字段，"// 默认值" 防止 null 报错
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "/"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# 输出状态栏内容 — ${DIR##*/} 只取目录名
echo "[$MODEL] ${DIR##*/} | ctx ${PCT}%"
```

脚本逻辑：
1. `input=$(cat)` — 将 stdin 中的整段 JSON 读入变量
2. `jq -r '.field // fallback'` — 提取字段，`//` 后是 null 时的兜底值
3. `echo` — 输出到 stdout，Claude Code 会渲染这段文本

### 步骤 2：赋予执行权限

```bash
chmod +x ~/.claude/statusline.sh
```

### 步骤 3：写入 settings.json

编辑 `~/.claude/settings.json`，添加 `statusLine` 配置：

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

配置项说明：
- `type` — 固定为 `"command"`，表示运行 shell 命令
- `command` — 脚本路径或内联 shell 命令
- `padding`（可选）— 额外的水平间距（字符数），默认 `0`

保存后，下一次与 Claude Code 交互时状态栏即生效。

### 步骤 4：测试脚本

用模拟数据测试，无需启动 Claude Code：

```bash
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/Users/you/project"},"context_window":{"used_percentage":42}}' | ~/.claude/statusline.sh
```

预期输出：

```
[Opus] project | ctx 42%
```

---

## 第三部分：进阶示例

### 示例 1：带颜色的进度条

使用 ANSI 转义码根据上下文使用率显示不同颜色的进度条：

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf "%.2f")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# ANSI 颜色码
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# 根据使用率选择颜色
if [ "$PCT" -ge 90 ]; then
    COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
    COLOR="$YELLOW"
else
    COLOR="$GREEN"
fi

# 构建 10 格进度条
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

echo -e "[$MODEL] ${COLOR}${BAR}${RESET} ${PCT}% | \$$COST"
```

效果示例：`[Opus] ████░░░░░░ 42% | $0.05`

### 示例 2：多行状态栏 + Git 分支

每个 `echo` 语句输出一行，Claude Code 会将多行分别渲染：

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "/"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf "%.2f")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

# Git 分支检测
BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=" | $(git branch --show-current 2>/dev/null)"
fi

# 时间格式化
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# 第一行：模型 + 目录 + Git 分支
echo -e "${CYAN}[$MODEL]${RESET} ${DIR##*/}${BRANCH}"
# 第二行：上下文 + 费用 + 耗时
echo -e "ctx ${PCT}% | ${YELLOW}\$$COST${RESET} | ${MINS}m ${SECS}s"
```

### 示例 3：IDE 连接检测（来自 ide-status 插件）

本仓库的 `ide-status` 插件展示了如何检测当前连接的 IDE 并显示在状态栏中。以下是其核心脚本 `statusline.sh` 的完整代码与注释：

```bash
#!/bin/bash
# 读取 Claude Code 传入的 JSON
input=$(cat)

# 提取基础字段
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf "%.2f")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# IDE 连接检测
# Claude Code 在 ~/.claude/ide/ 目录下为每个连接的 IDE 创建 .lock 文件
# 每个 lock 文件是 JSON 格式，包含 ideName 字段（如 "VS Code"、"Cursor"）
IDE=""
IDE_DIR="$HOME/.claude/ide"
if [[ -d "$IDE_DIR" ]]; then
    # nullglob 确保没有匹配时数组为空而非包含 glob 字面量
    shopt -s nullglob
    lockfiles=("$IDE_DIR"/*.lock)
    shopt -u nullglob
    for lockfile in "${lockfiles[@]}"; do
        IDE_NAME=$(jq -r '.ideName // empty' "$lockfile" 2>/dev/null)
        [[ -n "$IDE_NAME" ]] && IDE="$IDE_NAME" && break
    done
fi

# 有 IDE 连接时显示 IDE 名称，否则省略
if [[ -n "$IDE" ]]; then
    echo "$IDE · $MODEL · \$$COST · ctx ${PCT}%"
else
    echo "$MODEL · \$$COST · ctx ${PCT}%"
fi
```

关键技术点：
- `~/.claude/ide/*.lock` — Claude Code 为连接的 IDE 维护的锁文件，内含 JSON 元数据
- `shopt -s nullglob` — Bash 选项，使 glob 在无匹配时返回空数组
- `jq -r '.ideName // empty'` — 从锁文件中提取 IDE 名称，`// empty` 表示字段不存在时输出空

### 示例 4：缓存耗时操作

`git status`、`git diff` 等命令在大仓库中较慢。由于状态栏脚本每次刷新都是一个新进程，可以用临时文件做缓存：

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "/"')

CACHE_FILE="/tmp/statusline-git-cache"
CACHE_MAX_AGE=5  # 缓存有效期（秒）

# 判断缓存是否过期
cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] || \
    [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

# 仅在缓存过期时执行 git 命令
if cache_is_stale; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH|$STAGED|$MODIFIED" > "$CACHE_FILE"
    else
        echo "||" > "$CACHE_FILE"
    fi
fi

# 读取缓存
IFS='|' read -r BRANCH STAGED MODIFIED < "$CACHE_FILE"

if [ -n "$BRANCH" ]; then
    echo "[$MODEL] ${DIR##*/} | $BRANCH +$STAGED ~$MODIFIED"
else
    echo "[$MODEL] ${DIR##*/}"
fi
```

> **注意**：缓存文件名必须使用固定路径（如 `/tmp/statusline-git-cache`）。不要使用 `$$` 或 `$PPID`，因为每次脚本执行都是新进程，PID 不同会导致缓存永远无法命中。

---

## 第四部分：将状态栏封装为插件

手动配置只影响本机。如果你想将状态栏分发给其他人使用，可以将其封装为 Claude Code 插件。下面以 `ide-status` 插件为模板，完整演示创建过程。

### 插件目录结构

```
my-statusline/
├── .claude-plugin/
│   └── plugin.json          # 插件元信息
├── hooks/
│   └── hooks.json           # 钩子配置，在 SessionStart 时自动安装状态栏
└── scripts/
    ├── install-statusline.sh # 安装脚本：将 statusLine 配置写入用户 settings
    └── statusline.sh         # 状态栏渲染脚本
```

### 步骤 1：创建 plugin.json

```json
{
  "name": "my-statusline",
  "description": "自定义状态栏插件",
  "version": "1.0.0",
  "author": { "name": "你的名字" }
}
```

### 步骤 2：创建 hooks.json

利用 `SessionStart` 钩子在每次会话启动时执行安装脚本：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

关键说明：
- `SessionStart` — 会话开始或恢复时触发
- `${CLAUDE_PLUGIN_ROOT}` — Claude Code 自动展开为插件安装目录的绝对路径
- `timeout: 5` — 脚本执行超时 5 秒，防止阻塞会话启动

### 步骤 3：创建安装脚本 install-statusline.sh

以下是 `ide-status` 插件的安装脚本，它将 `statusLine` 配置幂等地写入用户的 `settings.json`：

```bash
#!/bin/bash
# 将 statusLine 配置写入用户 settings（若尚未配置）
SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"

# 确保 settings.json 存在
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# 幂等检查：如果已配置 statusLine，直接退出
if jq -e '.statusLine' "$SETTINGS_FILE" > /dev/null 2>&1; then
    exit 0
fi

# 使用 jq 注入 statusLine 配置
# 先写入 .tmp 文件，再 mv 替换，保证原子写入
jq --arg cmd "bash \"$STATUSLINE_SCRIPT\"" \
   '. + {"statusLine": {"type": "command", "command": $cmd}}' \
   "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" \
   && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
```

脚本执行流程：
1. 检查 `~/.claude/settings.json` 是否存在，不存在则创建空 JSON
2. `jq -e '.statusLine'` 检查是否已有 `statusLine` 配置 — 有则退出（幂等）
3. 用 `jq` 向 JSON 中插入 `statusLine` 对象，写入临时文件后 `mv` 替换原文件

### 步骤 4：创建状态栏脚本 statusline.sh

将你想要的状态栏逻辑写入 `scripts/statusline.sh`。这里以 IDE 检测 + 基础信息为例：

```bash
#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf "%.2f")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# IDE 检测
IDE=""
IDE_DIR="$HOME/.claude/ide"
if [[ -d "$IDE_DIR" ]]; then
    shopt -s nullglob
    lockfiles=("$IDE_DIR"/*.lock)
    shopt -u nullglob
    for lockfile in "${lockfiles[@]}"; do
        IDE_NAME=$(jq -r '.ideName // empty' "$lockfile" 2>/dev/null)
        [[ -n "$IDE_NAME" ]] && IDE="$IDE_NAME" && break
    done
fi

if [[ -n "$IDE" ]]; then
    echo "$IDE · $MODEL · \$$COST · ctx ${PCT}%"
else
    echo "$MODEL · \$$COST · ctx ${PCT}%"
fi
```

### 步骤 5：赋予脚本执行权限

```bash
chmod +x scripts/install-statusline.sh
chmod +x scripts/statusline.sh
```

### 步骤 6：本地测试插件

使用 `--plugin-dir` 在当前会话中加载插件（不会持久安装）：

```bash
claude --plugin-dir ./my-statusline
```

如果一切正常，状态栏会在会话启动后出现在界面底部。

### 步骤 7：发布到 Marketplace

如果你想通过 marketplace 分发插件，在 marketplace 的 `marketplace.json` 中添加条目：

```json
{
  "name": "my-statusline",
  "source": "./my-statusline",
  "description": "自定义状态栏插件"
}
```

其他用户即可通过以下命令安装：

```bash
claude plugin install my-statusline@your-marketplace
```

---

## 实用技巧

### 脚本输出规则

- **单行**：一个 `echo` 输出一行，显示在状态栏区域
- **多行**：多个 `echo` 分别渲染为独立行，适合展示更丰富的信息
- **颜色**：使用 ANSI 转义码，如 `\033[32m`（绿色）、`\033[33m`（黄色）、`\033[31m`（红色）、`\033[0m`（重置）
- **链接**：使用 OSC 8 转义序列创建可点击链接（需终端支持，如 iTerm2、Kitty、WezTerm）

### 内联命令（无需脚本文件）

对于简单的状态栏，可以直接在 `settings.json` 中写内联命令：

```json
{
  "statusLine": {
    "type": "command",
    "command": "jq -r '\"[\\(.model.display_name)] ctx \\(.context_window.used_percentage // 0)%\"'"
  }
}
```

### 性能建议

- 状态栏脚本在活跃会话中频繁运行，保持脚本执行速度
- 对耗时操作（`git status`、`git diff`）使用文件缓存，参考[示例 4](#示例-4缓存耗时操作)
- 避免网络请求或磁盘密集操作

### 调试方法

1. **手动测试**：用 `echo '{ JSON }' | ./statusline.sh` 传入模拟数据
2. **调试模式**：`claude --debug` 可查看状态栏脚本的首次执行退出码和 stderr
3. **检查权限**：确认脚本有执行权限 (`chmod +x`)
4. **检查输出**：脚本必须输出到 stdout（不是 stderr），且退出码为 0

---

## 常见问题

**状态栏不显示**
- 原因：脚本无执行权限 → 解决：`chmod +x statusline.sh`
- 原因：`disableAllHooks` 为 `true` → 解决：在 settings.json 中移除该项或设为 `false`

**显示 `--` 或空值**
- 原因：首次 API 调用前字段为 null → 解决：使用 `jq` 的 `// 0` 或 `// "fallback"` 做兜底

**转义字符显示为原始文本**
- 原因：`echo` 未正确处理 → 解决：使用 `echo -e` 或 `printf '%b'` 输出带转义的文本

**状态栏更新慢/卡顿**
- 原因：脚本中有耗时操作 → 解决：使用文件缓存，减少每次执行的开销

**插件安装后状态栏不出现**
- 原因：工作区信任未授权 → 解决：重启 Claude Code 并接受信任提示
