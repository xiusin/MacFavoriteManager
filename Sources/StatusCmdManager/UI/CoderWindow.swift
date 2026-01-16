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
        if window == nil { createWindow() }
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
        let width: CGFloat = 720
        let height: CGFloat = 520
        let initialRect = NSRect(x: screenRect.midX - width/2, y: screenRect.midY - height/2, width: width, height: height)
        
        window = CoderWindow(contentRect: initialRect, styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
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
    
    enum Language: String, CaseIterable, Identifiable {
        case shell = "Shell", python = "Python", swift = "Swift", node = "Node.js", go = "Go", rust = "Rust", zig = "Zig", php = "PHP"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .shell: return "terminal"; case .python: return "ladybug"; case .swift: return "swift"; case .node: return "hexagon"; case .go: return "g.circle"; case .rust: return "gearshape.2"; case .zig: return "z.circle"; case .php: return "p.circle"
            }
        }
        var template: String {
            switch self {
            case .shell: return "#!/bin/bash\necho 'Hello World'"; case .python: return "print('Hello Python')"; case .swift: return "print(\"Hello Swift\")"; case .node: return "console.log('Hello Node')"; case .go: return "package main\nimport \"fmt\"\nfunc main() {\n    fmt.Println(\"Hello Go\")\n}"; case .rust: return "fn main() {\n    println!(\"Hello Rust\");\n}"; case .zig: return "const std = @import(\"std\");\n\npub fn main() !void {\n    const stdout = std.io.getStdOut().writer();\n    try stdout.print(\"Hello Zig\\n\", .{});\n}"; case .php: return "<?php\necho \"Hello PHP\";\n?"
            }
        }
        var keywords: [String] {
            switch self {
            case .shell: return ["echo", "if", "else", "fi", "then", "for", "while", "do", "done", "case", "esac", "function", "return", "exit", "local", "alias", "export"]
            case .python: return ["def", "class", "if", "elif", "else", "while", "for", "in", "try", "except", "import", "from", "return", "print", "True", "False", "None", "lambda", "with", "as", "yield", "async", "await", "len", "range", "self"]
            case .swift: return ["func", "var", "let", "if", "else", "guard", "return", "class", "struct", "enum", "extension", "import", "print", "true", "false", "nil", "try", "throws", "catch", "init", "deinit", "self", "Self", "Any", "typealias", "associatedtype", "async", "await"]
            case .node: return ["const", "let", "var", "function", "if", "else", "return", "import", "require", "console.log", "true", "false", "null", "undefined", "async", "await", "module.exports", "process", "exports", "Promise", "JSON.parse", "JSON.stringify"]
            case .go: return ["func", "package", "import", "var", "const", "type", "struct", "interface", "if", "else", "return", "for", "range", "go", "chan", "true", "false", "nil", "make", "len", "cap", "new", "append", "copy", "close", "delete", "panic", "recover", "fmt.Println", "fmt.Printf"]
            case .rust: return ["fn", "let", "mut", "if", "else", "match", "return", "struct", "enum", "impl", "use", "mod", "pub", "crate", "true", "false", "unsafe", "where", "while", "loop", "trait", "println!", "vec!", "format!", "dbg!", "Option", "Result", "Self", "self"]
            case .zig: return ["const", "var", "fn", "pub", "return", "if", "else", "switch", "while", "for", "try", "catch", "struct", "enum", "union", "error", "true", "false", "null", "undefined", "void", "@import", "std.debug.print", "comptime", "defer", "errdefer", "usingnamespace", "extern", "@intCast", "@ptrCast"]
            case .php: return ["function", "echo", "if", "else", "elseif", "while", "for", "foreach", "return", "class", "public", "private", "protected", "new", "null", "true", "false", "array_merge", "count", "isset", "unset", "var_dump", "print_r", "namespace", "use", "trait", "match", "fn", "readonly"]
            }
        }
    }
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active, cornerRadius: 20)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(LinearGradient(gradient: Gradient(colors: [.white.opacity(0.4), .white.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                )
                .shadow(color: .black.opacity(0.2), radius: 25, x: 0, y: 15)
            
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Circle().fill(Color.red.opacity(0.7)).frame(width: 11, height: 11).onTapGesture { controller.close() }
                        Circle().fill(Color.orange.opacity(0.7)).frame(width: 11, height: 11)
                        Circle().fill(Color.green.opacity(0.7)).frame(width: 11, height: 11)
                    }
                    Text("Coder").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                    Menu {
                        ForEach(Language.allCases) { lang in
                            Button(action: { language = lang; if code.isEmpty || Language.allCases.map({$0.template}).contains(code) { code = lang.template } }) { Label(lang.rawValue, systemImage: lang.icon) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: language.icon).font(.system(size: 10))
                            Text(language.rawValue).font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 8))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(Color.white.opacity(0.1))).overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }.menuStyle(BorderlessButtonMenuStyle())
                    Button(action: runCode) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isRunning ? Color.gray.opacity(0.3) : Color.blue.opacity(0.8)).shadow(color: isRunning ? .clear : .blue.opacity(0.3), radius: 4, y: 2)
                            HStack(spacing: 6) { if isRunning { TinyLoadingView() } else { Image(systemName: "play.fill").font(.system(size: 9)) }; Text(isRunning ? "RUNNING" : "RUN").font(.system(size: 10, weight: .heavy)) }.foregroundColor(.white)
                        }.frame(width: 80, height: 28)
                    }.buttonStyle(PlainButtonStyle()).disabled(isRunning)
                }.padding(.horizontal, 20).padding(.vertical, 14).background(Color.black.opacity(0.03))
                
                CodeEditorView(text: $code, language: language).padding(12).background(Color.white.opacity(0.02))
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "terminal").font(.system(size: 10)); Text("CONSOLE").font(.system(size: 10, weight: .bold)); Spacer()
                        Button(action: { output = "Ready..." }) { Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.secondary) }.buttonStyle(PlainButtonStyle())
                    }.padding(.horizontal, 16).padding(.vertical, 8).foregroundColor(.secondary.opacity(0.6)).background(Color.black.opacity(0.1))
                    ScrollView {
                        Text(output).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    }.frame(height: 150).background(Color.black.opacity(0.2))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .background(ShortcutMonitorView { event in if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "r" { runCode(); return true }; return false })
    }
    
    func runCode() { if isRunning { return }; isRunning = true; output = "Compiling & Running..."; CodeRunner.run(language: language, code: code) { result in DispatchQueue.main.async { self.output = result; self.isRunning = false } } }
}

