import SwiftUI
import Combine

struct NoteItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var content: String
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var color: String = "blue" // blue, red, orange, green, purple
    
    // Desktop Widget Properties
    var x: Double?
    var y: Double?
    var width: Double?
    var height: Double?
    var isLocked: Bool = false
    var isDesktopWidget: Bool = false
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
    
    // AI Chat State
    @Published var chatMessages: [AIChatMessage] = []
    @Published var chatSettings: AIChatSettings = AIChatSettings()
    @Published var isChatSending: Bool = false
    @Published var chatInput: String = ""
    
    private let storageKey = "UserCommands_v1"
    private let bookmarkKey = "UserBookmarks_v1"
    private let noteKey = "UserNotes_v1"
    private let chatSettingsKey = "UserChatSettings_v1"
    private let viewModeKey = "isBookmarkGridView"
    
    init() {
        loadCommands()
        loadBookmarks()
        loadNotes()
        loadChatSettings()
        self.isBookmarkGridView = UserDefaults.standard.object(forKey: viewModeKey) as? Bool ?? true
        setupCloudSync()
        
        // Initial Greeting
        if chatMessages.isEmpty {
            chatMessages.append(AIChatMessage(role: .assistant, content: "你好！我是你的 AI 助手。请在设置中配置 API Key 后开始交谈。"))
        }
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
        loadChatSettings()
    }
    
    func saveViewMode() {
        UserDefaults.standard.set(isBookmarkGridView, forKey: viewModeKey)
        NSUbiquitousKeyValueStore.default.set(isBookmarkGridView, forKey: viewModeKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    // MARK: - Persistence
    func loadChatSettings() {
        let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: chatSettingsKey)
        let localData = UserDefaults.standard.data(forKey: chatSettingsKey)
        
        if let data = cloudData ?? localData,
           let decoded = try? JSONDecoder().decode(AIChatSettings.self, from: data) {
            self.chatSettings = decoded
        }
    }
    
    func saveChatSettings() {
        if let encoded = try? JSONEncoder().encode(chatSettings) {
            UserDefaults.standard.set(encoded, forKey: chatSettingsKey)
            NSUbiquitousKeyValueStore.default.set(encoded, forKey: chatSettingsKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    func clearChatHistory() {
        chatMessages.removeAll()
        chatMessages.append(AIChatMessage(role: .assistant, content: "对话已重置。"))
    }
    
    func sendChatMessage() {
        let content = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        let userMsg = AIChatMessage(role: .user, content: content)
        chatMessages.append(userMsg)
        chatInput = ""
        isChatSending = true
        
        let provider = chatSettings.selectedProvider
        let apiKey = chatSettings.getApiKey(for: provider)
        let model = chatSettings.getModel(for: provider)
        let baseUrl = chatSettings.getBaseUrl(for: provider)
        
        if provider != .custom && apiKey.isEmpty {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.chatMessages.append(AIChatMessage(role: .assistant, content: "请先点击右上角设置图标配置 \(provider.rawValue) 的 API Key。", isError: true))
                self.isChatSending = false
            }
            return
        }
        
        Task {
            let aiMsgId = UUID()
            let aiMsg = AIChatMessage(id: aiMsgId, role: .assistant, content: "")
            
            await MainActor.run {
                self.chatMessages.append(aiMsg)
                self.isChatSending = true
            }
            
            do {
                var fullContent = ""
                for try await chunk in AIService.stream(provider: provider, apiKey: apiKey, model: model, messages: chatMessages.dropLast(), baseUrl: baseUrl) {
                    fullContent += chunk
                    await MainActor.run {
                        if let index = self.chatMessages.firstIndex(where: { $0.id == aiMsgId }) {
                            self.chatMessages[index].content = fullContent
                        }
                    }
                }
                await MainActor.run { self.isChatSending = false }
            } catch {
                await MainActor.run {
                    self.isChatSending = false
                    if let index = self.chatMessages.firstIndex(where: { $0.id == aiMsgId }) {
                        self.chatMessages[index].content += "\n[Error: \(error.localizedDescription)]"
                        self.chatMessages[index].isError = true
                    }
                }
            }
        }
    }
    
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
    
    func updateNote(_ note: NoteItem, saveImmediately: Bool = true) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            if saveImmediately {
                saveNotes()
            }
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

// MARK: - AI Service

class AIService {
    enum AIError: Error {
        case invalidURL
        case noData
        case decodingError
        case apiError(String)
    }
    
    static func stream(provider: AIProvider, apiKey: String, model: String, messages: [AIChatMessage], baseUrl: String? = nil) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    switch provider {
                    case .openai, .deepseek, .custom:
                        try await streamOpenAICompatible(provider: provider, apiKey: apiKey, model: model, messages: messages, baseUrl: baseUrl, continuation: continuation)
                    case .claude:
                        try await streamClaude(apiKey: apiKey, model: model, messages: messages, continuation: continuation)
                    case .gemini:
                        // Gemini fallback (simplified)
                        continuation.yield("Gemini streaming is currently handled via one-shot in this version.")
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private static func streamOpenAICompatible(provider: AIProvider, apiKey: String, model: String, messages: [AIChatMessage], baseUrl: String?, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let finalUrl: URL?
        if let baseUrl = baseUrl, !baseUrl.isEmpty {
            if baseUrl.contains("/chat/completions") { finalUrl = URL(string: baseUrl) }
            else { finalUrl = URL(string: baseUrl)?.appendingPathComponent("chat/completions") }
        } else {
            let defaultString = provider == .deepseek ? "https://api.deepseek.com/v1/chat/completions" : "https://api.openai.com/v1/chat/completions"
            finalUrl = URL(string: defaultString)
        }
        
        guard let url = finalUrl else { throw AIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let apiMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = ["model": model, "messages": apiMessages, "stream": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
             throw AIError.apiError("API Error")
        }
        
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonStr = line.dropFirst(6)
                if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let delta = first["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    continuation.yield(content)
                }
            }
        }
        continuation.finish()
    }
    
    private static func streamClaude(apiKey: String, model: String, messages: [AIChatMessage], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
         guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw AIError.invalidURL }
         var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
         request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
         let apiMessages = messages.filter { $0.role != .system }.map { ["role": $0.role.rawValue, "content": $0.content] }
         var body: [String: Any] = ["model": model, "max_tokens": 1024, "messages": apiMessages, "stream": true]
         if let systemMsg = messages.first(where: { $0.role == .system }) { body["system"] = systemMsg.content }
         request.httpBody = try JSONSerialization.data(withJSONObject: body)
         let (bytes, response) = try await URLSession.shared.bytes(for: request)
         guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw AIError.apiError("Claude API Error") }
         for try await line in bytes.lines {
             if line.hasPrefix("data: ") {
                 let jsonStr = line.dropFirst(6)
                 if let data = jsonStr.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = json["type"] as? String {
                     if type == "content_block_delta", let delta = json["delta"] as? [String: Any], let text = delta["text"] as? String { continuation.yield(text) }
                 }
             }
         }
         continuation.finish()
    }
}
