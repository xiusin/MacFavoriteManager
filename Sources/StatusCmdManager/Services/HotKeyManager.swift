import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    var onTrigger: (() -> Void)?
    private var eventMonitor: Any?
    
    // 简单实现：使用 NSEvent 监听 Global Monitor
    // 注意：这需要辅助功能权限 (Accessibility) 才能在后台监听按键
    // 如果没有权限，只能在前台监听
    // 想要更稳健的 Global Shortcut，通常需要使用 Carbon InstallEventHandler
    
    // 这里为了演示，我们使用 Option + Space (Alt + Space)
    // 更好的方式是使用 Carbon Events，但 swift 中写起来比较繁琐
    
    func startMonitoring() {
        checkPermissions()
        
        // 监听 Option + Space
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // 检查 Option 键 (Alt)
            if flags.contains(.option) {
                // 检查 Space (空格键的 keyCode 通常是 49)
                if event.keyCode == 49 {
                    DispatchQueue.main.async {
                        self?.onTrigger?()
                    }
                }
            }
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
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
