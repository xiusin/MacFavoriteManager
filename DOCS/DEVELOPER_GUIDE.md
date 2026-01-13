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
  - **Orange (琥珀色)** 用于警告/删除（移出收藏夹、清空剪贴板）。
  - 文本多使用 `.secondary.opacity(0.8)` 或更小字体（9-12pt）以保持高级感。

### 2. 紧凑性 (Compactness)
- 列表项高度需保持精致，图标容器标准为 **28x28**，内部图标 **16x16**。
- 工具箱内的输入框（如搜索、JSON 输入）与操作按钮高度应统一保持在 **32px**。
- 列表项垂直间距标准为 **6px**。
- 弹出菜单（Popover）宽度固定为 **110-120px**，字体 **10.5pt**。

### 3. 毛玻璃 (Glassmorphism)
- 所有的浮层（菜单、对话框、Header）必须使用 `.ultraThinMaterial` 背景。
- 必须配合 0.5px 的半透明白色边框 (`.overlay(RoundedRectangle(...).stroke(...))`)。

## ⌨️ 技术架构 (Architecture)

- **环境**：Target macOS 12.0+。
- **数据流**：严格遵守 MVVM。`AppViewModel` 是唯一的真相来源。
- **剪贴板管理**：
  - **自动清洗**：所有进入剪贴板的内容均经过首尾空格/换行去除。
  - **动态去重**：重复内容会自动置顶，不产生冗余记录。
  - **有效性过滤**：忽略长度小于 4 的短文本或纯标点内容。
  - **来源追踪**：利用 `NSWorkspace` 实时获取产生剪贴板数据的应用图标。
- **热键系统**：
  - **触发**：`Option + Space`。
  - **实现**：同时开启 `GlobalMonitor` 和 `LocalMonitor` 以确保在任何应用（包括本应用）活跃时都能响应。
  - **权限**：依赖系统 **辅助功能 (Accessibility)** 权限。利用 `AXIsProcessTrustedWithOptions` 触发系统授权弹窗。
- **窗口管理**：
  - **浮窗 (FloatingWindow)**：无边框设计，支持键盘 Up/Down/Enter 选择与粘贴。
  - **详情窗 (DetailWindow)**：现代无边框设计 (`fullSizeContentView`)，配合 `AcrylicBackground` (高斯模糊) 实现沉浸式视图。

## 🖱 交互协议与手势处理 (Interaction & Gestures)

这是本项目最复杂的逻辑点，修改时需极其谨慎：

### 1. 模拟粘贴 (Paste Simulation)
- **挑战**：macOS 限制直接向非活跃应用注入按键。
- **解决方案**：执行粘贴前必须调用 `NSApp.hide(nil)` 隐藏本应用并释放焦点。
- **关键参数**：必须保持 **0.3s** 的延迟等待系统焦点转换完成，否则模拟的 `Command+V` 会失效。

### 2. 拖拽重排 (Drag & Drop)
- **实现方式**：在列表项左侧覆盖一个 **30px 宽的透明矩形** (`Color.white.opacity(0.001)`)。
- **触发点**：`.onDrag` 必须绑定在这个透明感应区上，而不是整个卡片。
- **稳定性**：这种“专用感应区”方案是解决 `ScrollView` 内部多手势冲突的唯一稳定解。

### 3. 侧滑菜单 (Swipe Actions)
- **触发**：在非感应区进行横向滑动。
- **参数**：使用 `simultaneousGesture` 配合 `DragGesture(minimumDistance: 25)`。
- **判定逻辑**：`abs(width) > abs(height) * 2`（确保横向意图明显时才触发）。

### 4. 右键菜单 (Context Menu)
- **禁用原生**：严禁使用 `.contextMenu { ... }` 装饰器。
- **自定义实现**：使用 `RightClickDetector` (NSViewRepresentable) 捕获右键，并弹出基于 `.popover` 的拟物化菜单。

## ⚠️ 避坑指南
- **不要使用 `List`**：`List` 在 macOS 12 下会强制带入背景色和内边距，且难以定制拟物化间隔。请始终使用 `ScrollView` + `LazyVStack`。
- **热键失效**：如果权限已开启但热键不工作，通常是 `GlobalMonitor` 在当前 App 活跃时无法捕获，需检查 `LocalMonitor` 是否正常工作。
- **按钮穿透**：侧滑后的拟物化按钮（`NeumorphicActionButton`）应位于 `ZStack` 顶层，并使用 `onTapGesture` 确保在滑动偏移后依然可点击。

## 🤖 给 Agent 的操作指令
- **修改图标**：检查 `Model.swift` 中的 `IconMatcher` 映射逻辑及 `iconLibrary`。
- **添加组件**：复用 `NeumorphicInputBackground` 和 `NeumorphicTextField` 以保持输入框风格统一。
- **多端同步**：任何对剪贴板列表样式的修改，必须在 `ToolsView.swift` 和 `FloatingWindow.swift` 中同步更新。
