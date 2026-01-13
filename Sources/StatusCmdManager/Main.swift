import SwiftUI
import AppKit

// 必须的入口点
@main
struct StatusCmdManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView() // 不需要主窗口
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: EventMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 初始化 Popover
        let contentView = ContentView()
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400) // 高度自适应，但在 SwiftUI 中主要由 View 决定
        popover.behavior = .transient // 点击外部自动关闭
        popover.contentViewController = NSHostingController(rootView: contentView)
        // 移除 Popover 默认的箭头外观，更贴近 Fluent Design
        popover.animates = true
        
        // 2. 初始化状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // 这里使用一个系统图标，你可以换成自己的
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Cmd Manager")
            button.action = #selector(togglePopover(_:))
        }
        
        // 3. 事件监听（用于点击外部关闭 popover，虽然 behavior = .transient 通常够用，但有时需要手动处理）
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover(sender: event)
            }
        }
        
        // 4. 初始化全局快捷键 (Option + Space) 呼出浮窗
        HotKeyManager.shared.onTrigger = {
            let mouseLoc = NSEvent.mouseLocation
            FloatingWindowController.shared.toggle(at: mouseLoc)
        }
        HotKeyManager.shared.startMonitoring()
        
        // 5. 初始化侧边记事本 (Side Note)
        _ = SideNoteWindowController.shared
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            // 发送通知让 UI 刷新状态
            NotificationCenter.default.post(name: NSNotification.Name("RefreshStatus"), object: nil)
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }
    
    func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
}

// 辅助类：监听全局点击事件以关闭 Popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
