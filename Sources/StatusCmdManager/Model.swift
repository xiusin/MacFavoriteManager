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
        
        // 环境变量
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = env
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            
            return ShellResult(
                status: task.terminationStatus,
                output: String(data: outData, encoding: .utf8) ?? "",
                error: String(data: errData, encoding: .utf8) ?? ""
            )
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
    
    static func listBrewServices() -> [BrewService] {
        let cmd = "/opt/homebrew/bin/brew services list"
        let result = run(cmd)
        guard result.status == 0 else { return [] }
        
        let lines = result.output.components(separatedBy: .newlines)
        var services: [BrewService] = []
        
        for line in lines.dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if let name = parts.first {
                services.append(BrewService(name: String(name)))
            }
        }
        return services
    }
}

struct BrewService: Identifiable, Hashable {
    let id = UUID()
    let name: String
}

// 智能图标匹配器
class IconMatcher {
    static let mapping: [String: String] = [
        // 数据库
        "mysql": "m.circle.fill",
        "mariadb": "m.circle",
        "postgres": "p.circle.fill",
        "postgresql": "p.circle.fill",
        "redis": "r.square.fill",
        "mongo": "leaf.fill",
        "mongodb": "leaf.fill",
        "sqlite": "s.circle",
        "db": "cylinder.split.1x2",
        "database": "cylinder.split.1x2",
        "elasticsearch": "e.circle.fill",
        "etcd": "e.square",
        "memcached": "m.square",
        "influxdb": "i.circle",
        "oracle": "o.circle.fill",
        "clickhouse": "c.circle.fill",
        
        // Web 服务器 & 代理
        "nginx": "n.circle.fill",
        "apache": "a.circle.fill",
        "httpd": "globe",
        "caddy": "c.circle",
        "tomcat": "ant.fill",
        "traefik": "t.circle.fill",
        "haproxy": "h.circle",
        "squid": "s.square",
        
        // 容器与虚拟化
        "docker": "shippingbox.fill",
        "k8s": "k.circle.fill",
        "kubernetes": "k.circle.fill",
        "helm": "h.square.fill",
        "podman": "p.square.fill",
        "vm": "desktopcomputer",
        "virtualbox": "v.square",
        "vmware": "v.circle.fill",
        "vagrant": "v.square.fill",
        
        // 语言与运行时
        "python": "p.square.fill",
        "node": "n.square.fill",
        "nodejs": "n.square.fill",
        "java": "cup.and.saucer.fill",
        "php": "p.circle",
        "go": "g.circle.fill",
        "golang": "g.circle.fill",
        "rust": "r.circle.fill",
        "ruby": "diamond.fill",
        "swift": "swift",
        "dart": "d.circle.fill",
        "flutter": "f.circle.fill",
        "c": "c.square.fill",
        "cpp": "c.square",
        "csharp": "number.square.fill",
        "javascript": "js",
        "typescript": "ts",
        "kotlin": "k.square.fill",
        "scala": "s.square.fill",
        
        // 开发工具 & IDE
        "git": "point.topleft.down.curvedto.point.bottomright.up",
        "github": "g.circle",
        "gitlab": "g.square",
        "vscode": "v.square.fill",
        "xcode": "hammer.fill",
        "intellij": "i.square.fill",
        "webstorm": "w.square.fill",
        "pycharm": "p.square.fill",
        "vim": "v.circle",
        "nvim": "n.circle",
        "npm": "n.square",
        "yarn": "y.square.fill",
        "pnpm": "p.square",
        "maven": "m.circle",
        "gradle": "g.square",
        
        // 监控 & 日志
        "prometheus": "p.circle.fill",
        "grafana": "g.circle.fill",
        "kibana": "k.circle",
        "logstash": "l.circle",
        "sentry": "s.circle.fill",
        "jaeger": "j.circle.fill",
        
        // 消息队列
        "kafka": "k.square.fill",
        "rabbitmq": "r.square.fill",
        "rocketmq": "r.circle.fill",
        "activemq": "a.circle",
        "pulsar": "p.circle",
        
        // 云服务
        "aws": "a.square.fill",
        "azure": "a.circle.fill",
        "gcp": "g.square.fill",
        "aliyun": "a.circle",
        "tencent": "t.circle",
        
        // 常用软件
        "ssh": "terminal.fill",
        "vpn": "lock.shield.fill",
        "postman": "paperplane.fill",
        "slack": "s.circle.fill",
        "discord": "d.circle.fill",
        "teams": "t.square.fill",
        "zoom": "z.circle.fill",
        "chrome": "c.circle.fill",
        "firefox": "f.circle.fill"
    ]
    
