import SwiftUI
import AppKit

// MARK: - Core Visuals

struct AcrylicBackground: NSViewRepresentable {
    var radius: CGFloat = 16
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .headerView 
        
        // 核心修复：在原生层应用圆角
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
        
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.layer?.cornerRadius = radius
    }
}

struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. 基础模糊材质
                    Color(NSColor.windowBackgroundColor).opacity(colorScheme == .dark ? 0.3 : 0.5)
                    
                    // 2. 表面液态光泽
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                // 3. 玻璃厚度效果：双层精密描边
                ZStack {
                    // 外层极细深色边框（增强边界感）
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), lineWidth: 0.5)
                    
                    // 内层强反光高光
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.8), // 顶部边缘亮光
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.3)  // 底部微光
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
            )
            // 4. 顶部内发光（让玻璃看起来更厚）
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.15), Color.clear]), startPoint: .top, endPoint: .center))
                    .padding(1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }
}

struct LiquidGlassPaneModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.white.opacity(0.2)),
                alignment: .top
            )
    }
}


enum AppRoute: Equatable {
    case list
    case editor(CommandItem?)
    case addBookmark
    case brewManager
}

enum AppTab: Int, CaseIterable {
    case bookmarks = 0
    case services = 1
    case tools = 2
    
    var title: String {
        switch self {
        case .bookmarks: return "收藏夹"
        case .services: return "服务"
        case .tools: return "工具箱"
        }
    }
    
    var icon: String {
        switch self {
        case .bookmarks: return "bookmark.fill"
        case .services: return "server.rack"
        case .tools: return "briefcase.fill"
        }
    }
}

// MARK: - Drag & Drop Support

struct ReorderableDropDelegate<T: Equatable>: DropDelegate {
    let item: T
    var list: [T]
    @Binding var draggedItem: T?
    var onMove: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item,
              let from = list.firstIndex(of: draggedItem),
              let to = list.firstIndex(of: item)
        else { return }

        if list[to] != draggedItem {
            onMove(IndexSet(integer: from), to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject var viewModel = AppViewModel()
    @State private var currentTab: AppTab = .bookmarks
    @State private var route: AppRoute = .list
    
    @State private var draggedCommand: CommandItem?
    @State private var draggedBookmark: BookmarkItem?
    
    @State private var itemToDelete: CommandItem?
    @State private var showDeleteAlert = false
    @State private var bookmarkToDelete: BookmarkItem?
    @State private var bookmarkToEdit: BookmarkItem?
    
    @State private var newBookmarkUrl = ""
    @State private var showAddBookmark = false
    
    var body: some View {
        ZStack {
            AcrylicBackground(radius: 16)
            
            VStack(spacing: 0) {
                headerView
                contentArea
            }
            
            overlayViews
        }
        .frame(width: 420, height: 600)
        .onAppear { viewModel.checkAllStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStatus"))) { _ in
            viewModel.checkAllStatus()
        }
        .alert(isPresented: $showDeleteAlert) {
            deleteAlert
        }
    }
    
    // Sub-views to fix type-check performance
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.black.opacity(0.05)))
            
