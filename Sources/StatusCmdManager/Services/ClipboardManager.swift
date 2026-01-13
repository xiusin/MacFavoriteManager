import SwiftUI
import Combine
import AppKit

struct ClipboardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var text: String
    var date: Date
    var appName: String?
    var bundleId: String?
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        loadHistory()
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            if let str = pasteboard.string(forType: .string) {
                // 1. 数据清洗：去除首尾空格和换行，确保 UI 显示紧凑，并作为去重判断的基准
                let cleanStr = str.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 2. 长度过滤：忽略小于 4 个字符的内容（如单个标点或极短单词），减少无意义记录
                if cleanStr.count < 4 {
                    return
                }
                
                // 3. 获取来源应用信息：记录当前前台应用的名称和图标，用于 UI 区分数据来源
                let frontApp = NSWorkspace.shared.frontmostApplication
                let appName = frontApp?.localizedName
                let bundleId = frontApp?.bundleIdentifier
                
                let newItem = ClipboardItem(text: cleanStr, date: Date(), appName: appName, bundleId: bundleId)
                
                DispatchQueue.main.async {
                    // 4. 实时去重：如果内容已存在，则移除旧记录并插入新记录到首位（变相置顶更新）
                    self.history.removeAll { $0.text == cleanStr }
                    
                    self.history.insert(newItem, at: 0)
                    // 5. 容量限制：限制最大存储 100 条
                    if self.history.count > 100 {
                        self.history.removeLast()
                    }
                    self.saveHistory()
                }
            }
        }
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
    }
    
    /// 模拟粘贴逻辑：由于系统安全限制，必须隐藏当前 App 并让焦点回到上一个 App 后再模拟按键
    func pasteToActiveApp(_ item: ClipboardItem) {
        // 1. 复制内容到剪贴板
        copyToClipboard(item)
        
        // 2. 隐藏当前应用，使系统焦点切回之前的活跃应用
        NSApp.hide(nil)
        
        // 3. 延迟 0.3s 执行：关键步骤，确保系统焦点切换彻底完成，解决“无法填充到输入框”的问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let source = CGEventSource(stateID: .hidSystemState)
            
            let keyV: CGKeyCode = 9 // 'V' 键
            let cmdFlag = CGEventFlags.maskCommand
            
            // 模拟 Command + V 按下与弹起
            if let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true) {
                eventDown.flags = cmdFlag
                eventDown.post(tap: .cghidEventTap)
            }
            
            if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) {
                eventUp.flags = cmdFlag
                eventUp.post(tap: .cghidEventTap)
            }
        }
    }
    
    // Persistence
    private let key = "ClipboardHistory_v1"
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            
            // Clean up legacy data: Trim, Filter, and Deduplicate
            var uniqueText = Set<String>()
            var cleanedHistory: [ClipboardItem] = []
            
            // Process from newest to oldest (assuming decoded is sorted newest first)
            for item in decoded {
                let cleanText = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Apply new rules to old data
                if cleanText.count < 4 { continue }
                
                if !uniqueText.contains(cleanText) {
                    uniqueText.insert(cleanText)
                    // Update the item with the cleaned text just in case
                    var newItem = item
                    newItem.text = cleanText
                    cleanedHistory.append(newItem)
                }
            }
            
            self.history = cleanedHistory
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