    static func suggest(for name: String) -> String {
        let lowerName = name.lowercased()
        
        // 1. 尝试完全匹配键名
        if let icon = mapping[lowerName] { return icon }
        
        // 2. 尝试包含匹配
        for (key, icon) in mapping {
            if lowerName.contains(key) { return icon }
        }
        
        // 3. 尝试模糊匹配图标库名称
        let cleanName = lowerName.replacingOccurrences(of: " ", with: "")
                                 .replacingOccurrences(of: "-", with: "")
                                 .replacingOccurrences(of: "_", with: "")
        
        let allIcons = iconLibrary.flatMap { $0.icons }
        if let match = allIcons.first(where: { $0.replacingOccurrences(of: ".", with: "").contains(cleanName) }) {
            return match
        }

        return "terminal"
    }
}

// 图标库分类结构
struct IconCategory: Identifiable {
    let id = UUID()
    let title: String
    let icons: [String]
}

// 庞大的预置图标库
let iconLibrary: [IconCategory] = [
    IconCategory(title: "常用软件", icons: [
        "terminal.fill", "swift", "hammer.fill", "cup.and.saucer.fill", "diamond.fill",
        "leaf.fill", "shippingbox.fill", "lock.shield.fill", "paperplane.fill",
        "safari.fill", "app.connected.to.app.below.fill", "gearshape.fill", 
        "network", "globe", "server.rack", "cpu.fill"
    ]),
    IconCategory(title: "语言 & 框架 (A-Z)", icons: [
        "a.circle.fill", "b.circle.fill", "c.circle.fill", "d.circle.fill", "e.circle.fill",
        "f.circle.fill", "g.circle.fill", "h.circle.fill", "i.circle.fill", "j.circle.fill",
        "k.circle.fill", "l.circle.fill", "m.circle.fill", "n.circle.fill", "o.circle.fill",
        "p.circle.fill", "q.circle.fill", "r.circle.fill", "s.circle.fill", "t.circle.fill",
        "u.circle.fill", "v.circle.fill", "w.circle.fill", "x.circle.fill", "y.circle.fill", "z.circle.fill"
    ]),
    IconCategory(title: "开发工具", icons: [
        "terminal", "chevron.left.forwardslash.chevron.right", "curlybraces", 
        "applescript", "ladybug.fill", "ant.fill", "hexagon.fill", 
        "c.square.fill", "j.square.fill", "p.square.fill", "n.square.fill", 
        "r.square.fill", "s.square.fill", "v.square.fill", "number.square.fill",
        "hammer", "wrench.and.screwdriver.fill", "testtube.2", "command",
        "keyboard.macwindow", "briefcase.fill", "puzzlepiece.fill"
    ]),
    IconCategory(title: "数据库 & 存储", icons: [
        "cylinder", "cylinder.split.1x2", "cylinder.split.1x2.fill", 
        "externaldrive.fill", "externaldrive.connected.to.line.below", 
        "internaldrive.fill", "opticaldisc", "sdcard.fill", "xserve", 
        "folder.fill", "tray.full.fill", "archivebox.fill", "doc.on.doc.fill", 
        "icloud.fill", "chart.xyaxis.line", "magnifyingglass.circle.fill"
    ]),
    IconCategory(title: "网络 & 云", icons: [
        "cloud.fill", "wifi", "wifi.router.fill", "airport.extreme", 
        "dot.radiowaves.left.and.right", "antenna.radiowaves.left.and.right", 
        "shield.checkerboard", "arrow.left.arrow.right", "link", 
        "network.badge.shield.half.filled", "bolt.horizontal.fill", "lock.square.fill"
    ]),
    IconCategory(title: "状态 & 指示", icons: [
        "play.fill", "pause.fill", "stop.fill", "record.circle",
        "checkmark.circle.fill", "xmark.octagon.fill", "exclamationmark.triangle.fill",
        "bolt.fill", "flame.fill", "drop.fill", "sun.max.fill", "moon.stars.fill",
        "bell.fill", "alarm.fill", "hourglass", "timer", "speedometer", "gauge"
    ]),
    IconCategory(title: "业务 & 通讯", icons: [
        "cart.fill", "creditcard.fill", "banknote.fill", "chart.bar.fill", "chart.pie.fill",
        "envelope.fill", "phone.fill", "video.fill", "mic.fill", "person.fill", "person.2.fill",
        "house.fill", "building.2.fill", "bag.fill", "gift.fill", "location.fill", "ticket.fill", "calendar"
    ])
]

