# StatusCmdManager Agent 开发指南

本文档旨在为后续接手的 Agent 提供项目的技术细节、视觉规范及交互协议，以确保代码的延续性与风格的一致性。

## 🎯 核心使命
本应用定位于 **“极客的精致工具”**。每一个像素的偏移、每一个颜色的透明度、每一个动效的阻尼感都经过调优。

## 🎨 视觉规范 (UI Standard)

### 1. Neumorphism (拟物化) 原则
- **基础阴影**：背景色需具有轻微透明度。亮部阴影（左上，白色）与暗部阴影（右下，黑色）结合产生凸起感。
- **凹陷效果**：图标容器通常采用 `ZStack` 实现，背景色比卡片稍深，模拟下凹感。
- **色彩偏好**：
  - 禁用标准纯红/纯蓝。
  - **Indigo (靛蓝)** 用于主要操作/配置。
  - **Orange (琥珀色)** 用于警告/删除。
  - 文本多使用 `.secondary.opacity(0.8)` 以保持高级感。

### 2. 紧凑性 (Compactness)
- 列表项高度需保持精致，图标尺寸标准为 **28x28**，内部图标 **16x16**。
- 列表项间距标准为 **6px**。
- 弹出菜单（Popover）宽度固定为 **110-120px**。

### 3. 毛玻璃 (Glassmorphism)
- 所有的浮层（菜单、对话框、Header）必须使用 `.ultraThinMaterial` 背景。
- 必须配合 0.5px 的半透明白色边框 (`.overlay(RoundedRectangle(...).stroke(...))`)。

## ⌨️ 技术架构 (Architecture)

- **环境**：Target macOS 12.0+。
- **数据流**：严格遵守 MVVM。`AppViewModel` 是唯一的真相来源（Single Source of Truth）。
- **持久化**：使用 `UserDefaults` 存储 JSON 编码的结构体。
- **网络逻辑**：`WebMetadataFetcher` 必须伪装 User-Agent，且支持自动处理重定向和相对路径解析。
- **图标缓存**：网页图标抓取后必须下载到 `Application Support/StatusCmdManager/Icons` 并引用本地路径。

## 🖱 交互协议 (Interaction Protocol)

Agent 在添加新功能或修改现有逻辑时必须遵守以下优先级：
1. **左键短点击**：执行核心动作（跳转网页、切换开关）。
2. **鼠标右键**：显示自定义拟物化 Popover 菜单。
3. **向左侧滑**：显示常用操作托盘（NeumorphicActionButton）。
4. **长按 (0.5s+)**：触发系统拖拽排序（onDrag）。

## ⚠️ 避坑指南
- **不要使用系统右键菜单**：必须使用自定义的 `RightClickDetector` 覆盖层。
- **不要使用 `List`**：除非能解决 macOS 12 下的背景和边距污染问题，否则请优先使用 `ScrollView` + `LazyVStack` 手动实现列表。
- **手势冲突**：`DragGesture` 必须设置 `minimumDistance` (建议 15-20) 且在 `onChanged` 中判断位移方向，以兼容拖拽排序。

## 🤖 给 Agent 的操作指令
当用户要求“增加一个图标”或“修改一个样式”时，请先检查 `Model.swift` 中的 `iconLibrary` 和 `IconMatcher`。
当用户要求“添加新 Tab”时，请确保新 Tab 的 Header 组件与现有 Tab 共享同样的逻辑。
