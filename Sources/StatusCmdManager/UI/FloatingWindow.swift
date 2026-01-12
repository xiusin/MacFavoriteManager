import SwiftUI
import AppKit

// MARK: - Floating Window Controller
class FloatingWindowController: ObservableObject {
    static let shared = FloatingWindowController()
    
    var window: NSWindow?
    @Published var isVisible: Bool = false
    @Published var isExpanded: Bool = false
    
    // Dependencies
    let clipboardManager = ClipboardManager()
    
    init() {
        createWindow()
    }
    
    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let contentView = FloatingRootView(controller: self)
            .environmentObject(clipboardManager)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.window = window
    }
    
    func toggle(at point: NSPoint) {
        if isVisible {
            hide()
        } else {
            show(at: point)
        }
    }
    
    func show(at point: NSPoint) {
        guard let window = window else { return }
        
        // 初始位置，修正 y 坐标 (屏幕坐标系转换)
        // NSEvent.mouseLocation 的原点在屏幕左下角
        // NSWindow frame 的原点也在左下角
        // 所以直接使用 point 即可
        
        window.setFrameOrigin(NSPoint(x: point.x - 30, y: point.y - 30))
        window.makeKeyAndOrderFront(nil)
        
        // 激活应用以接收焦点（如果需要输入）
        // NSApp.activate(ignoringOtherApps: true) 
        
        withAnimation {
            isVisible = true
            isExpanded = false // 初始只显示图标
        }
    }
    
    func hide() {
        withAnimation {
            isVisible = false
            isExpanded = false
        }
        window?.orderOut(nil)
    }
}

// MARK: - Floating Views
struct FloatingRootView: View {
    @ObservedObject var controller: FloatingWindowController
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        ZStack {
            if controller.isExpanded {
                FloatingToolMenu(controller: controller)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                FloatingToolIcon(controller: controller)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .frame(width: controller.isExpanded ? 240 : 60, height: controller.isExpanded ? 320 : 60)
        .background(Color.clear)
    }
}

struct FloatingToolIcon: View {
    var controller: FloatingWindowController
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            
            Image(systemName: "briefcase.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
        }
        .frame(width: 50, height: 50)
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .onTapGesture {
            withAnimation(.spring()) {
                controller.isExpanded = true
                // Update window size
                controller.window?.setContentSize(NSSize(width: 240, height: 320))
            }
        }
        .onHover { hover in
            withAnimation { isHovering = hover }
        }
    }
}

struct FloatingToolMenu: View {
    var controller: FloatingWindowController
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var selectedTab = 0 // 0: Clipboard, 1: Tools
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(selectedTab == 0 ? "剪贴板" : "工具")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                
                // Toggle Tab
                Button(action: { withAnimation { selectedTab = selectedTab == 0 ? 1 : 0 } }) {
                    Image(systemName: selectedTab == 0 ? "square.grid.2x2" : "doc.on.clipboard")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer().frame(width: 10)
                
                // Close
                Button(action: { controller.hide() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            if selectedTab == 0 {
                // Clipboard List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(clipboardManager.history) { item in
                            ClipboardRow(item: item) {
                                clipboardManager.copyToClipboard(item)
                                controller.hide()
                            }
                        }
                    }
                    .padding(8)
                }
            } else {
                // Tools List
                VStack(spacing: 10) {
                    SimpleToolRow(icon: "character.book.closed.fill", title: "翻译选中文本", color: .orange) {
                        // TODO: Implement Translation
                        controller.hide()
                    }
                    
                    SimpleToolRow(icon: "text.viewfinder", title: "屏幕 OCR", color: .purple) {
                        // TODO: Implement OCR
                        controller.hide()
                    }
                }
                .padding(12)
                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(item.text)
                    .lineLimit(2)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(8)
            .background(isHovering ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovering = $0 }
    }
}

struct SimpleToolRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14))
                }
                Text(title).font(.system(size: 12))
                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
