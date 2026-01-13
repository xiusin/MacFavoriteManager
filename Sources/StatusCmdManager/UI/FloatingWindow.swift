import SwiftUI
import AppKit

// MARK: - Floating Window Controller
class FloatingWindowController: ObservableObject {
    static let shared = FloatingWindowController()
    
    var window: NSWindow?
    @Published var isVisible: Bool = false
    
    // Dependencies
    let clipboardManager = ClipboardManager.shared
    
    init() {
        createWindow()
    }
    
    private func createWindow() {
        // 使用无边框窗口以获得完全的自定义外观
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 450),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // 浮动层级，确保在其他窗口之上
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        // 允许在全屏应用之上显示
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let contentView = FloatingRootView(controller: self)
            .environmentObject(clipboardManager)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.window = window
    }
    
    // 保持签名兼容，但忽略坐标，强制居中
    func toggle(at point: NSPoint) {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        guard let window = window else { return }
        
        // 核心修复：每次显示都强制居中
        window.center()
        
        // 核心修复：强制激活应用和窗口，确保能接收键盘事件
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        withAnimation {
            isVisible = true
        }
    }
    
    func hide() {
        withAnimation {
            isVisible = false
        }
        window?.orderOut(nil)
        NSApp.hide(nil) // 隐藏应用以归还焦点
    }
}

// MARK: - Floating Views
struct FloatingRootView: View {
    @ObservedObject var controller: FloatingWindowController
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        ZStack {
            // 复用 AcrylicBackground 实现高斯模糊背景
            AcrylicBackground()
                .cornerRadius(16) // 圆角
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            FloatingToolMenu(controller: controller)
        }
        .frame(width: 320, height: 450)
        .background(Color.clear)
    }
}

struct FloatingToolMenu: View {
    var controller: FloatingWindowController
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @Environment(\.colorScheme) var colorScheme
    
    var filteredHistory: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.history
        } else {
            return clipboardManager.history.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("剪贴板历史")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                
                Text("⇅选择 ↵粘贴")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                
                Spacer().frame(width: 8)
                
                // Close
                Button(action: { controller.hide() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            // Search & Clear Row (Synced with ToolsView style)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11.5))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(NeumorphicInputBackground())
                
                Button(action: { clipboardManager.clearHistory() }) {
                    ZStack {
                        NeumorphicInputBackground()
                        
                        Image(systemName: "trash")
                            .foregroundColor(.orange.opacity(0.85))
                            .font(.system(size: 11))
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider().opacity(0.2)
            
            // Clipboard List
            ScrollViewReader { proxy in
                ScrollView {
                    if filteredHistory.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.2))
                            Text("暂无记录")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 80)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                                FloatingClipboardRow(item: item, isSelected: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture {
                                        confirmSelection(item)
                                    }
                            }
                        }
                        .padding(12)
                    }
                }
                .onChange(of: selectedIndex) { newIndex in
                    proxy.scrollTo(newIndex, anchor: .center)
                }
                .onChange(of: searchText) { _ in selectedIndex = 0 }
            }
            .background(KeyEventHandlingView { key in
                handleKey(key)
            })
        }
        .onAppear {
            selectedIndex = 0
        }
    }
    
    func handleKey(_ event: NSEvent) {
        let maxIndex = filteredHistory.count - 1 // Fix: Use filteredHistory count
        guard maxIndex >= 0 else { return }
        
        switch event.keyCode {
        case 126: // Up Arrow
            if selectedIndex > 0 { selectedIndex -= 1 }
        case 125: // Down Arrow
            if selectedIndex < maxIndex { selectedIndex += 1 }
        case 36: // Enter
            let item = filteredHistory[selectedIndex] // Fix: Use filteredHistory item
            confirmSelection(item)
        case 53: // Esc
            controller.hide()
        default: break
        }
    }
    
    func confirmSelection(_ item: ClipboardItem) {
        controller.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            clipboardManager.pasteToActiveApp(item)
        }
    }
}

struct FloatingClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    // Helper to get app icon
    func getAppIcon(bundleId: String?) -> NSImage? {
        guard let bundleId = bundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Source App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                
                if let bundleId = item.bundleId, let icon = getAppIcon(bundleId: bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                            .aspectRatio(contentMode: .fit)
                        .padding(3)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .frame(width: 28, height: 28)
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                    .font(.system(size: 11.5))
                    .lineLimit(2)
                    .foregroundColor(.primary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                Text(timeString(from: item.date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            // Action
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // 如果选中，使用半透明蓝色；否则透明
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        .background(Color.white.opacity(0.02).cornerRadius(10))
                }
            }
        )
        .scaleEffect(isHovering ? 1.005 : 1.0)
        .onHover { isHovering = $0 }
    }
}

// Invisible view to handle keyboard events
struct KeyEventHandlingView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class KeyView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func viewDidMoveToWindow() {
            window?.makeFirstResponder(self)
        }
        
        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }
    }
}