            Spacer()
            
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.1)), alignment: .bottom)
    }
    
    private func tabButton(for tab: AppTab) -> some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { currentTab = tab } }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon).font(.system(size: 11))
                if currentTab == tab {
                    Text(tab.title).font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(currentTab == tab ? RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.2)) : nil)
            .foregroundColor(currentTab == tab ? .primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if currentTab == .services {
                LiquidIconButton(icon: "shippingbox") { withAnimation { route = .brewManager } }
                LiquidIconButton(icon: "plus") { withAnimation { route = .editor(nil) } }
            } else if currentTab == .bookmarks {
                LiquidIconButton(icon: viewModel.isBookmarkGridView ? "list.bullet" : "square.grid.2x2") { 
                    withAnimation { viewModel.isBookmarkGridView.toggle(); viewModel.saveViewMode() } 
                }
                LiquidIconButton(icon: "plus") { showAddBookmark = true }
            }
            LiquidIconButton(icon: "sparkles", color: .indigo) { AIChatWindowController.shared.toggle(viewModel: viewModel) }
            LiquidIconButton(icon: "power", color: .red) { NSApplication.shared.terminate(nil) }
        }
    }
    
    @ViewBuilder
    private var contentArea: some View {
        ZStack {
            if currentTab == .services {
                servicesContent
            } else if currentTab == .tools {
                ToolsView(viewModel: viewModel).transition(.opacity)
            } else {
                BookmarkListView(
                    viewModel: viewModel,
                    draggedItem: $draggedBookmark,
                    onDeleteRequest: { bookmarkToDelete = $0; showDeleteAlert = true },
                    onEditRequest: { bookmarkToEdit = $0 }
                ).transition(.opacity)
            }
        }
    }
    
    @ViewBuilder
    private var servicesContent: some View {
        if case .list = route {
            CommandListView(
                viewModel: viewModel,
                draggedItem: $draggedCommand,
                onEdit: { item in withAnimation { route = .editor(item) } },
                onDeleteRequest: { item in itemToDelete = item; showDeleteAlert = true }
            ).transition(AnyTransition.move(edge: .leading))
        } else if case let .editor(item) = route {
            CommandEditView(viewModel: viewModel, item: item, onDismiss: { withAnimation { route = .list } })
                .background(AcrylicBackground())
                .transition(AnyTransition.move(edge: .trailing))
                .zIndex(1)
        } else if case .brewManager = route {
            BrewManagerView(viewModel: viewModel, onDismiss: { withAnimation { route = .list } })
                .background(AcrylicBackground())
                .transition(AnyTransition.move(edge: .trailing))
                .zIndex(1)
        }
    }
    
    @ViewBuilder
    private var overlayViews: some View {
        if showAddBookmark || bookmarkToEdit != nil {
            ZStack {
                Color.black.opacity(0.1).edgesIgnoringSafeArea(.all).onTapGesture { showAddBookmark = false; bookmarkToEdit = nil }
                AddBookmarkDialog(
                    viewModel: viewModel,
                    initialUrl: bookmarkToEdit?.url ?? newBookmarkUrl,
                    editingBookmark: bookmarkToEdit,
                    onCancel: { showAddBookmark = false; bookmarkToEdit = nil; newBookmarkUrl = "" },
                    onAdd: { t, u, i in
                        if let e = bookmarkToEdit { var m = e; m.title = t; m.url = u; m.iconUrl = i; viewModel.updateBookmark(m) }
                        else { viewModel.addBookmark(title: t, url: u, iconUrl: i) }
                        showAddBookmark = false; bookmarkToEdit = nil; newBookmarkUrl = ""
                    }
                ).transition(.scale(scale: 0.9).combined(with: .opacity)).zIndex(2)
            }
        }
        if viewModel.showErrorToast {
            ToastView(message: viewModel.errorMessage) { viewModel.showErrorToast = false }
        }
    }
    
    private var deleteAlert: Alert {
        if currentTab == .services {
            return Alert(title: Text("确认删除?"), message: Text("此操作将永久移除该服务配置。"), primaryButton: .destructive(Text("删除")) {
                if let item = itemToDelete, let idx = viewModel.commands.firstIndex(where: { $0.id == item.id }) { viewModel.deleteCommand(at: IndexSet(integer: idx)) }
            }, secondaryButton: .cancel(Text("取消")))
        } else {
            return Alert(title: Text("移除书签?"), message: Text("确定要移除此书签吗？"), primaryButton: .destructive(Text("移除")) {
                if let item = bookmarkToDelete, let idx = viewModel.bookmarks.firstIndex(where: { $0.id == item.id }) { viewModel.deleteBookmark(at: IndexSet(integer: idx)) }
            }, secondaryButton: .cancel(Text("取消")))
        }
    }
}

// MARK: - Sub-components definitions

struct RightClickDetector: NSViewRepresentable {
    var onRightClick: () -> Void
    var onLeftClick: (() -> Void)? = nil
    func makeNSView(context: Context) -> NSView { RightClickView(onRightClick: onRightClick, onLeftClick: onLeftClick) }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? RightClickView { v.onRightClick = onRightClick; v.onLeftClick = onLeftClick }
    }
    class RightClickView: NSView {
        var onRightClick: () -> Void; var onLeftClick: (() -> Void)?
        init(onRightClick: @escaping () -> Void, onLeftClick: (() -> Void)?) { self.onRightClick = onRightClick; self.onLeftClick = onLeftClick; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func rightMouseDown(with e: NSEvent) { onRightClick() }
        override func mouseDown(with e: NSEvent) { if let l = onLeftClick { l() } else { super.mouseDown(with: e) } }
    }
}

