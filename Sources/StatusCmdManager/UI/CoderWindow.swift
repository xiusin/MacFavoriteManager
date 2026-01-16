import SwiftUI
import AppKit

// MARK: - Coder Window

class CoderWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class CoderWindowController: ObservableObject {
    static let shared = CoderWindowController()
    
    var window: CoderWindow?
    
    @Published var isVisible: Bool = false
    
    func show() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func close() {
        window?.close()
        isVisible = false
    }
    
    private func createWindow() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = 700
        let height: CGFloat = 500
        
        let initialRect = NSRect(
            x: screenRect.midX - width/2,
            y: screenRect.midY - height/2,
            width: width,
            height: height
        )
        
        window = CoderWindow(
            contentRect: initialRect,
            styleMask: [.borderless, .resizable], 
            backing: .buffered,
            defer: false
        )
        
        window?.level = .normal
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = true
        window?.invalidateShadow()
        window?.isMovableByWindowBackground = true
        
        let contentView = CoderView(controller: self)
        window?.contentView = NSHostingView(rootView: contentView)
    }
}

// MARK: - View

struct CoderView: View {
    @ObservedObject var controller: CoderWindowController
    
    @State private var code: String = "#!/bin/bash\necho 'Hello World'"
    @State private var output: String = "Ready..."
    @State private var language: Language = .shell
    @State private var isRunning: Bool = false
    @State private var isHovering: Bool = false
    
    enum Language: String, CaseIterable, Identifiable {
        case shell = "Shell"
        case python = "Python"
        case swift = "Swift"
        case node = "Node.js"
        case go = "Go"
        case rust = "Rust"
        case zig = "Zig"
        case php = "PHP"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .shell: return "terminal"
            case .python: return "ladybug"
            case .swift: return "swift"
            case .node: return "hexagon"
            case .go: return "g.circle"
            case .rust: return "gearshape.2"
            case .zig: return "z.circle"
            case .php: return "p.circle"
            }
        }
        
        var template: String {
            switch self {
            case .shell: return "#!/bin/bash\necho 'Hello World'"
            case .python: return "print('Hello Python')"
            case .swift: return "print(\"Hello Swift\")"
            case .node: return "console.log('Hello Node')"
            case .go: return "package main\nimport \"fmt\"\nfunc main() {\n    fmt.Println(\"Hello Go\")\n}"
            case .rust: return "fn main() {\n    println!(\"Hello Rust\");\n}"
            case .zig: return "const std = @import(\"std\");\n\npub fn main() !void {\n    const stdout = std.io.getStdOut().writer();\n    try stdout.print(\"Hello Zig\\n\", .{});\n}"
            case .php: return "<?php\necho \"Hello PHP\";\n?>"
            }
        }
        
        var keywords: [String] {
            switch self {
            case .shell: return ["echo", "if", "else", "fi", "then", "for", "while", "do", "done", "case", "esac", "function", "return", "exit"]
            case .python: return ["def", "class", "if", "elif", "else", "while", "for", "in", "try", "except", "import", "from", "return", "print", "True", "False", "None"]
            case .swift: return ["func", "var", "let", "if", "else", "guard", "return", "class", "struct", "enum", "extension", "import", "print", "true", "false"]
            case .node: return ["const", "let", "var", "function", "if", "else", "return", "import", "require", "console", "true", "false", "null", "undefined"]
            case .go: return ["func", "package", "import", "var", "const", "type", "struct", "interface", "if", "else", "return", "for", "range", "go", "chan", "true", "false", "nil"]
            case .rust: return ["fn", "let", "mut", "if", "else", "match", "return", "struct", "enum", "impl", "use", "mod", "pub", "crate", "true", "false"]
            case .zig: return ["const", "var", "fn", "pub", "return", "if", "else", "switch", "while", "for", "try", "catch", "struct", "enum", "union", "error", "true", "false", "null", "undefined", "void", "import"]
            case .php: return ["function", "echo", "if", "else", "elseif", "while", "for", "foreach", "return", "class", "public", "private", "protected", "new", "null", "true", "false"]
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active, cornerRadius: 16)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    // Close Button
                    Button(action: { controller.close() }) {
                        Circle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 12, height: 12)
                            .overlay(isHovering ? Image(systemName: "xmark").font(.system(size: 8)).foregroundColor(.black.opacity(0.5)) : nil)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Code Runner")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Language Picker
                    Picker("", selection: $language) {
                        ForEach(Language.allCases) {
                            lang in
                            HStack {
                                Image(systemName: lang.icon)
                                Text(lang.rawValue)
                            }.tag(lang)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 110)
                    .onChange(of: language) { newVal in
                        // Only reset if empty or default template to avoid losing work
                        if code.isEmpty || Language.allCases.map({$0.template}).contains(code) {
                            code = newVal.template
                        }
                    }
                    
                    // Run Button
                    Button(action: runCode) {
                        ZStack {
                            // Background
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.green.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                                .shadow(color: Color.green.opacity(0.3), radius: 4, y: 2)
                            
                            // Content
                            HStack(spacing: 6) {
                                if isRunning {
                                    TinyLoadingView()
                                }
                                Text(isRunning ? "Running" : "Run")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 28) // Fixed size prevents jumping
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isRunning)
                    .opacity(isRunning ? 0.8 : 1.0)
                }
                .padding(12)
                .background(Color.black.opacity(0.05)) // Lighter header background
                
                // Editor Area (With Syntax Highlighting)
                CodeEditorView(text: $code, language: language)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Divider
                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
                
                // Output Area
                ScrollView {
                    Text(output)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 140)
                .background(Color.black.opacity(0.2)) // Slightly darker for output
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // Ensure content doesn't bleed
        }
        .onHover { isHovering = $0 }
    }
    
    func runCode() {
        isRunning = true
        output = "Compiling & Running..."
        
        CodeRunner.run(language: language, code: code) { result in
            DispatchQueue.main.async {
                self.output = result
                self.isRunning = false
            }
        }
    }
}

