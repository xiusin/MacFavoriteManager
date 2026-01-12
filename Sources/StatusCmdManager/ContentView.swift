import SwiftUI
import AppKit

// MARK: - Core Visuals

struct AcrylicBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .headerView
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct GlassPaneModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.2)), alignment: .top)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.black.opacity(0.05)), alignment: .bottom)
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
    
    var title: String {
        switch self {
        case .bookmarks: return "收藏夹"
        case .services: return "服务控制"
        }
    }
    
    var icon: String {
        switch self {
        case .bookmarks: return "bookmark.fill"
        case .services: return "terminal.fill"
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
    
    // 拖动状态
    @State private var draggedCommand: CommandItem?
    @State private var draggedBookmark: BookmarkItem?
    
    // 删除确认状态
    @State private var itemToDelete: CommandItem?
    @State private var showDeleteAlert = false
    @State private var bookmarkToDelete: BookmarkItem?
    @State private var bookmarkToEdit: BookmarkItem?
    
    // 添加书签状态
    @State private var newBookmarkUrl = ""
    @State private var showAddBookmark = false
    
    var body: some View {
        ZStack {
            ZStack {
                AcrylicBackground()
                Color(NSColor.windowBackgroundColor).opacity(0.4)
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Main Header with Tabs
                HStack {
                    HStack(spacing: 0) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            Button(action: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { currentTab = tab }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 11))
                                    Text(tab.title)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle()) // 确保透明区域也能响应点击
                                .background(
                                    currentTab == tab ? 
                                    Color.black.opacity(0.1) : Color.clear
                                )
                                .foregroundColor(currentTab == tab ? .primary : .secondary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(3)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if currentTab == .services {
                            NeumorphicIconButton(icon: "shippingbox", action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .brewManager }
                            })
                            NeumorphicIconButton(icon: "plus", action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .editor(nil) }
                            })
                        } else {
                            // 布局切换按钮
                            NeumorphicIconButton(
                                icon: viewModel.isBookmarkGridView ? "list.bullet" : "square.grid.2x2",
                                action: { 
                                    withAnimation(.spring()) { 
                                        viewModel.isBookmarkGridView.toggle()
                                        viewModel.saveViewMode()
                                    }
                                }
                            )
                            
                            NeumorphicIconButton(icon: "plus", action: { showAddBookmark = true })
                        }
                        
                        NeumorphicIconButton(icon: "power", color: .red, action: { NSApplication.shared.terminate(nil) })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .modifier(GlassPaneModifier())
                
                // Content Area
                ZStack {
                    if currentTab == .services {
                        if case .list = route {
                            CommandListView(
                                viewModel: viewModel,
                                draggedItem: $draggedCommand,
                                onEdit: { item in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .editor(item) }
                                },
                                onDeleteRequest: { item in
                                    itemToDelete = item
                                    showDeleteAlert = true
                                }
                            )
                            .transition(.move(edge: .leading))
                        }
                        
                        if case let .editor(item) = route {
                            CommandEditView(viewModel: viewModel, item: item, onDismiss: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .list }
                            })
                            .transition(.move(edge: .trailing))
                            .zIndex(1)
                            .background(Color(NSColor.windowBackgroundColor)) // 防止透视重叠
                        }
                        
                        if case .brewManager = route {
                            BrewManagerView(viewModel: viewModel, onDismiss: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .list }
                            })
                            .transition(.move(edge: .trailing))
                            .zIndex(1)
                            .background(Color(NSColor.windowBackgroundColor))
                        }
                    } else {
                        BookmarkListView(
                            viewModel: viewModel,
                            draggedItem: $draggedBookmark,
                            onDeleteRequest: { item in
                                bookmarkToDelete = item
                                showDeleteAlert = true
                            },
                            onEditRequest: { item in
                                bookmarkToEdit = item
                            }
                        )
                        .transition(.opacity)
                    }
                }
            }
            
            // Overlays
            if showAddBookmark || bookmarkToEdit != nil {
                Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
                    .onTapGesture { 
                        showAddBookmark = false
                        bookmarkToEdit = nil
                    }
                
                AddBookmarkDialog(
                    viewModel: viewModel,
                    initialUrl: bookmarkToEdit?.url ?? newBookmarkUrl,
                    editingBookmark: bookmarkToEdit,
                    onCancel: {
                        showAddBookmark = false
                        bookmarkToEdit = nil
                        newBookmarkUrl = ""
                    },
                    onAdd: { title, url, iconUrl in
                        if let existing = bookmarkToEdit {
                            var updated = existing
                            updated.title = title
                            updated.url = url
                            updated.iconUrl = iconUrl
                            viewModel.updateBookmark(updated)
                        } else {
                            viewModel.addBookmark(title: title, url: url, iconUrl: iconUrl)
                        }
                        showAddBookmark = false
                        bookmarkToEdit = nil
                        newBookmarkUrl = ""
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(2)
            }
            
            if viewModel.showErrorToast {
                ToastView(message: viewModel.errorMessage) { viewModel.showErrorToast = false }
            }
        }
        .frame(width: 420, height: 600)
        .onAppear { viewModel.checkAllStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStatus"))) { _ in
            viewModel.checkAllStatus()
        }
        .alert(isPresented: $showDeleteAlert) {
            if currentTab == .services {
                return Alert(
                    title: Text("确认删除?"),
                    message: Text("此操作将永久移除该服务配置，无法撤销。"),
                    primaryButton: .destructive(Text("删除")) {
                        if let item = itemToDelete, let idx = viewModel.commands.firstIndex(where: { $0.id == item.id }) {
                            viewModel.deleteCommand(at: IndexSet(integer: idx))
                        }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            } else {
                return Alert(
                    title: Text("移除书签?"),
                    message: Text("确定要移除此书签吗？"),
                    primaryButton: .destructive(Text("移除")) {
                        if let item = bookmarkToDelete, let idx = viewModel.bookmarks.firstIndex(where: { $0.id == item.id }) {
                            viewModel.deleteBookmark(at: IndexSet(integer: idx))
                        }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
}

// MARK: - Bookmark Views

struct BookmarkListView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var draggedItem: BookmarkItem?
    var onDeleteRequest: (BookmarkItem) -> Void
    var onEditRequest: (BookmarkItem) -> Void
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    var body: some View {
        ScrollView {
            if viewModel.bookmarks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark.slash").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
                    Text("暂无书签").font(.body).foregroundColor(.secondary)
                }
                .padding(.top, 60)
            } else {
                if viewModel.isBookmarkGridView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.bookmarks) { item in
                            BookmarkCard(item: item, onDelete: { onDeleteRequest(item) }, onEdit: { onEditRequest(item) })
                                .onDrag {
                                    self.draggedItem = item
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: ReorderableDropDelegate(
                                    item: item,
                                    list: viewModel.bookmarks,
                                    draggedItem: $draggedItem,
                                    onMove: viewModel.moveBookmark
                                ))
                        }
                    }
                    .padding(16)
                    .transition(.opacity)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.bookmarks) { item in
                            BookmarkRow(
                                item: item,
                                draggedItem: $draggedItem, // 传递绑定
                                onDelete: { onDeleteRequest(item) },
                                onEdit: { onEditRequest(item) }
                            )
                            .onDrop(of: [.text], delegate: ReorderableDropDelegate(
                                item: item,
                                list: viewModel.bookmarks,
                                draggedItem: $draggedItem,
                                onMove: viewModel.moveBookmark
                            ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .transition(.opacity)
                }
            }
        }
    }
}

struct BookmarkRow: View {
    let item: BookmarkItem
    @Binding var draggedItem: BookmarkItem?
    var onDelete: () -> Void
    var onEdit: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // 侧滑状态
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showMenu = false
    private let menuWidth: CGFloat = 90
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 内容层
            HStack(spacing: 10) {
                // 视觉手柄
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.3))
                    .padding(.leading, 2)

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.6), radius: 1, x: -0.5, y: -0.5)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0.5, y: 0.5)
                    BookmarkIconView(iconUrl: item.iconUrl)
                        .frame(width: 16, height: 16)
                }
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundColor(.primary)
                    Text(URL(string: item.url)?.host ?? item.url).font(.system(size: 9)).lineLimit(1).foregroundColor(.secondary.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary.opacity(0.2))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
            .offset(x: offset)
            // 整个区域的点击手势
            .onTapGesture {
                if isSwiped {
                    withAnimation(.spring()) { offset = 0; isSwiped = false }
                } else {
                    if let url = URL(string: item.url) { NSWorkspace.shared.open(url) }
                }
            }
            // 整个区域的右键
            .overlay(
                RightClickDetector { showMenu = true }
            )
            // 左侧 30px 的透明拖拽触发区
            .overlay(
                HStack {
                    Color.white.opacity(0.001)
                        .frame(width: 30)
                        .onDrag {
                            self.draggedItem = item
                            return NSItemProvider(object: item.id.uuidString as NSString)
                        }
                    Spacer()
                }
            )
            .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                BookmarkContextMenu(onEdit: onEdit, onDelete: onDelete, showMenu: $showMenu)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 25) // 增加阈值，防止干扰拖拽排序
                    .onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) * 2 {
                            let translation = value.translation.width
                            if translation < 0 {
                                offset = isSwiped ? translation - menuWidth : translation
                            } else if isSwiped && translation > 0 {
                                offset = translation - menuWidth
                                if offset > 0 { offset = 0 }
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -30 {
                                offset = -menuWidth
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            
            // 操作按钮... (保持不变)
            if offset != 0 || isSwiped {
                HStack(spacing: 10) {
                    NeumorphicActionButton(icon: "slider.horizontal.3", color: .indigo) {
                        withAnimation(.spring()) { offset = 0; isSwiped = false }
                        onEdit()
                    }
                    NeumorphicActionButton(icon: "minus.circle.fill", color: .orange) {
                        withAnimation(.spring()) { offset = 0; isSwiped = false }
                        onDelete()
                    }
                }
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

struct NeumorphicActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.1 : 0.8), radius: 1, x: -1, y: -1)
                .shadow(color: Color.black.opacity(0.15), radius: 1, x: 1, y: 1)
            
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
        }
        .frame(width: 30, height: 30)
        .contentShape(Circle())
        .onTapGesture {
            action()
        }
    }
}