struct LiquidIconButton: View {
    let icon: String; var color: Color = .primary; let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Button(action: action) {
            ZStack {
                // 1. 材质
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .background(.ultraThinMaterial, in: Circle())
                
                // 2. 内部液态渐变
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.4), Color.clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color.opacity(0.9))
                    .shadow(color: color.opacity(0.2), radius: 2, x: 0, y: 0)
            }
            .frame(width: 30, height: 30)
            .overlay(
                ZStack {
                    // 外层微阴影边界
                    Circle().stroke(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1), lineWidth: 0.5)
                    // 内层强反光高光
                    Circle().strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }.buttonStyle(PlainButtonStyle())
    }
}

struct LiquidIconContainer<Content: View>: View {
    let size: CGFloat; let content: Content
    @Environment(\.colorScheme) var colorScheme
    init(size: CGFloat, @ViewBuilder content: () -> Content) { self.size = size; self.content = content() }
    var body: some View {
        ZStack { 
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            content 
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8
                )
        )
    }
}

struct BookmarkIconView: View {
    let iconUrl: String?
    var body: some View {
        if let urlStr = iconUrl {
            if urlStr.hasPrefix("file://"), let url = URL(string: urlStr), let img = NSImage(contentsOf: url) { Image(nsImage: img).resizable().aspectRatio(contentMode: .fit) }
            else if let u = URL(string: urlStr) { AsyncImage(url: u) { p in if let i = p.image { i.resizable().aspectRatio(contentMode: .fit) } else { defaultIcon } } }
            else { defaultIcon }
        } else { defaultIcon }
    }
    private var defaultIcon: some View { Image(systemName: "globe").font(.system(size: 14)).foregroundColor(.blue.opacity(0.7)) }
}

struct LiquidActionButton: View {
    let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack { Circle().fill(.ultraThinMaterial); Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(color) }
            .frame(width: 32, height: 32).overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        }.buttonStyle(PlainButtonStyle())
    }
}

// Reuse from ToolsView concepts but local for ContentView
struct NeumorphicInputBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

struct NeumorphicTextField: View {
    let icon: String; let title: String; @Binding var text: String; var placeholder: String; var isCode: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.6)).padding(.leading, 4)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(.secondary.opacity(0.5)).font(.system(size: 12)).frame(width: 16)
                TextField(placeholder, text: $text).textFieldStyle(PlainTextFieldStyle()).font(isCode ? .system(.caption, design: .monospaced) : .system(.body))
            }.padding(12).background(NeumorphicInputBackground())
        }
    }
}

// Components from previous logic...
struct CommandListView: View {
    @ObservedObject var viewModel: AppViewModel; @Binding var draggedItem: CommandItem?; var onEdit: (CommandItem) -> Void; var onDeleteRequest: (CommandItem) -> Void
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                if viewModel.commands.isEmpty { EmptyStateView { } }
                else {
                    ForEach(viewModel.commands) { cmd in
                        NeumorphicCard(command: cmd, draggedItem: $draggedItem, isOn: Binding(get: { viewModel.commandStates[cmd.id] ?? false }, set: { _ in viewModel.toggle(command: cmd) }), isLoading: viewModel.isLoading[cmd.id] ?? false, onEdit: { onEdit(cmd) }, onDelete: { onDeleteRequest(cmd) })
                            .onDrop(of: [.text], delegate: ReorderableDropDelegate(item: cmd, list: viewModel.commands, draggedItem: $draggedItem, onMove: viewModel.moveCommand))
                    }
                }
            }.padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}