// MARK: - Components

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var language: CoderView.Language
    
    func makeNSView(context: Context) -> NSScrollView {
        let s = NSTextView.scrollableTextView(); s.drawsBackground = false; s.hasVerticalScroller = true
        let t = s.documentView as! NSTextView; t.drawsBackground = false; t.backgroundColor = .clear
        t.delegate = context.coordinator; t.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        t.textColor = .labelColor; t.isAutomaticQuoteSubstitutionEnabled = false; t.isAutomaticDashSubstitutionEnabled = false
        t.isAutomaticTextReplacementEnabled = false; t.isRichText = false; t.textContainerInset = NSSize(width: 8, height: 8)
        return s
    }
    
    func updateNSView(_ s: NSScrollView, context: Context) {
        let t = s.documentView as! NSTextView
        context.coordinator.parent = self
        if t.string != text { t.string = text; context.coordinator.highlightDebounced(textView: t) }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        private var debounceTimer: Timer?
        private var lastProcessedString: String = ""
        private var isDeleting: Bool = false
        
        init(_ p: CodeEditorView) { self.parent = p }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            isDeleting = (replacementString?.isEmpty ?? true)
            return true
        }
        
        func textDidChange(_ n: Notification) {
            guard let t = n.object as? NSTextView else { return }
            self.parent.text = t.string
            highlightDebounced(textView: t)
            if !isDeleting, let last = t.string.last, last.isLetter || last.isNumber || last == "." || last == "@" {
                DispatchQueue.main.async { t.complete(nil) }
            }
        }
        
        func highlightDebounced(textView: NSTextView) {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in self?.applyHighlight(textView: textView) }
        }
        
        private func applyHighlight(textView: NSTextView) {
            guard let storage = textView.textStorage, storage.string != lastProcessedString else { return }
            lastProcessedString = storage.string
            let s = storage.string; let r = NSRange(location: 0, length: s.utf16.count)
            storage.beginEditing()
            storage.removeAttribute(.foregroundColor, range: r)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: r)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: r)
            
            let escapedKeywords = parent.language.keywords.map { NSRegularExpression.escapedPattern(for: $0) }
            let keywordPattern = "\\b(" + escapedKeywords.joined(separator: "|") + ")\\b"
            
            let patterns: [(String, NSColor)] = [
                ("\"[^\"]*?\"", .systemOrange), ("\\/\\/.*", .systemGray), ("#.*", .systemGray),
                (keywordPattern, .systemPink), ("\\b\\d+\\b", .systemBlue), ("@[a-zA-Z]+", .systemCyan)
            ]
            for (p, c) in patterns {
                if let regex = try? NSRegularExpression(pattern: p, options: []) {
                    regex.enumerateMatches(in: s, range: r) { m, _, _ in if let mr = m?.range { storage.addAttribute(.foregroundColor, value: c, range: mr) } }
                }
            }
            if let funcRegex = try? NSRegularExpression(pattern: #"[a-zA-Z_][a-zA-Z0-9_]*(?=\(""#, options: []) {
                funcRegex.enumerateMatches(in: s, range: r) { m, _, _ in if let mr = m?.range { storage.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: mr) } }
            }
            storage.endEditing()
        }
        
        func textView (_ t: NSTextView, completions w: [String], forPartialWordRange r: NSRange, indexOfSelectedItem i: UnsafeMutablePointer<Int>?) -> [String] {
            guard let s = t.textStorage?.string as NSString? else { return w }
            let p = s.substring(with: r).lowercased()
            return parent.language.keywords.filter { $0.lowercased().hasPrefix(p) || $0.lowercased().contains("." + p) }.sorted()
        }
    }
}

