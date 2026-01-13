import SwiftUI
import Combine

struct NoteItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var content: String
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var color: String = "blue" // blue, red, orange, green, purple
}

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
    
    // Note State
    @Published var notes: [NoteItem] = []
    
    private let storageKey = "UserCommands_v1"
    private let bookmarkKey = "UserBookmarks_v1"
    private let noteKey = "UserNotes_v1"
    private let viewModeKey = "isBookmarkGridView"
    
    init() {
        loadCommands()
        loadBookmarks()
        loadNotes()
        self.isBookmarkGridView = UserDefaults.standard.object(forKey: viewModeKey) as? Bool ?? true
        setupCloudSync()
    }
    
    // MARK: - iCloud Sync logic
    private func setupCloudSync() {
        // 监听其他设备同步过来的变更
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            self?.loadFromCloud()
        }
        
        // 强制从 iCloud 拉取最新
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    private func loadFromCloud() {
        print("iCloud Data Changed, updating...")
        loadCommands()
        loadBookmarks()
        loadNotes()
    }
    
    func saveViewMode() {
        UserDefaults.standard.set(isBookmarkGridView, forKey: viewModeKey)
        NSUbiquitousKeyValueStore.default.set(isBookmarkGridView, forKey: viewModeKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    // MARK: - Persistence
    func loadCommands() {
        // 优先从 iCloud 读取，如果没有则回退到本地
        let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: storageKey)
        let localData = UserDefaults.standard.data(forKey: storageKey)
        
        if let data = cloudData ?? localData,
           let decoded = try? JSONDecoder().decode([CommandItem].self, from: data) {
            self.commands = decoded
        } else {
            // 默认初始数据...
            self.commands = [
                CommandItem(name: "MySQL", description: "Homebrew Service", iconName: "server.rack", startCommand: "brew services start mysql", stopCommand: "brew services stop mysql", checkCommand: "pgrep mysqld"),
                CommandItem(name: "Redis", description: "Homebrew Service", iconName: "memorychip", startCommand: "brew services start redis", stopCommand: "brew services stop redis", checkCommand: "pgrep redis-server")
            ]
        }
        checkAllStatus()
    }
    
    func loadBookmarks() {
        let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: bookmarkKey)
        let localData = UserDefaults.standard.data(forKey: bookmarkKey)
        
        if let data = cloudData ?? localData,
           let decoded = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            self.bookmarks = decoded
        }
    }
    
    func loadNotes() {
        let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: noteKey)
        let localData = UserDefaults.standard.data(forKey: noteKey)
        
        if let data = cloudData ?? localData,
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            self.notes = decoded
        } else {
            // Default Welcome Note
            self.notes = [NoteItem(content: "欢迎使用侧边记事本！鼠标触碰屏幕右侧边缘即可唤出。", color: "blue")]
        }
    }
    
    func saveCommands() {
        if let encoded = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.set(encoded, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(encoded, forKey: bookmarkKey)
            NSUbiquitousKeyValueStore.default.set(encoded, forKey: bookmarkKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: noteKey)
            NSUbiquitousKeyValueStore.default.set(encoded, forKey: noteKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    // MARK: - Note Management
    func addNote(content: String, color: String = "blue") {
        let newNote = NoteItem(content: content, color: color)
        notes.insert(newNote, at: 0)
        saveNotes()
    }
    
    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        saveNotes()
    }
    
    func updateNote(_ note: NoteItem) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            saveNotes()
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
    
    // MARK: - Brew Manager
    @Published var brewServices: [BrewService] = []
    @Published var isBrewLoading: Bool = false
    
    // Store / Marketplace
    @Published var installedFormulae: Set<String> = []
    @Published var searchResults: [String] = []
    @Published var isSearching: Bool = false
    @Published var searchQuery: String = ""
    
    // Recommended list based on IconMatcher keys (filtered to likely services)
    var recommendedServices: [String] {
        let allKeys = IconMatcher.mapping.keys.map { $0 }
        return allKeys.sorted()
    }
    
    func refreshBrewServices() {
        isBrewLoading = true
        // Parallel fetch
        let group = DispatchGroup()
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let services = ShellRunner.listBrewServices()
            DispatchQueue.main.async {
                self.brewServices = services
                group.leave()
            }
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let installed = ShellRunner.listInstalledFormulae()
            DispatchQueue.main.async {
                self.installedFormulae = installed
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isBrewLoading = false
        }
    }
    
    func searchBrew() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        ShellRunner.searchBrew(query: searchQuery) { [weak self] results in
            DispatchQueue.main.async {
                self?.searchResults = results
                self?.isSearching = false
            }
        }
    }
    
    func operateBrewService(_ service: BrewService, action: String) {
        isBrewLoading = true
        ShellRunner.operateBrewService(action: action, service: service.name) { result in
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(title: "\(action.capitalized) Failed", message: result.error.isEmpty ? result.output : result.error)
                }
                self.refreshBrewServices()
            }
        }
    }
    
    func installBrewService(_ name: String) {
        isBrewLoading = true
        ShellRunner.installBrewService(name) { result in
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(title: "Install Failed", message: result.error.isEmpty ? result.output : result.error)
                }
                self.refreshBrewServices()
            }
        }
    }
    
    func uninstallBrewService(_ service: BrewService) {
        isBrewLoading = true
        ShellRunner.uninstallBrewService(service.name) { result in
            DispatchQueue.main.async {
                if result.status != 0 {
                    self.showError(title: "Uninstall Failed", message: result.error.isEmpty ? result.output : result.error)
                }
                self.refreshBrewServices()
            }
        }
    }
}