struct NeumorphicCard: View {
    let command: CommandItem; @Binding var draggedItem: CommandItem?; @Binding var isOn: Bool; var isLoading: Bool; var onEdit: () -> Void; var onDelete: () -> Void
    @State private var offset: CGFloat = 0; @State private var isSwiped = false; @State private var showMenu = false
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.3))
                
                LiquidIconContainer(size: 32) {
                    Image(systemName: command.iconName).font(.system(size: 14)).foregroundColor(isOn ? .blue : .secondary.opacity(0.7))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.name).font(.system(size: 13, weight: .bold)).foregroundColor(.primary.opacity(0.9))
                    if !command.description.isEmpty { Text(command.description).font(.system(size: 10)).foregroundColor(.secondary.opacity(0.6)) }
                }
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.5) } else { Toggle("", isOn: $isOn).toggleStyle(SwitchToggleStyle(tint: .blue)).labelsHidden().scaleEffect(0.7) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Sheen Layer
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(
                ZStack {
                    // Outer border
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), lineWidth: 0.5)
                    // Inner glow edge
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.1), Color.clear, Color.white.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 3)
            .offset(x: offset)
            .overlay(RightClickDetector(onRightClick: { showMenu = true }, onLeftClick: { if isSwiped { withAnimation { offset = 0; isSwiped = false } } }))
            .overlay(HStack { Color.white.opacity(0.001).frame(width: 30).onDrag { self.draggedItem = command; return NSItemProvider(object: command.id.uuidString as NSString) }; Spacer() })
            .popover(isPresented: $showMenu, arrowEdge: .bottom) { BookmarkContextMenu(onEdit: onEdit, onDelete: onDelete, showMenu: $showMenu) }
            .simultaneousGesture(DragGesture(minimumDistance: 25).onChanged { v in if abs(v.translation.width) > abs(v.translation.height) * 2 { offset = isSwiped ? v.translation.width - 90 : v.translation.width } }
                .onEnded { v in withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { if v.translation.width < -30 { offset = -90; isSwiped = true } else { offset = 0; isSwiped = false } } })
            
            if isSwiped { HStack(spacing: 12) { LiquidActionButton(icon: "slider.horizontal.3", color: .indigo) { withAnimation { offset = 0; isSwiped = false }; onEdit() }; LiquidActionButton(icon: "trash.fill", color: .orange) { withAnimation { offset = 0; isSwiped = false }; onDelete() } }.padding(.trailing, 12) }
        }
    }
}

struct BookmarkListView: View {
    @ObservedObject var viewModel: AppViewModel; @Binding var draggedItem: BookmarkItem?; var onDeleteRequest: (BookmarkItem) -> Void; var onEditRequest: (BookmarkItem) -> Void
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    var body: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.bookmarks.isEmpty { VStack { Image(systemName: "bookmark.slash").font(.largeTitle); Text("暂无书签") }.padding(.top, 60).foregroundColor(.secondary) }
            else if viewModel.isBookmarkGridView { LazyVGrid(columns: columns, spacing: 16) { ForEach(viewModel.bookmarks) { item in BookmarkCard(item: item, onDelete: { onDeleteRequest(item) }, onEdit: { onEditRequest(item) }).onDrag { self.draggedItem = item; return NSItemProvider(object: item.id.uuidString as NSString) }.onDrop(of: [.text], delegate: ReorderableDropDelegate(item: item, list: viewModel.bookmarks, draggedItem: $draggedItem, onMove: viewModel.moveBookmark)) } }.padding(16) }
            else { LazyVStack(spacing: 10) { ForEach(viewModel.bookmarks) { item in BookmarkRow(item: item, draggedItem: $draggedItem, onDelete: { onDeleteRequest(item) }, onEdit: { onEditRequest(item) }).onDrop(of: [.text], delegate: ReorderableDropDelegate(item: item, list: viewModel.bookmarks, draggedItem: $draggedItem, onMove: viewModel.moveBookmark)) } }.padding(16) }
        }
    }
}

struct BookmarkCard: View {
    let item: BookmarkItem; var onDelete: () -> Void; var onEdit: () -> Void; @State private var showMenu = false
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(spacing: 8) { 
            LiquidIconContainer(size: 44) { BookmarkIconView(iconUrl: item.iconUrl).frame(width: 24, height: 24).cornerRadius(4) }
            Text(item.title).font(.system(size: 11, weight: .bold)).lineLimit(1).foregroundColor(.primary.opacity(0.85)) 
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(
            ZStack { 
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.3), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing)) 
            }
        )
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            }
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(RightClickDetector(onRightClick: { showMenu = true }, onLeftClick: { if let url = URL(string: item.url) { NSWorkspace.shared.open(url) } }))
        .popover(isPresented: $showMenu) { BookmarkContextMenu(onEdit: onEdit, onDelete: onDelete, showMenu: $showMenu) }
    }
}