// MARK: - Tiny Loader
struct TinyLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white, lineWidth: 1.5)
            .frame(width: 10, height: 10)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Code Editor with Syntax Highlighting

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var language: CoderView.Language
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let textView = scrollView.documentView as! NSTextView
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        
        // Essential for code editing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = false
        
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        context.coordinator.parent = self // Update parent ref for language change
        
        if textView.string != text {
            textView.string = text
            context.coordinator.highlightSyntax(textView: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            highlightSyntax(textView: textView)
        }
        
        // MARK: - Completion (Syntax Hinting)
        func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            // 1. Get the current partial word
            guard let textStorage = textView.textStorage else { return words }
            let wholeString = textStorage.string as NSString
            
            // Safety check range
            if charRange.location == NSNotFound || charRange.length > wholeString.length {
                return words
            }
            
            let partialString = wholeString.substring(with: charRange)
            
            // 2. Get keywords for current language
            let keywords = parent.language.keywords
            
            // 3. Filter matches (Case insensitive)
            // If partial string is empty, we might want to return all? Or none. Usually only return if length > 0
            var matches: [String] = []
            
            if partialString.isEmpty {
                // If user forces completion on empty space, show all keywords?
                // Standard behavior is usually context aware, but here we just dump keywords.
                matches = keywords
            } else {
                matches = keywords.filter { $0.lowercased().hasPrefix(partialString.lowercased()) }
            }
            
            // 4. Combine with standard words if needed, or just return keywords
            return matches.sorted()
        }
        
        func highlightSyntax(textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let string = textStorage.string
            let range = NSRange(location: 0, length: string.utf16.count)
            
            // Reset attributes
            textStorage.removeAttribute(.foregroundColor, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: range)
            
            // 1. Strings: "..."
            applyRegex(pattern: "\"[^\"]*\"", color: .systemOrange, storage: textStorage, string: string)
            applyRegex(pattern: "'[^']*'", color: .systemOrange, storage: textStorage, string: string)
            
            // 2. Comments: //... or #...
            applyRegex(pattern: "//.*
", color: .systemGray, storage: textStorage, string: string)
            applyRegex(pattern: "#.*\n", color: .systemGray, storage: textStorage, string: string)
            
            // 3. Keywords
            let keywords = parent.language.keywords.joined(separator: "|")
            applyRegex(pattern: "\\b(\(keywords))\\b", color: .systemPink, storage: textStorage, string: string)
            
            // 4. Numbers
            applyRegex(pattern: "\\b\\d+\\b", color: .systemBlue, storage: textStorage, string: string)
        }
        
        private func applyRegex(pattern: String, color: NSColor, storage: NSTextStorage, string: String) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            regex.enumerateMatches(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)) { match, _, _ in
                if let matchRange = match?.range {
                    storage.addAttribute(.foregroundColor, value: color, range: matchRange)
                }
            }
        }
    }
}

