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
                // 1. 去除首尾空格和换行
                let cleanStr = str.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 2. 过滤空内容
                if cleanStr.isEmpty { return }
                
                // 3. 过滤过短的内容（小于4个字符）
                if cleanStr.count < 4 {
                    return
                }
                
                // 获取当前前台应用作为来源
                let frontApp = NSWorkspace.shared.frontmostApplication
                let appName = frontApp?.localizedName
                let bundleId = frontApp?.bundleIdentifier
                
                let newItem = ClipboardItem(text: cleanStr, date: Date(), appName: appName, bundleId: bundleId)
                
                DispatchQueue.main.async {
                    // 4. 去重：如果存在相同内容，先移除旧的（变相置顶）
                    self.history.removeAll { $0.text == cleanStr }
                    
                    self.history.insert(newItem, at: 0)
                    // 限制最大条数
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
        // 更新 changeCount 避免被自己再次捕获（或者不做处理，让其成为最新）
    }
    
    func pasteToActiveApp(_ item: ClipboardItem) {
        // 1. Copy to clipboard first
        copyToClipboard(item)
        
        // 2. Hide our app and return focus to the previous app
        // Note: The UI hiding logic usually happens in the View/Controller, 
        // but we need to ensure the previous app is active before sending keys.
        NSApp.hide(nil)
        
        // 3. Wait a bit for focus to switch, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let source = CGEventSource(stateID: .hidSystemState)
            
            let keyV: CGKeyCode = 9
            let cmdFlag = CGEventFlags.maskCommand
            
            // Key Down
            if let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true) {
                eventDown.flags = cmdFlag
                eventDown.post(tap: .cghidEventTap)
            }
            
            // Key Up
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