struct BookmarkRow: View {
    let item: BookmarkItem; @Binding var draggedItem: BookmarkItem?; var onDelete: () -> Void; var onEdit: () -> Void; @State private var offset: CGFloat = 0; @State private var isSwiped = false; @State private var showMenu = false
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) { 
                Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.2))
                LiquidIconContainer(size: 32) { BookmarkIconView(iconUrl: item.iconUrl).frame(width: 18, height: 18) }
                VStack(alignment: .leading, spacing: 2) { 
                    Text(item.title).font(.system(size: 13, weight: .bold)).foregroundColor(.primary.opacity(0.9))
                    Text(URL(string: item.url)?.host ?? item.url).font(.system(size: 10)).foregroundColor(.secondary.opacity(0.7)) 
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.1)) 
            }
            .padding(10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .offset(x: offset).overlay(RightClickDetector(onRightClick: { showMenu = true }, onLeftClick: { if isSwiped { withAnimation { offset = 0; isSwiped = false } } else if let url = URL(string: item.url) { NSWorkspace.shared.open(url) } }))
            .overlay(HStack { Color.white.opacity(0.001).frame(width: 30).onDrag { self.draggedItem = item; return NSItemProvider(object: item.id.uuidString as NSString) }; Spacer() })
            .popover(isPresented: $showMenu) { BookmarkContextMenu(onEdit: onEdit, onDelete: onDelete, showMenu: $showMenu) }
            .simultaneousGesture(DragGesture(minimumDistance: 25).onChanged { v in if abs(v.translation.width) > abs(v.translation.height) * 2 { offset = isSwiped ? v.translation.width - 90 : v.translation.width } }.onEnded { v in withAnimation { if v.translation.width < -30 { offset = -90; isSwiped = true } else { offset = 0; isSwiped = false } } })
            if isSwiped { HStack(spacing: 12) { LiquidActionButton(icon: "slider.horizontal.3", color: .indigo) { withAnimation { offset = 0; isSwiped = false }; onEdit() }; LiquidActionButton(icon: "trash.fill", color: .orange) { withAnimation { offset = 0; isSwiped = false }; onDelete() } }.padding(.trailing, 12) }
        }
    }
}

struct BookmarkContextMenu: View {
    var onEdit: () -> Void; var onDelete: () -> Void; @Binding var showMenu: Bool
    var body: some View {
        VStack(spacing: 2) {
            Button(action: { showMenu = false; onEdit() }) { HStack { Image(systemName: "slider.horizontal.3"); Text("个性化配置"); Spacer() }.padding(8).font(.system(size: 11)) }.buttonStyle(NeumorphicMenuButtonStyle())
            Divider().opacity(0.1)
            Button(action: { showMenu = false; onDelete() }) { HStack { Image(systemName: "trash"); Text("移出收藏夹"); Spacer() }.padding(8).font(.system(size: 11)).foregroundColor(.orange) }.buttonStyle(NeumorphicMenuButtonStyle())
        }.padding(4).frame(width: 130).background(.ultraThinMaterial).cornerRadius(12)
    }
}

struct NeumorphicMenuButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.background(configuration.isPressed ? Color.black.opacity(0.05) : Color.clear).cornerRadius(6) } }

