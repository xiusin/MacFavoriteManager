import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var commands: [CommandItem] = []
    @Published var commandStates: [UUID: Bool] = [:]
    @Published var isLoading: [UUID: Bool] = [:]
    
    // UI 状态
    @Published var showErrorToast: Bool = false
    @Published var errorMessage: String = ""
    @Published var isEditingMode: Bool = false
    
    // Bookmark State
    @Published var bookmarks: [BookmarkItem] = []
    @Published var isFetchingMetadata: Bool = false
    @Published var isBookmarkGridView: Bool = true
    
    private let storageKey = "UserCommands_v1"
    private let bookmarkKey = "UserBookmarks_v1"
    private let viewModeKey = "isBookmarkGridView"
    
    init() {
        loadCommands()
        loadBookmarks()
        self.isBookmarkGridView = UserDefaults.standard.object(forKey: viewModeKey) as? Bool ?? true
    }
    
    func saveViewMode() {
        UserDefaults.standard.set(isBookmarkGridView, forKey: viewModeKey)
    }
    
    // MARK: - Persistence
    func loadCommands() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CommandItem].self, from: data) {
            self.commands = decoded
        } else {
            // 默认初始数据
            self.commands = [
                CommandItem(
                    name: "MySQL",
                    description: "Homebrew Service",
                    iconName: "server.rack",
                    startCommand: "brew services start mysql",
                    stopCommand: "brew services stop mysql",
                    checkCommand: "pgrep mysqld"
                ),
                CommandItem(
                    name: "Redis",
                    description: "Homebrew Service",
                    iconName: "memorychip",
                    startCommand: "brew services start redis",
                    stopCommand: "brew services stop redis",
                    checkCommand: "pgrep redis-server"
                )
            ]
        }
        checkAllStatus()
    }
    
    func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarkKey),
           let decoded = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            self.bookmarks = decoded
        }
    }
    
    func saveCommands() {
        if let encoded = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: bookmarkKey)
        }
    }
    
    // MARK: - Bookmark Management
    func fetchMetadata(url: String, completion: @escaping (WebMetadata) -> Void) {
        var fixedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fixedUrl.hasPrefix("http") { fixedUrl = "https://" + fixedUrl }
        WebMetadataFetcher.fetch(urlStr: fixedUrl, completion: completion)
    }

    func addBookmark(title: String, url: String, iconUrl: String?) {
        // 简单修正 URL
        var fixedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fixedUrl.hasPrefix("http") { fixedUrl = "https://" + fixedUrl }
        
        let id = UUID()
        var finalIconPath = iconUrl
        
        // 尝试缓存图标到本地
        if let remoteIconUrl = iconUrl, let remoteUrl = URL(string: remoteIconUrl) {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let iconsDir = appSupport.appendingPathComponent("StatusCmdManager/Icons")
            
            do {
                try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
                let localFilename = "\(id.uuidString).png" // 假设是 png，或者直接存数据
                let localFileUrl = iconsDir.appendingPathComponent(localFilename)
                
                // 异步下载并保存，这里为了简化逻辑在主线程发起异步任务，UI 会先更新
                DispatchQueue.global().async {
                    if let data = try? Data(contentsOf: remoteUrl) {
                        try? data.write(to: localFileUrl)
                        
                        // 更新内存中的 Item 指向本地路径
                        DispatchQueue.main.async {
                            if let index = self.bookmarks.firstIndex(where: { $0.id == id }) {
                                var item = self.bookmarks[index]
                                item.iconUrl = localFileUrl.absoluteString
                                self.bookmarks[index] = item
                                self.saveBookmarks()
                            }
                        }
                    }
                }
                
                // 暂时先存远程，下载完更新为本地
                finalIconPath = remoteIconUrl
            } catch {
                print("Failed to setup icon cache: \(error)")
            }
        }
        
        let newItem = BookmarkItem(id: id, title: title.isEmpty ? "Bookmark" : title, url: fixedUrl, iconUrl: finalIconPath)
        bookmarks.append(newItem)
        saveBookmarks()
    }
    
    func deleteBookmark(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        saveBookmarks()
    }
    
    func updateBookmark(_ item: BookmarkItem) {
        if let index = bookmarks.firstIndex(where: { $0.id == item.id }) {
            bookmarks[index] = item
            saveBookmarks()
        }
    }
    
    func moveCommand(from source: IndexSet, to destination: Int) {
        withAnimation {
            commands.move(fromOffsets: source, toOffset: destination)
            saveCommands()
        }
    }
    
    func moveBookmark(from source: IndexSet, to destination: Int) {
        withAnimation {
            bookmarks.move(fromOffsets: source, toOffset: destination)
            saveBookmarks()
        }
    }
    
    // MARK: - Command Management
    func addCommand(_ item: CommandItem) {
        commands.append(item)
        saveCommands()
        checkStatus(for: item)
    }
    
    func deleteCommand(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
        saveCommands()
    }
    
    func updateCommand(_ item: CommandItem) {
        if let index = commands.firstIndex(where: { $0.id == item.id }) {
            commands[index] = item
            saveCommands()
            checkStatus(for: item)
        }
    }
    
    // MARK: - Execution
    func checkAllStatus() {
        for cmd in commands {
            checkStatus(for: cmd)
        }
    }
    
    func checkStatus(for command: CommandItem) {
        ShellRunner.runAsync(command.checkCommand) { result in
            self.commandStates[command.id] = (result.status == 0)
        }
    }
    
    func toggle(command: CommandItem) {
        let currentState = commandStates[command.id] ?? false
        let cmdStr = currentState ? command.stopCommand : command.startCommand
        
        isLoading[command.id] = true
        
        ShellRunner.runAsync(cmdStr) { result in
            if result.status != 0 {
                // 失败处理
                self.showError(title: "执行失败", message: result.error.isEmpty ? result.output : result.error)
                self.isLoading[command.id] = false
                // 恢复状态检查
                self.checkStatus(for: command)
            } else {
                // 成功后延迟检查
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ShellRunner.runAsync(command.checkCommand) { newResult in
                        self.commandStates[command.id] = (newResult.status == 0)
                        self.isLoading[command.id] = false
                        
                        // 双重检查：如果状态没变，可能是命令执行慢了或者无效
                        if self.commandStates[command.id] == currentState {
                            // 可选：提示用户状态未改变
                        }
                    }
                }
            }
        }
    }
    
    func showError(title: String, message: String) {
        self.errorMessage = "\(title): \(message)"
        self.showErrorToast = true
        
        // 3秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showErrorToast = false
        }
    }
}
