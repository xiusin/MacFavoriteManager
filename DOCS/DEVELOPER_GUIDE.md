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
  - **Indigo (靛蓝)** 用于主要操作/配置（个性化配置）。
  - **Orange (琥珀色)** 用于警告/删除（移出收藏夹）。
  - 文本多使用 `.secondary.opacity(0.8)` 或更小字体（9-12pt）以保持高级感。

### 2. 紧凑性 (Compactness)
- 列表项高度需保持精致，图标容器标准为 **28x28**，内部图标 **16x16**。
- 列表项垂直间距标准为 **6px**。
- 弹出菜单（Popover）宽度固定为 **110-120px**，字体 **10.5pt**。

### 3. 毛玻璃 (Glassmorphism)
- 所有的浮层（菜单、对话框、Header）必须使用 `.ultraThinMaterial` 背景。
- 必须配合 0.5px 的半透明白色边框 (`.overlay(RoundedRectangle(...).stroke(...))`)。

## ⌨️ 技术架构 (Architecture)

- **环境**：Target macOS 12.0+。
- **数据流**：严格遵守 MVVM。`AppViewModel` 是唯一的真相来源。
- **持久化**：使用 `UserDefaults` 存储 JSON 编码的结构体。
- **图标缓存**：网页图标抓取后必须下载到 `Application Support/StatusCmdManager/Icons` 并引用本地路径 `file://`。

## 🖱 交互协议与手势处理 (Interaction & Gestures)

这是本项目最复杂的逻辑点，修改时需极其谨慎：

### 1. 拖拽重排 (Drag & Drop)
- **实现方式**：在列表项左侧覆盖一个 **30px 宽的透明矩形** (`Color.white.opacity(0.001)`)。
- **触发点**：`.onDrag` 必须绑定在这个透明感应区上，而不是整个卡片。
- **稳定性**：这种“专用感应区”方案是解决 `ScrollView` 内部多手势冲突的唯一稳定解。

### 2. 侧滑菜单 (Swipe Actions)
- **触发**：在非感应区进行横向滑动。
- **参数**：使用 `simultaneousGesture` 配合 `DragGesture(minimumDistance: 25)`。
- **判定逻辑**：`abs(width) > abs(height) * 2`（确保横向意图明显时才触发）。

### 3. 右键菜单 (Context Menu)
- **禁用原生**：严禁使用 `.contextMenu { ... }` 装饰器。
- **自定义实现**：使用 `RightClickDetector` (NSViewRepresentable) 捕获右键，并弹出基于 `.popover` 的拟物化菜单。

## ⚠️ 避坑指南
- **不要使用 `List`**：`List` 在 macOS 12 下会强制带入背景色和内边距，且难以定制拟物化间隔。请始终使用 `ScrollView` + `LazyVStack`。
- **不要使用 `.onLongPressGesture`**：长按会拦截系统的拖拽识别。所有的次要操作必须通过 **右键** 或 **侧滑** 触发。
- **按钮穿透**：侧滑后的拟物化按钮（`NeumorphicActionButton`）应位于 `ZStack` 顶层，并使用 `onTapGesture` 确保在滑动偏移后依然可点击。

## 🤖 给 Agent 的操作指令
- **修改图标**：检查 `Model.swift` 中的 `IconMatcher` 映射逻辑及 `iconLibrary`。
- **添加组件**：复用 `NeumorphicInputBackground` 和 `NeumorphicTextField` 以保持输入框风格统一。
- **重构逻辑**：任何涉及列表项手势的修改，必须同时在 `NeumorphicCard` (服务) 和 `BookmarkRow` (书签) 中同步。