import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    var onTrigger: (() -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // 简单实现：使用 NSEvent 监听 Global Monitor
    // 注意：这需要辅助功能权限 (Accessibility) 才能在后台监听按键
    // 如果没有权限，只能在前台监听
    // 想要更稳健的 Global Shortcut，通常需要使用 Carbon InstallEventHandler
    
    // 这里为了演示，我们使用 Option + Space (Alt + Space)
    // 更好的方式是使用 Carbon Events，但 swift 中写起来比较繁琐
    
    func startMonitoring() {
        checkPermissions()
        
        let handler: (NSEvent) -> Void = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // 检查 Option 键 (Alt)
            // 注意：有时 flags 可能包含其他非关键修饰键，这里做精确匹配或包含匹配
            // 这里使用包含匹配：只要按住了 Option 且按下了 Space
            if flags.contains(.option) {
                // 检查 Space (空格键的 keyCode 通常是 49)
                if event.keyCode == 49 {
                    DispatchQueue.main.async {
                        self?.onTrigger?()
                    }
                }
            }
        }
        
        // 1. 全局监听 (当应用在后台时)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        
        // 2. 本地监听 (当应用在前台/活跃时)
        // 返回 event 以便让事件继续传递（否则按键会被吞掉，导致打字时无法输入空格）
        // 但对于热键，我们通常希望拦截它？
        // 这里为了安全起见，如果不处理则返回 event，如果处理了也是被动监听
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return event
        }
    }
    
    func checkPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("需要辅助功能权限来监听全局快捷键")
        }
    }
    
    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
