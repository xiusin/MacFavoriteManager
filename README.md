# StatusCmdManager

一个精致的 macOS 状态栏常驻应用，集成了 **本地服务管理 (Shell控制)** 与 **智能网页收藏夹** 功能。

## 🌟 核心功能

- **服务控制**：通过 Shell 命令管理本地服务（如 MySQL, Redis, Nginx），支持实时状态检查。
- **智能收藏夹**：收藏常用网页，支持自动抓取标题与图标（Favicon），并进行本地持久化缓存。
- **拟物化交互**：全局采用 Neumorphism (拟物化) 设计语言，配合极简的毛玻璃视觉效果。
- **高效操作**：
  - **拖拽排序**：长按列表项即可调整顺序。
  - **侧滑菜单**：向左滑动列表项快速呼出配置与删除按钮。
  - **自定义菜单**：鼠标右键点击弹出深度定制的拟物化 Popover 菜单。

## 🛠 构建与运行

项目无需任何第三方依赖，基于 Swift 5.5+ 和 SwiftUI 开发。

```bash
# 赋予执行权限
chmod +x build.sh

# 编译并打包成 .app
./build.sh

# 启动应用
open build/StatusCmdManager.app
```

## 📂 项目结构

- `Sources/StatusCmdManager/Main.swift`: 应用入口，处理状态栏 (NSStatusItem) 与 Popover。
- `Sources/StatusCmdManager/Model.swift`: 数据模型、Shell 执行器及网页元数据抓取逻辑。
- `Sources/StatusCmdManager/ViewModel.swift`: 业务逻辑、持久化及状态管理。
- `Sources/StatusCmdManager/ContentView.swift`: 主 UI 实现，包含拟物化组件库。

---
*欲了解详细开发规范，请阅读 [DOCS/DEVELOPER_GUIDE.md](./DOCS/DEVELOPER_GUIDE.md)*