// MARK: - Runner Logic

class CodeRunner {
    static func run(language: CoderView.Language, code: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory
            let uuid = UUID().uuidString
            let sourceFile: URL
            let interpreter: String
            var args: [String] = []
            
            // Determine paths and extension
            switch language {
            case .shell: sourceFile = tempDir.appendingPathComponent("\(uuid).sh"); interpreter = "/bin/zsh"
            case .python: sourceFile = tempDir.appendingPathComponent("\(uuid).py"); interpreter = "/usr/bin/python3"
            case .swift: sourceFile = tempDir.appendingPathComponent("\(uuid).swift"); interpreter = "/usr/bin/swift"
            case .node: sourceFile = tempDir.appendingPathComponent("\(uuid).js"); interpreter = findExec("node")
            case .php: sourceFile = tempDir.appendingPathComponent("\(uuid).php"); interpreter = findExec("php")
            
            // Compiled Languages: Treat differently? 
            // For simplicity, we use `go run`, `zig run`. Rust needs compile.
            case .go: sourceFile = tempDir.appendingPathComponent("\(uuid).go"); interpreter = findExec("go"); args = ["run"]
            case .zig: sourceFile = tempDir.appendingPathComponent("\(uuid).zig"); interpreter = findExec("zig"); args = ["run"]
            case .rust:
                sourceFile = tempDir.appendingPathComponent("\(uuid).rs")
                interpreter = findExec("rustc") // Needs special handling
            }
            
            do {
                try code.write(to: sourceFile, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sourceFile.path)
                
                // Special handling for Rust (Compile then Run)
                if language == .rust {
                    let binaryPath = tempDir.appendingPathComponent(uuid)
                    let compileRes = runCommand(interpreter, args: [sourceFile.path, "-o", binaryPath.path])
                    if !compileRes.1.isEmpty { // Compilation error
                        completion("Compilation Error:\n" + compileRes.1)
                        return
                    }
                    let runRes = runCommand(binaryPath.path, args: [])
                    completion(runRes.0 + (runRes.1.isEmpty ? "" : "\nStderr:\n" + runRes.1))
                    try? FileManager.default.removeItem(at: binaryPath)
                    return
                }
                
                // Standard Interpreters / Runners
                let finalArgs = args + [sourceFile.path]
                let res = runCommand(interpreter, args: finalArgs)
                
                var output = res.0
                if !res.1.isEmpty { output += "\n[Stderr]:\n" + res.1 }
                
                try? FileManager.default.removeItem(at: sourceFile)
                completion(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(No Output)" : output)
                
            } catch {
                completion("Execution Error: \(error.localizedDescription)")
            }
        }
    }
    
    static func findExec(_ name: String) -> String {
        let paths = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)", "/bin/\(name)"]
        for p in paths { if FileManager.default.fileExists(atPath: p) { return p } }
        return name // hope it's in PATH
    }
    
    static func runCommand(_ cmd: String, args: [String]) -> (String, String) {
        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: cmd)
        task.arguments = args
        task.standardOutput = outPipe
        task.standardError = errPipe
        
        // Inherit system environment to ensure HOME, USER, GOCACHE etc. are available
        var env = ProcessInfo.processInfo.environment
        // Ensure PATH includes common locations
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + currentPath
        // Explicitly ensure HOME is set if missing (unlikely on macOS but safe)
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        
        task.environment = env
        
        do {
            try task.run()
            task.waitUntilExit()
            let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (out, err)
        } catch {
            return ("", "Failed to launch: \(error.localizedDescription)")
        }
    }
}

// Helpers reused from module
// (VisualEffectBlur should be available from DesktopNoteWindow)
