import Foundation

// 数据模型
struct CommandItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description: String
    var iconName: String = "terminal"
    var startCommand: String
    var stopCommand: String
    var checkCommand: String
}

// Shell 执行结果
struct ShellResult {
    let status: Int32
    let output: String
    let error: String
}

// Shell 执行器
class ShellRunner {
    static func run(_ command: String) -> ShellResult {
        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = env
        do {
            try task.run()
            task.waitUntilExit()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            return ShellResult(status: task.terminationStatus, output: String(data: outData, encoding: .utf8) ?? "", error: String(data: errData, encoding: .utf8) ?? "")
        } catch {
            return ShellResult(status: -1, output: "", error: "Failed to launch process: \(error)")
        }
    }
    static func runAsync(_ command: String, completion: @escaping (ShellResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = run(command)
            DispatchQueue.main.async { completion(result) }
        }
    }
    static func listInstalledFormulae() -> Set<String> {
        let result = run("/opt/homebrew/bin/brew list --formula -1")
        guard result.status == 0 else { return [] }
        let lines = result.output.components(separatedBy: .newlines)
        return Set(lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
    static func searchBrew(query: String, completion: @escaping ([String]) -> Void) {
        runAsync("/opt/homebrew/bin/brew search \(query)") { result in
            guard result.status == 0 else { completion([]); return }
            let lines = result.output.components(separatedBy: .newlines)
            var matches: [String] = []
            for line in lines {
                if line.starts(with: "==>") || line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                let parts = line.components(separatedBy: .whitespaces)
                for part in parts {
                    let clean = part.trimmingCharacters(in: .whitespaces)
                    if !clean.isEmpty && !clean.contains("Casks") { matches.append(clean) }
                }
            }
            completion(matches)
        }
    }
    static func listBrewServices() -> [BrewService] {
        let result = run("/opt/homebrew/bin/brew services list")
        guard result.status == 0 else { return [] }
        let lines = result.output.components(separatedBy: .newlines)
        var services: [BrewService] = []
        for line in lines.dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 2, let name = parts.first {
                services.append(BrewService(name: String(name), status: String(parts[1]), user: parts.count >= 3 ? String(parts[2]) : nil))
            } else if let name = parts.first {
                 services.append(BrewService(name: String(name), status: "unknown", user: nil))
            }
        }
        return services
    }
    static func operateBrewService(action: String, service: String, completion: @escaping (ShellResult) -> Void) {
        runAsync("/opt/homebrew/bin/brew services \(action) \(service)", completion: completion)
    }
    static func installBrewService(_ name: String, completion: @escaping (ShellResult) -> Void) {
        runAsync("/opt/homebrew/bin/brew install \(name)", completion: completion)
    }
    static func uninstallBrewService(_ name: String, completion: @escaping (ShellResult) -> Void) {
        runAsync("/opt/homebrew/bin/brew uninstall \(name)", completion: completion)
    }
}

struct BrewService: Identifiable, Hashable {
    let id = UUID(); let name: String; var status: String = "unknown"; var user: String? = nil
}

class IconMatcher {
    static let mapping: [String: String] = ["mysql": "m.circle.fill", "redis": "r.square.fill", "mongo": "leaf.fill", "docker": "shippingbox.fill", "python": "p.square.fill", "node": "n.square.fill"]
    static func suggest(for name: String) -> String {
        let lowerName = name.lowercased()
        if let icon = mapping[lowerName] { return icon }
        for (key, icon) in mapping { if lowerName.contains(key) { return icon } }
        return "terminal"
    }
}

struct IconCategory: Identifiable { let id = UUID(); let title: String; let icons: [String] }
let iconLibrary: [IconCategory] = [
    IconCategory(title: "常用软件", icons: ["terminal.fill", "swift", "hammer.fill", "gearshape.fill", "network", "globe"]),
    IconCategory(title: "开发工具", icons: ["terminal", "curlybraces", "hammer", "wrench.and.screwdriver.fill", "briefcase.fill"])
]
let presetIcons: [String] = iconLibrary.flatMap { $0.icons }

// MARK: - Bookmark Models
struct BookmarkItem: Identifiable, Codable, Equatable {
    var id = UUID(); var title: String; var url: String; var iconUrl: String?; var addedAt: Date = Date()
}
struct WebMetadata { var title: String?; var iconUrl: String? }

// MARK: - AI Models
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openai = "OpenAI", deepseek = "DeepSeek", claude = "Claude", gemini = "Gemini", custom = "Custom (API)"
    var id: String { self.rawValue }
    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o"; case .deepseek: return "deepseek-chat"; case .claude: return "claude-3-5-sonnet-20240620"; case .gemini: return "gemini-pro"; case .custom: return ""
        }
    }
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    var id = UUID(); var role: MessageRole; var content: String; var date: Date = Date(); var isError: Bool = false
    enum MessageRole: String, Codable { case user = "user", assistant = "assistant", system = "system" }
}

struct AIChatSettings: Codable {
    var selectedProvider: AIProvider = .deepseek
    var apiKeys: [AIProvider: String] = [:]
    var selectedModels: [AIProvider: String] = [:]
    var customBaseUrls: [AIProvider: String] = [:]
    func getApiKey(for provider: AIProvider) -> String { apiKeys[provider] ?? "" }
    func getModel(for provider: AIProvider) -> String { selectedModels[provider] ?? provider.defaultModel }
    func getBaseUrl(for provider: AIProvider) -> String { customBaseUrls[provider] ?? "" }
}

class WebMetadataFetcher {
    static func fetch(urlStr: String, completion: @escaping (WebMetadata) -> Void) {
        guard let url = URL(string: urlStr) else { completion(WebMetadata(title: nil, iconUrl: nil)); return }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { completion(WebMetadata(title: nil, iconUrl: nil)); return }
            let finalUrl = response?.url ?? url
            var title: String? = nil
            if let regex = try? NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title>", options: .caseInsensitive), let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)), let range = Range(match.range(at: 1), in: html) { title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines) }
            var iconUrl: String? = nil
            func firstMatch(pattern: String, in text: String) -> String? {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
                let nsString = text as NSString
                let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
                if let first = results.first, first.numberOfRanges >= 2 { return nsString.substring(with: first.range(at: 1)) }
                return nil
            }
            func resolveUrl(base: URL, relative: String) -> String? {
                if relative.hasPrefix("http") { return relative }; if relative.hasPrefix("//") { return "https:" + relative }; return URL(string: relative, relativeTo: base)?.absoluteString
            }
            let iconRelations = ["apple-touch-icon", "icon", "shortcut icon"]
            for rel in iconRelations {
                let pattern1 = "<link[^>]*rel=\"\(rel)\"[^>]*href=\"([^\"]+)\""; let pattern2 = "<link[^>]*href=\"([^\"]+)\"[^>]*rel=\"\(rel)\""
                if let match = firstMatch(pattern: pattern1, in: html) { iconUrl = resolveUrl(base: finalUrl, relative: match); break }
                if let match = firstMatch(pattern: pattern2, in: html) { iconUrl = resolveUrl(base: finalUrl, relative: match); break }
            }
            if iconUrl == nil { iconUrl = resolveUrl(base: finalUrl, relative: "/favicon.ico") }
            DispatchQueue.main.async { completion(WebMetadata(title: title, iconUrl: iconUrl)) }
        }
        task.resume()
    }
}