// 抽取图标显示逻辑以重用
struct BookmarkIconView: View {
    let iconUrl: String?
    
    var body: some View {
        if let iconUrl = iconUrl {
            if iconUrl.hasPrefix("file://"), let localUrl = URL(string: iconUrl) {
                if let nsImage = NSImage(contentsOf: localUrl) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    DefaultIcon()
                }
            } else if let u = URL(string: iconUrl) {
                AsyncImage(url: u) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        DefaultIcon()
                    } else {
                        ProgressView().scaleEffect(0.4)
                    }
                }
            } else {
                DefaultIcon()
            }
        } else {
            DefaultIcon()
        }
    }
    
    func DefaultIcon() -> some View {
        Image(systemName: "globe").font(.system(size: 14)).foregroundColor(.blue.opacity(0.7))
    }
}

// 抽取 ContextMenu 以重用
struct BookmarkContextMenu: View {
    var onEdit: () -> Void
    var onDelete: () -> Void
    @Binding var showMenu: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: {
                showMenu = false
                onEdit()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundColor(.indigo.opacity(0.8))
                    Text("个性化配置")
                        .font(.system(size: 10.5, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(NeumorphicMenuButtonStyle())
            
            Divider().opacity(0.05).padding(.horizontal, 4)
            
            Button(action: {
                showMenu = false
                onDelete()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.8))
                    Text("移出收藏夹")
                        .font(.system(size: 10.5, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundColor(.primary.opacity(0.7))
                .contentShape(Rectangle())
            }
            .buttonStyle(NeumorphicMenuButtonStyle())
        }
        .padding(4)
        .frame(width: 120)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

struct BookmarkCard: View {
    let item: BookmarkItem
    var onDelete: () -> Void
    var onEdit: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var showMenu = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Neumorphic Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.6), radius: 2, x: -1, y: -1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
                
                BookmarkIconView(iconUrl: item.iconUrl)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            }
            .frame(width: 44, height: 44)
            
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary.opacity(0.8))
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: item.url) {
                NSWorkspace.shared.open(url)
            }
        }
        .onLongPressGesture {
            showMenu = true
        }
        .overlay(
            RightClickDetector { showMenu = true }
        )
        .popover(isPresented: $showMenu, arrowEdge: .bottom) {
            BookmarkContextMenu(onEdit: onEdit, onDelete: onDelete, showMenu: $showMenu)
        }
    }
}

