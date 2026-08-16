# godot_project — 幸存者类竞技场 Roguelite

一个 2D 俯视角「类吸血鬼幸存者」（survivors-like）原型：角色自动攻击，玩家只负责走位、
活下去、每次升级从卡片里挑一个能力强化。用 **Godot 4.7.1 stable + GDScript** 实现。

A 2D top-down survivors-like arena roguelite: abilities fire automatically, the player only
moves; every level-up offers an upgrade card. Built with Godot 4.7.1 stable, GDScript only.

## 玩法 / Gameplay

| | |
|---|---|
| 移动 | `WASD` 或方向键 |
| 攻击 | 全自动 —— 剑会自动打最近的敌人，斧头绕着玩家旋转 |
| 目标 | 活到计时器归零；被敌人贴身会持续掉血 |
| 成长 | 敌人死后掉落经验瓶 → 经验条满 → 暂停并弹出升级卡 → 点击选择 |
| 结束 | 血量归零 → Defeat 结算界面；可重开或退出 |

难度随时间递增：每 5 秒 `ArenaTimeManager` 提升一档难度，`EnemyManager` 相应缩短刷怪间隔
（最多快 0.7 秒）。

## 架构 / Architecture

三条主线，彼此通过信号解耦，没有一个全局 God object：

**1. 组件化的战斗（component-based combat）**
攻击方挂 `HitboxComponent`（只带一个 `damage` 数值），受击方挂 `HurtboxComponent` +
`HealthComponent`。伤害结算完全发生在 `HurtboxComponent.on_area_entered` 里 —— 敌人和玩家
共用同一套组件，没有任何 `if is_player` 这种分支。`VialDropComponent` 监听
`HealthComponent.died`，死亡时在 `entities_layer` 里生成经验瓶。

**2. 全局事件总线（autoload `GameEvents`）**
跨系统的通知走 `scenes/autoload/game_events.gd`，避免 UI / 管理器之间互相持有引用：

- `experience_vial_collected` — 经验瓶 → `ExperienceManager`
- `ability_upgrade_added` — `UpgradeManager` → 各个能力控制器（剑靠它把攻击间隔 -10%/层）

**3. 管理器 + 分组查找（managers + groups）**
`scenes/manger/` 下四个管理器各管一件事（时间/难度、刷怪、经验升级、升级卡池）。
场景之间不写死路径，全部用 `global_group` 查找：`player`、`enemy`、`entities_layer`、
`foreground_layer` —— 所以能力脚本可以在完全不认识主场景结构的情况下找到玩家。

```
Main
├── ArenaTimeUI / ExperienceBar      UI（CanvasLayer）
├── ArenaTimeManager                 计时 + 难度递增信号
├── EnemyManager                     环形射线找一个不被墙挡住的刷怪点
├── ExperienceManager                经验累积 / 升级
├── UpgradeManager                   升级卡池 + 弹出选择界面
├── GameCamera                       指数平滑跟随玩家
├── TileMap                          Kenney Tiny Dungeon tileset
├── Entities  (group: entities_layer)   Player / 敌人 / 经验瓶
└── Foreground(group: foreground_layer) 剑、斧等特效实例
```

## 目录 / Layout

```
scenes/
  autoload/       GameEvents 全局事件总线（project.godot 里注册为 autoload）
  component/      可复用组件：health / hitbox / hurtbox / vial_drop
  game_object/    场上实体：player、basic_enemy、experience_vial、game_camera
  ability/        能力本体 + 其控制器（sword、axe）
  manger/         四个管理器（拼写沿用工程内既有目录名）
  ui/             经验条、计时、升级卡、升级界面、结算界面
  main/           主场景 —— run/main_scene 指向这里
resources/        TileSet + 升级配置（AbilityUpgrade 资源）
assets/           游戏实际使用的美术
tools/            g.sh 工具链封装 + 输入映射生成脚本
```

每个实体一个文件夹，`.tscn` / `.gd` / `.png` 放在一起，不用集中式 `scripts/`。

## 运行 / Running

需要 Godot **4.7.1 stable（standard 版，非 .NET）**。所有命令都走 `tools/g.sh`
（里面写死了引擎路径和几个必需的 flag）：

```bash
tools/g.sh play           # 开窗口跑（真正玩）
tools/g.sh editor         # 打开编辑器
tools/g.sh run [frames]   # headless 跑 N 帧后自动退出，用于抓运行时报错
tools/g.sh check          # gdlint + gdformat --check + 逐脚本 parse 检查
tools/g.sh fmt            # gdformat 就地格式化
tools/g.sh import         # 重新导入资源，重建 .godot/
tools/g.sh shot           # 渲染帧到 reports/frames/（4.7 没有 --screenshot 参数）
```

用别的机器 clone 后要改 `tools/g.sh` 顶部的 `GODOT_DIR` / `PY` 两个路径。

**没有进仓库的东西**：`addons/`（测试框架）、`TinnyDungeon/`（Kenney 原始素材包）、
`.godot/`、`reports/`、本机 Claude 配置。项目不依赖它们就能跑。

## 素材 / Credits

美术来自 [Kenney — Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon)（CC0）。

## 已知待办 / Known TODO

- `scenes/manger/` 是 `manager` 的拼写错误，重命名会牵动所有 `.tscn` 的 uid 引用，暂未动。
- `UpgradeManager` 每次升级只发一张卡（`[chosen_upgrade]`），且不去重，同一个能力可能反复出现。
- `VialDropComponent.on_died()` 里的掉落概率分支只写了 `pass`，实际是 100% 掉落。
- `basic_enemy` 的移动放在 `_process` 而不是 `_physics_process`，速度会受帧率影响。
- 几处 `print()` 调试输出还没清掉（`player.gd`、`arena_time_manager.gd`、`sword_ability_controller.gd`）。