// 扁平化列表用于向后兼容或搜索
let presetIcons: [String] = iconLibrary.flatMap { $0.icons }

// MARK: - Bookmark Models

struct BookmarkItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var iconUrl: String? // 远程图标 URL
    var addedAt: Date = Date()
}

struct WebMetadata {
    var title: String?
    var iconUrl: String?
}

// 网页元数据抓取器
class WebMetadataFetcher {
    static func fetch(urlStr: String, completion: @escaping (WebMetadata) -> Void) {
        guard let url = URL(string: urlStr) else {
            completion(WebMetadata(title: nil, iconUrl: nil))
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        // 模拟浏览器 User-Agent，避免被屏蔽
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
            else {
                completion(WebMetadata(title: nil, iconUrl: nil))
                return
            }
            
            let finalUrl = response?.url ?? url // 使用最终 URL 处理重定向
            
            // 1. 提取标题
            // <title>...</title> 可能包含换行符或属性
            var title: String? = nil
            if let regex = try? NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title>", options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let range = Range(match.range(at: 1), in: html) {
                title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // 2. 提取图标
            // 优先级: apple-touch-icon > og:image (如果有意当作图标) > icon > shortcut icon > favicon.ico
            var iconUrl: String? = nil
            
            let iconRelations = ["apple-touch-icon", "icon", "shortcut icon"]
            
            // 辅助查找函数
            func findHref(rel: String) -> String? {
                // 匹配 <link ... rel="x" ... href="y" ...> 或 <link ... href="y" ... rel="x" ...>
                // 简化逻辑：找到包含 rel="value" 的 link 标签，然后提取 href
                // 正则说明：<link (任意非>) rel=['"]value['"] (任意非>) href=['"](目标)['"]
                let pattern1 = "<link[^>]*rel=[\"']\(rel)[\"'][^>]*href=[\"']([^\"']+)[\"']"
                // 正则说明：<link (任意非>) href=['"](目标)['"] (任意非>) rel=['"]value['"]
                let pattern2 = "<link[^>]*href=[\"']([^\"']+)[\"'][^>]*rel=[\"']\(rel)[\"']"
                
                if let match = firstMatch(pattern: pattern1, in: html) { return match }
                if let match = firstMatch(pattern: pattern2, in: html) { return match }
                return nil
            }
            
            for rel in iconRelations {
                if let href = findHref(rel: rel), let resolved = resolveUrl(base: finalUrl, relative: href) {
                    iconUrl = resolved
                    break
                }
            }
            
            // 尝试 Open Graph Image 作为备选 (通常很大，但在没有 favicon 时也好过没有)
            if iconUrl == nil {
                let ogPattern = "<meta[^>]*property=[\"']og:image[\"'][^>]*content=[\"']([^\"']+)[\"']"
                if let href = firstMatch(pattern: ogPattern, in: html), let resolved = resolveUrl(base: finalUrl, relative: href) {
                    iconUrl = resolved
                }
            }
            
            // 默认 favicon
            if iconUrl == nil {
                iconUrl = resolveUrl(base: finalUrl, relative: "/favicon.ico")
            }
            
            DispatchQueue.main.async {
                completion(WebMetadata(title: title, iconUrl: iconUrl))
            }
        }
        task.resume()
    }
    
    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        if let first = results.first, first.numberOfRanges >= 2 {
            return nsString.substring(with: first.range(at: 1))
        }
        return nil
    }
    
    private static func resolveUrl(base: URL, relative: String) -> String? {
        if relative.hasPrefix("http") { return relative }
        if relative.hasPrefix("//") { return "https:" + relative }
        return URL(string: relative, relativeTo: base)?.absoluteString
    }
}
