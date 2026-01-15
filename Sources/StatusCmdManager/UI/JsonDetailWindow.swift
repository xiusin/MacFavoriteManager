import SwiftUI
import AppKit

// MARK: - Controller
class JsonDetailWindowController: ObservableObject {
    static let shared = JsonDetailWindowController()
    
    var window: NSWindow?
    
    func show(jsonObject: Any) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "JSON 结构化视图"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.center()
            window.isReleasedWhenClosed = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            self.window = window
        }
        
        let contentView = JsonDetailView(initialObject: jsonObject)
            .edgesIgnoringSafeArea(.all)
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - View
struct JsonDetailView: View {
    @State private var input: String = ""
    @State private var jsonObject: Any?
    @State private var errorMsg: String = ""
    
    // Initializer
    init(initialObject: Any? = nil) {
        _jsonObject = State(initialValue: initialObject)
    }
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            AcrylicBackground(radius: 16)
            
            VStack(spacing: 0) {
                // Header / Drag Area
                HStack {
                    Text("JSON 结构化视图")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 68) // Traffic lights
                    
                    Spacer()
                    
                    if jsonObject != nil {
                        Button(action: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                jsonObject = nil 
                                input = ""
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("返回输入")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.01)) // For dragging
                
                Divider().opacity(0.1)
                
                // Content
                ZStack {
                    if let obj = jsonObject {
                        // MARK: - Preview Mode
                        VStack(spacing: 0) {
                            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 4) {
                                    JsonNodeView(key: "Root", value: obj, isRoot: true)
                                }
                                .padding(24)
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                    } else {
                        // MARK: - Input Mode
                        VStack(spacing: 20) {
                            Text("粘贴 JSON 内容以解析")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            ZStack(alignment: .topLeading) {
                                LiquidInputBackground()
                                
                                if input.isEmpty {
                                    Text("Waiting for input...")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .padding(12)
                                }
                                
                                JsonInputEditor(text: $input)
                                    .padding(6)
                            }
                            .frame(maxWidth: 500, maxHeight: 300)
                            
                            if !errorMsg.isEmpty {
                                Text(errorMsg)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            Button(action: parseJson) {
                                Text("解析预览")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(LiquidPillButtonStyle())
                            .disabled(input.isEmpty)
                            .opacity(input.isEmpty ? 0.5 : 1)
                        }
                        .padding(40)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Key Event Monitor for ESC
        .background(WindowAccessor { window in
            // Add local monitor for Esc key
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // 53 is Esc
                    window.close()
                    return nil // Consume event
                }
                return event
            }
        })
        .onAppear {
            if jsonObject == nil {
                checkClipboard()
            }
        }
    }
    
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
                input = trimmed
                parseJson()
            }
        }
    }
    
    func parseJson() {
        guard let data = input.data(using: .utf8) else { return }
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            errorMsg = ""
        } catch {
            errorMsg = "解析失败: \(error.localizedDescription)"
            withAnimation { jsonObject = nil }
        }
    }
}

// Helper to access underlying NSWindow
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}