struct TinyLoadingView: View {
    @State private var rotate = false
    var body: some View {
        Circle().trim(from: 0, to: 0.7).stroke(Color.white, lineWidth: 1.5).frame(width: 10, height: 10)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .onAppear { withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { rotate = true } }
    }
}

struct ShortcutMonitorView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool
    func makeNSView(context: Context) -> NSView { ShortcutNSView(onKeyDown: onKeyDown) }
    func updateNSView(_ ns: NSView, context: Context) {}
    class ShortcutNSView: NSView {
        var onKeyDown: (NSEvent) -> Bool
        init(onKeyDown: @escaping (NSEvent) -> Bool) { self.onKeyDown = onKeyDown; super.init(frame: .zero)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in if self?.window == e.window, self?.onKeyDown(e) ?? false { return nil }; return e }
        }
        required init?(coder: NSCoder) { fatalError() }
    }
}

class CodeRunner {
    static func run(language: CoderView.Language, code: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = FileManager.default.temporaryDirectory; let uuid = UUID().uuidString
            let sourceFile: URL; let interpreter: String; var args: [String] = []
            switch language {
            case .shell: sourceFile = tempDir.appendingPathComponent("\(uuid).sh"); interpreter = "/bin/zsh"
            case .python: sourceFile = tempDir.appendingPathComponent("\(uuid).py"); interpreter = "/usr/bin/python3"
            case .swift: sourceFile = tempDir.appendingPathComponent("\(uuid).swift"); interpreter = "/usr/bin/swift"
            case .node: sourceFile = tempDir.appendingPathComponent("\(uuid).js"); interpreter = findExec("node")
            case .php: sourceFile = tempDir.appendingPathComponent("\(uuid).php"); interpreter = findExec("php")
            case .go: sourceFile = tempDir.appendingPathComponent("\(uuid).go"); interpreter = findExec("go"); args = ["run"]
            case .zig: sourceFile = tempDir.appendingPathComponent("\(uuid).zig"); interpreter = findExec("zig"); args = ["run"]
            case .rust: sourceFile = tempDir.appendingPathComponent("\(uuid).rs"); interpreter = findExec("rustc")
            }
            do {
                try code.write(to: sourceFile, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sourceFile.path)
                if language == .rust {
                    let binary = tempDir.appendingPathComponent(uuid)
                    let res = runCommand(interpreter, args: [sourceFile.path, "-o", binary.path])
                    if !res.1.isEmpty { completion("Compilation Error:\n" + res.1); return }
                    let run = runCommand(binary.path, args: []); completion(run.0 + (run.1.isEmpty ? "" : "\nStderr:\n" + run.1))
                    try? FileManager.default.removeItem(at: binary); return
                }
                let res = runCommand(interpreter, args: args + [sourceFile.path])
                var out = res.0; if !res.1.isEmpty { out += "\n[Stderr]:\n" + res.1 }
                try? FileManager.default.removeItem(at: sourceFile)
                completion(out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(No Output)" : out)
            } catch { completion("Execution Error: \(error.localizedDescription)") }
        }
    }
    static func findExec(_ name: String) -> String {
        for p in ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/", "/bin/"] { let full = p + name; if FileManager.default.fileExists(atPath: full) { return full } }
        return name
    }
    static func runCommand(_ cmd: String, args: [String]) -> (String, String) {
        let task = Process(); let outPipe = Pipe(); let errPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: cmd); task.arguments = args
        task.standardOutput = outPipe; task.standardError = errPipe
        var env = ProcessInfo.processInfo.environment; env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        if env["HOME"] == nil { env["HOME"] = NSHomeDirectory() }
        task.environment = env
        do { try task.run(); task.waitUntilExit()
            let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (out, err)
        } catch { return ("", "Failed: \(error.localizedDescription)") }
    }
}
