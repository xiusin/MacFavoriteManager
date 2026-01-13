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
        // 启动时检查辅助功能权限，这是全局快捷键生效的前提
        checkPermissions()
        
        let handler: (NSEvent) -> Void = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // 包含匹配：只要按住了 Option 且按下了 Space (keyCode 49)
            if flags.contains(.option) {
                if event.keyCode == 49 {
                    DispatchQueue.main.async {
                        self?.onTrigger?()
                    }
                }
            }
        }
        
        // 1. 全局监听 (Global Monitor): 当应用处于后台或失去焦点时，捕获系统范围内的按键事件
        // 注意：这严格依赖系统的 Accessibility 权限
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        
        // 2. 本地监听 (Local Monitor): 当应用处于前台活跃状态时，捕获当前应用窗口内的按键事件
        // 返回 event 以便让按键继续传递（不影响正常空格输入）
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return event
        }
    }
    
    /// 辅助功能权限检查：如果未授权，会触发 macOS 系统弹窗提示用户前往设置开启
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