struct AddBookmarkDialog: View {
    @ObservedObject var viewModel: AppViewModel; @State var url: String; var editingBookmark: BookmarkItem?; var onCancel: () -> Void; var onAdd: (String, String, String?) -> Void
    @State private var step: Int = 0; @State private var title: String = ""; @State private var iconUrl: String? = nil; @State private var isFetching: Bool = false
    init(viewModel: AppViewModel, initialUrl: String, editingBookmark: BookmarkItem? = nil, onCancel: @escaping () -> Void, onAdd: @escaping (String, String, String?) -> Void) {
        self.viewModel = viewModel; self._url = State(initialValue: initialUrl); self.editingBookmark = editingBookmark; self.onCancel = onCancel; self.onAdd = onAdd
        if let e = editingBookmark { self._step = State(initialValue: 1); self._title = State(initialValue: e.title); self._iconUrl = State(initialValue: e.iconUrl) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(editingBookmark != nil ? "编辑书签" : (step == 0 ? "添加书签" : "确认信息")).font(.system(size: 14, weight: .bold)); Spacer(); if step == 1 && editingBookmark == nil { Button("修改链接") { withAnimation { step = 0 } }.font(.system(size: 11)) } }.padding(20)
            VStack(spacing: 16) {
                if step == 0 { NeumorphicTextField(icon: "link", title: "网站链接", text: $url, placeholder: "github.com"); if isFetching { ProgressView().scaleEffect(0.5) } }
                else { HStack { LiquidIconContainer(size: 44) { BookmarkIconView(iconUrl: iconUrl).frame(width: 24, height: 24) }; VStack(alignment: .leading) { Text("网页图标已就绪").font(.caption.bold()); Text(iconUrl == nil ? "使用默认图标" : "已获取图标").font(.caption2) }; Spacer() }; NeumorphicTextField(icon: "tag", title: "标题", text: $title, placeholder: "标题"); NeumorphicTextField(icon: "link", title: "链接", text: $url, placeholder: "url") }
                HStack { Button("取消", action: onCancel); Spacer(); Button(step == 0 ? "下一步" : "保存") { if step == 0 { fetch() } else { onAdd(title, url, iconUrl) } }.disabled(url.isEmpty || isFetching) }.padding(.top, 10)
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.frame(width: 320).background(.ultraThinMaterial).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2)))
    }
    func fetch() { isFetching = true; viewModel.fetchMetadata(url: url) { m in withAnimation { isFetching = false; title = m.title ?? ""; iconUrl = m.iconUrl; step = 1 } } }
}

struct CommandEditView: View {
    @ObservedObject var viewModel: AppViewModel; var item: CommandItem?; var onDismiss: () -> Void
    enum Mode: Int { case brew = 0; case custom = 1 }; @State private var mode: Mode = .brew
    @State private var brewServices: [BrewService] = []; @State private var isLoadingBrew = false
    @State private var name = ""; @State private var desc = ""; @State private var icon = "terminal"
    @State private var startCmd = ""; @State private var stopCmd = ""; @State private var checkCmd = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) { HStack { Image(systemName: "chevron.left"); Text("返回") }.font(.system(size: 14)).foregroundColor(.secondary) }.buttonStyle(PlainButtonStyle())
                Spacer(); Text(item == nil ? "添加服务" : "编辑服务").font(.system(size: 15, weight: .bold)); Spacer()
                if item == nil { Picker("", selection: $mode) { Text("Brew").tag(Mode.brew); Text("Custom").tag(Mode.custom) }.pickerStyle(SegmentedPickerStyle()).frame(width: 120).onChange(of: mode) { _ in if mode == .brew { loadBrew() } } }
            }.padding(16).modifier(LiquidGlassPaneModifier())
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Brew Selector
                    if mode == .brew && item == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HOMEBREW 服务").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 4)
                            Menu { ForEach(brewServices) { s in Button(s.name) { applyBrew(s) } } } label: {
                                HStack {
                                    Text(name.isEmpty ? "点击选择服务..." : name).foregroundColor(name.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down").foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(NeumorphicInputBackground())
                            }
                            .menuStyle(BorderlessButtonMenuStyle())
                        }
                    }
                    
                    // Identity Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle").foregroundColor(.blue)
                            Text("基础信息").font(.system(size: 12, weight: .bold)).foregroundColor(.primary.opacity(0.8))
                        }
                        
                        VStack(spacing: 12) {
                            NeumorphicTextField(icon: "tag", title: "名称", text: $name, placeholder: "服务名称 (如 Redis)")
                            NeumorphicTextField(icon: "text.alignleft", title: "描述", text: $desc, placeholder: "简短描述")
                            
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("图标").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.6)).padding(.leading, 4)
                                    LiquidIconContainer(size: 44) {
                                        Image(systemName: icon).font(.system(size: 20)).foregroundColor(.blue)
                                    }
                                }
                                ExpandedIconPicker(selectedIcon: $icon)
                            }
                        }
                    }
                    .padding(16)
                    .modifier(LiquidGlassModifier()) // Glass Panel 1
                    
                    // Command Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "terminal").foregroundColor(.orange)
                            Text("执行指令").font(.system(size: 12, weight: .bold)).foregroundColor(.primary.opacity(0.8))
                        }
                        
                        VStack(spacing: 12) {
                            NeumorphicTextField(icon: "play.fill", title: "启动 (Start)", text: $startCmd, placeholder: "brew services start ...", isCode: true)
                            NeumorphicTextField(icon: "stop.fill", title: "停止 (Stop)", text: $stopCmd, placeholder: "brew services stop ...", isCode: true)
                            NeumorphicTextField(icon: "waveform.path.ecg", title: "健康检查 (Check)", text: $checkCmd, placeholder: "pgrep ...", isCode: true)
                        }
                    }
                    .padding(16)
                    .modifier(LiquidGlassModifier()) // Glass Panel 2
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            
            // Footer
            HStack { Spacer(); Button("保存配置") { save() }.buttonStyle(LiquidPillButtonStyle()).disabled(name.isEmpty || startCmd.isEmpty) }.padding(16).modifier(LiquidGlassPaneModifier())
        }.onAppear { setup() }
    }
    
    // Sub-components for cleaner code
    struct ExpandedIconPicker: View {
        @Binding var selectedIcon: String
        let columns = [GridItem(.adaptive(minimum: 34), spacing: 8)]
        var body: some View {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(presetIcons, id: \.self) { i in
                        Button(action: { selectedIcon = i }) {
                            Image(systemName: i).font(.system(size: 14))
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8).fill(selectedIcon == i ? Color.blue : Color.black.opacity(0.05)))
                                .foregroundColor(selectedIcon == i ? .white : .primary.opacity(0.7))
                        }.buttonStyle(PlainButtonStyle())
                    }
                }.padding(4)
            }
            .frame(height: 100)
            .background(NeumorphicInputBackground())
        }
    }
    
    func setup() { if let e = item { mode = .custom; name = e.name; desc = e.description; icon = e.iconName; startCmd = e.startCommand; stopCmd = e.stopCommand; checkCmd = e.checkCommand } else if mode == .brew { loadBrew() } }
    func loadBrew() { isLoadingBrew = true; DispatchQueue.global().async { let s = ShellRunner.listBrewServices(); DispatchQueue.main.async { self.brewServices = s; self.isLoadingBrew = false } } }
    func applyBrew(_ s: BrewService) { name = s.name; desc = "Brew Service"; startCmd = "/opt/homebrew/bin/brew services start \(s.name)"; stopCmd = "/opt/homebrew/bin/brew services stop \(s.name)"; checkCmd = "pgrep \(s.name)"; icon = IconMatcher.suggest(for: s.name) }
    func save() { let n = CommandItem(id: item?.id ?? UUID(), name: name, description: desc, iconName: icon, startCommand: startCmd, stopCommand: stopCmd, checkCommand: checkCmd); if item != nil { viewModel.updateCommand(n) } else { viewModel.addCommand(n) }; onDismiss() }
}