struct NeumorphicMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.05) : Color.clear)
            .cornerRadius(6)
    }
}

struct AddBookmarkDialog: View {
    @ObservedObject var viewModel: AppViewModel
    @State var url: String
    var editingBookmark: BookmarkItem?
    var onCancel: () -> Void
    var onAdd: (String, String, String?) -> Void
    
    // Internal State
    @State private var step: Int = 0 // 0: Input, 1: Edit
    @State private var title: String = ""
    @State private var iconUrl: String? = nil
    @State private var isFetching: Bool = false
    
    init(viewModel: AppViewModel, initialUrl: String, editingBookmark: BookmarkItem? = nil, onCancel: @escaping () -> Void, onAdd: @escaping (String, String, String?) -> Void) {
        self.viewModel = viewModel
        self._url = State(initialValue: initialUrl)
        self.editingBookmark = editingBookmark
        self.onCancel = onCancel
        self.onAdd = onAdd
        
        // 如果是编辑模式，直接进入第二步
        if let editing = editingBookmark {
            self._step = State(initialValue: 1)
            self._title = State(initialValue: editing.title)
            self._iconUrl = State(initialValue: editing.iconUrl)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editingBookmark != nil ? "编辑书签" : (step == 0 ? "添加书签" : "确认信息"))
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if step == 1 && editingBookmark == nil {
                    Button(action: { withAnimation { step = 0 } }) {
                        Text("修改链接").font(.system(size: 11)).foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            VStack(spacing: 20) {
                if step == 0 {
                    // Step 1: Input URL
                    VStack(spacing: 16) {
                        NeumorphicTextField(icon: "link", title: "网站链接", text: $url, placeholder: "github.com")
                        
                        if isFetching {
                            HStack {
                                ProgressView().scaleEffect(0.5)
                                Text("正在分析网页元数据...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .transition(.move(edge: .leading))
                } else {
                    // Step 2: Edit Details
                    VStack(spacing: 16) {
                        // Icon Preview
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                BookmarkIconView(iconUrl: iconUrl)
                                    .frame(width: 28, height: 28)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("网页图标已就绪")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(iconUrl == nil ? "使用默认全球图标" : "已从服务器获取图标")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        NeumorphicTextField(icon: "text.alignleft", title: "标题", text: $title, placeholder: "网页标题")
                        NeumorphicTextField(icon: "link", title: "链接", text: $url, placeholder: "https://...")
                    }
                    .transition(.move(edge: .trailing))
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button("取消", action: onCancel)
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                    
                    if step == 0 {
                        Button(action: fetchAndNext) {
                            Text("下一步")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(url.isEmpty || isFetching)
                        .opacity((url.isEmpty || isFetching) ? 0.5 : 1)
                    } else {
                        Button(action: { onAdd(title, url, iconUrl) }) {
                            Text(editingBookmark != nil ? "更新书签" : "保存书签")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(editingBookmark != nil ? Color.blue : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(width: 340)
    }
    
    func fetchAndNext() {
        guard !url.isEmpty else { return }
        isFetching = true
        
        viewModel.fetchMetadata(url: url) { metadata in
            withAnimation {
                self.isFetching = false
                self.title = metadata.title ?? ""
                self.iconUrl = metadata.iconUrl
                // 确保 URL 格式化
                if !self.url.hasPrefix("http") { self.url = "https://" + self.url }
                self.step = 1
            }
        }
    }
}

// MARK: - Command List View
struct CommandListView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var draggedItem: CommandItem?
    var onEdit: (CommandItem) -> Void
    var onDeleteRequest: (CommandItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if viewModel.commands.isEmpty {
                    EmptyStateView(onAdd: {}).padding(.top, 60)
                } else {
                    ForEach(viewModel.commands) { cmd in
                        NeumorphicCard(
                            command: cmd,
                            draggedItem: $draggedItem, // 传递绑定
                            isOn: Binding(
                                get: { viewModel.commandStates[cmd.id] ?? false },
                                set: { _ in viewModel.toggle(command: cmd) }
                            ),
                            isLoading: viewModel.isLoading[cmd.id] ?? false,
                            onEdit: { onEdit(cmd) },
                            onDelete: { onDeleteRequest(cmd) }
                        )
                        .onDrop(of: [.text], delegate: ReorderableDropDelegate(
                            item: cmd,
                            list: viewModel.commands,
                            draggedItem: $draggedItem,
                            onMove: viewModel.moveCommand
                        ))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Command Edit View
struct CommandEditView: View {
    @ObservedObject var viewModel: AppViewModel
    var item: CommandItem?
    var onDismiss: () -> Void
    
    enum Mode: Int { case brew = 0; case custom = 1 }
    @State private var mode: Mode = .brew
    @State private var brewServices: [BrewService] = []
    @State private var isLoadingBrew = false
    
    @State private var name = ""
    @State private var desc = ""
    @State private var icon = "terminal"
    @State private var startCmd = ""
    @State private var stopCmd = ""
    @State private var checkCmd = ""
    @State private var checkStatus: Int = -1
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text(item == nil ? "添加服务" : "编辑服务")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                
                if item == nil {
                    Picker("", selection: $mode) {
                        Text("Brew").tag(Mode.brew)
                        Text("Custom").tag(Mode.custom)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                    .frame(width: 120)
                    .onChange(of: mode) { newMode in
                        clearForm(keepMode: true)
                        if newMode == .brew { loadBrewServices() }
                    }
                } else {
                    Spacer().frame(width: 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .modifier(GlassPaneModifier())
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    
                    if mode == .brew && item == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("系统服务").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 4)
                            if isLoadingBrew {
                                ProgressView().scaleEffect(0.6).frame(maxWidth: .infinity, alignment: .leading)
                            } else if brewServices.isEmpty {
                                Text("未找到服务").font(.caption).foregroundColor(.secondary).padding(8)
                            } else {
                                Menu {
                                    ForEach(brewServices) { service in
                                        Button(service.name) { applyBrewService(service) }
                                    }
                                } label: {
                                    HStack {
                                        Text(name.isEmpty ? "点击选择 Homebrew 服务..." : name)
                                            .foregroundColor(name.isEmpty ? .secondary : .primary)
                                            .font(.system(size: 14))
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                                    }
                                    .padding(10)
                                    .background(NeumorphicInputBackground())
                                }
                                .menuStyle(BorderlessButtonMenuStyle())
                            }
                        }
                        .padding(.top, 20).padding(.horizontal, 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 18) {
                        NeumorphicTextField(icon: "tag.fill", title: "名称", text: $name, placeholder: "Service Name")
                            .onChange(of: name) { newValue in
                                if mode == .custom && item == nil {
                                    let suggested = IconMatcher.suggest(for: newValue)
                                    if suggested != "terminal" { icon = suggested }
                                }
                            }
                        
                        NeumorphicTextField(icon: "text.alignleft", title: "描述", text: $desc, placeholder: "Description")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("图标").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 4)
                            IconPicker(selectedIcon: $icon)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, mode == .custom ? 20 : 0)
                    
                    VStack(alignment: .leading, spacing: 18) {
                        Divider().background(Color.secondary.opacity(0.1))
                        
                        NeumorphicTextField(icon: "play.fill", title: "启动命令", text: $startCmd, placeholder: "Start Command", isCode: true)
                            .onChange(of: startCmd) { _ in autoFillCommands() }
                        NeumorphicTextField(icon: "stop.fill", title: "停止命令", text: $stopCmd, placeholder: "Stop Command", isCode: true)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("状态检查").font(.caption).bold().foregroundColor(.secondary).padding(.leading, 4)
                            HStack(spacing: 8) {
                                TextField("pgrep ...", text: $checkCmd)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(12)
                                    .background(NeumorphicInputBackground())
                                
                                Button(action: validate) {
                                    Image(systemName: checkStatus == 0 ? "checkmark.circle.fill" : (checkStatus == 1 ? "exclamationmark.circle.fill" : "play.circle.fill"))
                                        .foregroundColor(checkStatus == 0 ? .green : (checkStatus == 1 ? .orange : .blue))
                                        .font(.title2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
            
            // Footer
            HStack {
                Spacer()
                Button(action: save) {
                    Text("保存")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(name.isEmpty || startCmd.isEmpty)
                .opacity((name.isEmpty || startCmd.isEmpty) ? 0.5 : 1)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .modifier(GlassPaneModifier())
        }
        .onAppear { setup() }
    }
    
    // Logic Methods
    func setup() {
        if let existing = item {
            mode = .custom
            name = existing.name; desc = existing.description; icon = existing.iconName
            startCmd = existing.startCommand; stopCmd = existing.stopCommand; checkCmd = existing.checkCommand
            checkStatus = -1
        } else {
            if mode == .brew { loadBrewServices() }
        }
    }
    
    func clearForm(keepMode: Bool = false) {
        name = ""; desc = ""; icon = "terminal"; startCmd = ""; stopCmd = ""; checkCmd = ""; checkStatus = -1
    }
    
    func loadBrewServices() {
        guard brewServices.isEmpty else { return }
        isLoadingBrew = true
        DispatchQueue.global().async {
            let services = ShellRunner.listBrewServices()
            DispatchQueue.main.async { self.brewServices = services; self.isLoadingBrew = false }
        }
    }
    
    func applyBrewService(_ service: BrewService) {
        name = service.name
        desc = "Homebrew Service"
        startCmd = "/opt/homebrew/bin/brew services start \(service.name)"
        stopCmd = "/opt/homebrew/bin/brew services stop \(service.name)"
        icon = IconMatcher.suggest(for: service.name)
        checkCmd = service.name.contains("mysql") ? "pgrep mysqld" : "pgrep \(service.name)"
    }
    
    func autoFillCommands() {
        guard mode == .custom else { return }
        if !startCmd.isEmpty && (stopCmd.isEmpty || checkCmd.isEmpty) {
            let parts = startCmd.split(separator: " ")
            if let bin = parts.first {
                let binName = URL(fileURLWithPath: String(bin)).lastPathComponent
                if stopCmd.isEmpty { stopCmd = "pkill \(binName)" }
                if checkCmd.isEmpty { checkCmd = "pgrep \(binName)" }
            }
        }
    }
    
    func validate() {
        guard !checkCmd.isEmpty else { return }
        checkStatus = -1
        ShellRunner.runAsync(checkCmd) { result in checkStatus = (result.status <= 1 ? 0 : 1) }
    }
    
    func save() {
        let newItem = CommandItem(id: item?.id ?? UUID(), name: name, description: desc, iconName: icon, startCommand: startCmd, stopCommand: stopCmd, checkCommand: checkCmd)
        if item != nil { viewModel.updateCommand(newItem) } else { viewModel.addCommand(newItem) }
        onDismiss()
    }
}

// MARK: - Reusable Components

// 用于捕获右键点击的透明视图
struct RightClickDetector: NSViewRepresentable {
    var onRightClick: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = RightClickView()
        view.onRightClick = onRightClick
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class RightClickView: NSView {
        var onRightClick: (() -> Void)?
        
        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }
    }
}

struct NeumorphicCard: View {
    let command: CommandItem
    @Binding var draggedItem: CommandItem?
    @Binding var isOn: Bool
    var isLoading: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // 侧滑状态
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var showMenu = false
    private let menuWidth: CGFloat = 90
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 内容层
            HStack(spacing: 10) {
                // 视觉手柄
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.3))
                    .padding(.leading, 2)

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.6), radius: 1, x: -0.5, y: -0.5)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0.5, y: 0.5)
                    
                    Image(systemName: command.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(isOn ? .blue : .secondary.opacity(0.7))
                }
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(command.name).font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundColor(.primary)
                    if !command.description.isEmpty {
                        Text(command.description).font(.system(size: 9)).lineLimit(1).foregroundColor(.secondary.opacity(0.8))
                    }
                }
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.5) }
                else { Toggle("", isOn: $isOn).toggleStyle(SwitchToggleStyle(tint: .blue)).labelsHidden().scaleEffect(0.7) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
            .offset(x: offset)
            .onTapGesture {
                if isSwiped {
                    withAnimation(.spring()) { offset = 0; isSwiped = false }
                }
            }
            .overlay(
                RightClickDetector { showMenu = true }
            )
            // 30px 拖拽感应区
            .overlay(
                HStack {
                    Color.white.opacity(0.001)
                        .frame(width: 30)
                        .onDrag {
                            self.draggedItem = command
                            return NSItemProvider(object: command.id.uuidString as NSString)
                        }
                    Spacer()
                }
            )
            .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                BookmarkContextMenu(onEdit: onEdit, onDelete: onDelete, showMenu: $showMenu)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 25)
                    .onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) * 2 {
                            let translation = value.translation.width
                            if translation < 0 {
                                offset = isSwiped ? translation - menuWidth : translation
                            } else if isSwiped && translation > 0 {
                                offset = translation - menuWidth
                                if offset > 0 { offset = 0 }
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -30 {
                                offset = -menuWidth
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            
            // 操作按钮
            if offset != 0 || isSwiped {
                HStack(spacing: 10) {
                    NeumorphicActionButton(icon: "slider.horizontal.3", color: .indigo) {
                        withAnimation(.spring()) { offset = 0; isSwiped = false }
                        onEdit()
                    }
                    NeumorphicActionButton(icon: "minus.circle.fill", color: .orange) {
                        withAnimation(.spring()) { offset = 0; isSwiped = false }
                        onDelete()
                    }
                }
                .padding(.trailing, 10)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

struct NeumorphicInputBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), radius: 0, x: 0, y: 1)
    }
}

struct NeumorphicTextField: View {
    let icon: String
    let title: String
    @Binding var text: String
    var placeholder: String
    var isCode: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).padding(.leading, 4)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(.secondary.opacity(0.5)).font(.system(size: 13)).frame(width: 18)
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(isCode ? .system(.caption, design: .monospaced) : .system(.body))
            }
            .padding(12)
            .background(NeumorphicInputBackground())
        }
    }
}

struct NeumorphicIconButton: View {
    let icon: String
    var color: Color = .primary
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(color.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(NSColor.controlBackgroundColor).opacity(0.8)).shadow(color: Color.black.opacity(0.1), radius: 1, x: 1, y: 1).shadow(color: Color.white.opacity(0.5), radius: 1, x: -1, y: -1))
        }.buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
            Text("没有活跃的服务").font(.body).foregroundColor(.secondary)
            Button("立即添加", action: onAdd)
                .buttonStyle(PlainButtonStyle()).padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.blue).foregroundColor(.white).cornerRadius(16)
        }
    }
}

struct ToastView: View {
    let message: String
    let onDismiss: () -> Void
    var body: some View {
        VStack { Spacer(); HStack { Image(systemName: "info.circle"); Text(message) }
            .padding().background(Color.black.opacity(0.7)).cornerRadius(20).foregroundColor(.white)
            .padding().onTapGesture(perform: onDismiss) }
        .transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(99)
    }
}

struct IconPicker: View {
    @Binding var selectedIcon: String
    @State private var isExpanded = false
    @State private var searchText = ""
    
    let columns = [GridItem(.adaptive(minimum: 32), spacing: 8)]
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏 (仅展开时显示)
            if isExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("搜索图标...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if !searchText.isEmpty {
                        // 搜索结果模式
                        let filteredIcons = iconLibrary.flatMap { $0.icons }.filter { icon in
                            // 匹配 SF Symbol 名称
                            if icon.localizedCaseInsensitiveContains(searchText) { return true }
                            
                            // 匹配 IconMatcher 中的关键字
                            let matchesKeyword = IconMatcher.mapping.contains { keyword, mappedIcon in
                                keyword.localizedCaseInsensitiveContains(searchText) && mappedIcon == icon
                            }
                            return matchesKeyword
                        }
                        
                        if filteredIcons.isEmpty {
                            Text("无匹配图标")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(filteredIcons, id: \.self) { icon in
                                    IconCell(icon: icon, selectedIcon: $selectedIcon)
                                }
                            }
                        }
                    } else {
                        // 分类浏览模式
                        ForEach(iconLibrary) { category in
                            // 如果未展开，只显示包含当前选中图标的分类，或者第一个分类
                            if isExpanded || category.icons.contains(selectedIcon) || (selectedIcon == "terminal" && category.id == iconLibrary.first?.id) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if isExpanded {
                                        Text(category.title.uppercased())
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary.opacity(0.8))
                                            .padding(.leading, 2)
                                    }
                                    
                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(category.icons, id: \.self) { icon in
                                            IconCell(icon: icon, selectedIcon: $selectedIcon)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(4)
            }
            .frame(height: isExpanded ? 200 : 70) // 展开后高度大增，默认只展示一行多
            .background(Color.black.opacity(0.02))
            .cornerRadius(8)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
            
            // 展开按钮
            Button(action: { 
                withAnimation {
                    isExpanded.toggle() 
                    if !isExpanded { searchText = "" } // 收起时清空搜索
                }
            }) {
                HStack(spacing: 4) {
                    Text(isExpanded ? "收起图标库" : "展开完整图标库 (\(presetIcons.count)+)")
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.blue.opacity(0.8))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.01)) // 扩大点击区域
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct IconCell: View {
    let icon: String
    @Binding var selectedIcon: String
    
    var body: some View {
        Button(action: { selectedIcon = icon }) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedIcon == icon ? Color.blue : Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .foregroundColor(selectedIcon == icon ? .white : .primary.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedIcon == icon ? Color.blue.opacity(0.5) : Color.black.opacity(0.05), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
