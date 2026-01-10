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
}

// MARK: - Main View
struct ContentView: View {
    @StateObject var viewModel = AppViewModel()
    @State private var route: AppRoute = .list
    
    // 删除确认状态
    @State private var itemToDelete: CommandItem?
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            ZStack {
                AcrylicBackground()
                Color(NSColor.windowBackgroundColor).opacity(0.4)
            }
            .edgesIgnoringSafeArea(.all)
            
            ZStack {
                if case .list = route {
                    CommandListView(viewModel: viewModel, onAdd: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .editor(nil) }
                    }, onEdit: { item in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .editor(item) }
                    }, onDeleteRequest: { item in
                        itemToDelete = item
                        showDeleteAlert = true
                    })
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                }
                
                if case let .editor(item) = route {
                    CommandEditView(viewModel: viewModel, item: item, onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { route = .list }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    .zIndex(1)
                }
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
            Alert(
                title: Text("确认删除?"),
                message: Text("此操作将永久移除该服务配置，无法撤销。"),
                primaryButton: .destructive(Text("删除")) {
                    if let item = itemToDelete, let idx = viewModel.commands.firstIndex(where: { $0.id == item.id }) {
                        viewModel.deleteCommand(at: IndexSet(integer: idx))
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
}

// MARK: - Command List View
struct CommandListView: View {
    @ObservedObject var viewModel: AppViewModel
    var onAdd: () -> Void
    var onEdit: (CommandItem) -> Void
    var onDeleteRequest: (CommandItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("控制中心")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))
                Spacer()
                HStack(spacing: 12) {
                    NeumorphicIconButton(icon: "plus", action: onAdd)
                    NeumorphicIconButton(icon: "power", color: .red, action: { NSApplication.shared.terminate(nil) })
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .modifier(GlassPaneModifier())
            
            // List
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.commands.isEmpty {
                        EmptyStateView(onAdd: onAdd).padding(.top, 60)
                    } else {
                        ForEach(viewModel.commands) { cmd in
                            NeumorphicCard(
                                command: cmd,
                                isOn: Binding(
                                    get: { viewModel.commandStates[cmd.id] ?? false },
                                    set: { _ in viewModel.toggle(command: cmd) }
                                ),
                                isLoading: viewModel.isLoading[cmd.id] ?? false,
                                onEdit: { onEdit(cmd) },
                                onDelete: { onDeleteRequest(cmd) }
                            )
                        }
                    }
                }
                .padding(20)
            }
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
struct NeumorphicCard: View {
    let command: CommandItem
    @Binding var isOn: Bool
    var isLoading: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 42, height: 42)
                    .shadow(color: Color.white.opacity(0.5), radius: 1, x: -1, y: -1)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 1, y: 1)
                
                Image(systemName: command.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(isOn ? .blue : .secondary.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.9))
                if !command.description.isEmpty {
                    Text(command.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            
            if isHovering {
                HStack(spacing: 8) {
                    NeumorphicIconButton(icon: "pencil", action: onEdit)
                    NeumorphicIconButton(icon: "trash", color: .red, action: onDelete)
                }
                .transition(.opacity)
            }
            
            if isLoading {
                ProgressView().scaleEffect(0.6)
            } else {
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                    .scaleEffect(0.9)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 1, y: 2)
        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.1 : 0.5), radius: 1, x: -1, y: -1)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        .onHover { hover in withAnimation { isHovering = hover } }
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