struct LiquidPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .bold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 8)
            .background(Capsule().fill(Color.blue.opacity(0.8)).overlay(Capsule().stroke(Color.white.opacity(0.2)))).shadow(color: Color.blue.opacity(0.2), radius: 3).scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct EmptyStateView: View { 
    let onAdd: () -> Void
    var body: some View { 
        VStack(spacing: 12) { 
            Image(systemName: "tray.fill").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
            Text("空空如也").font(.system(size: 14)).foregroundColor(.secondary) 
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    } 
}

struct ToastView: View { 
    let message: String; let onDismiss: () -> Void
    var body: some View { 
        VStack { 
            Spacer()
            HStack {
                Image(systemName: "info.circle.fill")
                Text(message)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            .foregroundColor(.primary)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .onTapGesture(perform: onDismiss)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    } 
}

struct IconPicker: View {
    @Binding var selectedIcon: String; @State private var isExpanded = false; let columns = [GridItem(.adaptive(minimum: 30), spacing: 8)]
    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) { LazyVGrid(columns: columns, spacing: 8) { ForEach(presetIcons, id: \.self) { i in Button(action: { selectedIcon = i }) { Image(systemName: i).font(.system(size: 14)).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 6).fill(selectedIcon == i ? Color.blue : Color.white.opacity(0.1))).foregroundColor(selectedIcon == i ? .white : .primary) }.buttonStyle(PlainButtonStyle()) } }.padding(4) }
            .frame(height: isExpanded ? 150 : 40).background(Color.black.opacity(0.05)).cornerRadius(8)
            Button(isExpanded ? "收起" : "展开图标库") { withAnimation { isExpanded.toggle() } }.font(.system(size: 10)).foregroundColor(.blue)
        }
    }
}

