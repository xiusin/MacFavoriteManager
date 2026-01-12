import SwiftUI
import Combine
import AppKit

struct ClipboardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var text: String
    var date: Date
}

class ClipboardManager: ObservableObject {
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
                // 避免重复保存最近的一条
                if let last = history.first, last.text == str {
                    return
                }
                
                let newItem = ClipboardItem(text: str, date: Date())
                DispatchQueue.main.async {
                    self.history.insert(newItem, at: 0)
                    // 限制最大条数
                    if self.history.count > 50 {
                        self.history.removeLast()
                    }
                    self.saveHistory()
                }
            }
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        // 更新 changeCount 避免被自己再次捕获（或者不做处理，让其成为最新）
    }
    
    // Persistence
    private let key = "ClipboardHistory_v1"
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            self.history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
