import SwiftUI
import AppKit

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
        
        let contentView = JsonDetailView(jsonObject: jsonObject)
            .edgesIgnoringSafeArea(.top) // Allow content to go behind traffic lights
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct JsonDetailView: View {
    let jsonObject: Any
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            AcrylicBackground()
            
            VStack(spacing: 0) {
                // Header / Toolbar (Custom drag area)
                HStack {
                    Text("JSON 结构化视图")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 60) // Space for traffic lights
                    Spacer()
                    // Placeholder for search or other actions
                    Text("Esc 关闭")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.01)) // Make it draggable? SwiftUI doesn't auto-handle drag.
                // Usually window dragging is handled by the NSWindow background or Titlebar. 
                // With .fullSizeContentView, the user can drag the background if not covered by interactive views.
                
                Divider().opacity(0.2)
                
                // Content
                ScrollView([.horizontal, .vertical]) {
                    JsonNodeView(key: "Root", value: jsonObject)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
