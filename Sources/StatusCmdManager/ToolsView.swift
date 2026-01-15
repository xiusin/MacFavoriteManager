import SwiftUI
import AppKit
import CryptoKit

struct LocalEventMonitor: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool // Return true to consume
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown)
    }
    
    class Coordinator {
        var onKeyDown: (NSEvent) -> Bool
        var monitor: Any?
        
        init(onKeyDown: @escaping (NSEvent) -> Bool) {
            self.onKeyDown = onKeyDown
            self.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if let handler = self?.onKeyDown, handler(event) {
                    return nil
                }
                return event
            }
        }
        
        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

// MARK: - Tools Main View
struct ToolsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var activeTool: ToolType? = nil
    
    // Grid Layout Definition: 4 columns
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            // Main Grid Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ToolType.allCases, id: \.self) { tool in
                            ToolGridItem(tool: tool) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    activeTool = tool
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .blur(radius: activeTool != nil ? 10 : 0)
            .disabled(activeTool != nil)
            
            // Detail Overlay
            if let tool = activeTool {
                Color.black.opacity(0.01)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation { activeTool = nil }
                    }
                
                ToolDetailContainer(tool: tool, onDismiss: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        activeTool = nil
                    }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
    }
}

// MARK: - Data Models
enum ToolType: String, CaseIterable, Identifiable {
    case timestamp = "时间戳"
    case json = "JSON"
    case clipboard = "剪贴板"
    case password = "密码"
    case md5 = "哈希"
    case encoder = "编解码"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .timestamp: return "clock.fill"
        case .json: return "curlybraces"
        case .clipboard: return "doc.on.clipboard"
        case .password: return "key.fill"
        case .md5: return "number.circle.fill"
        case .encoder: return "arrow.triangle.2.circlepath"
        }
    }
    
    var color: Color {
        switch self {
        case .timestamp: return .red
        case .json: return .orange
        case .clipboard: return .cyan
        case .password: return .green
        case .md5: return .purple
        case .encoder: return .blue
        }
    }
    
    // Tiny description for compact card
    var description: String {
        switch self {
        case .timestamp: return "Unix 时间转换"
        case .json: return "Tree 视图"
        case .clipboard: return "历史记录管理"
        case .password: return "随机生成"
        case .md5: return "MD5/SHA"
        case .encoder: return "Base64/URL"
        }
    }
}

// MARK: - UI Components
struct ToolGridItem: View {
    let tool: ToolType
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 8) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tool.color.opacity(0.1))
                        .shadow(color: tool.color.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 16))
                        .foregroundColor(tool.color.opacity(0.9))
                }
                .frame(width: 36, height: 36)
                
                VStack(alignment: .center, spacing: 2) {
                    Text(tool.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary.opacity(0.9))
                    Text(tool.description)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.black.opacity(isHovering ? 0.1 : 0.05), radius: isHovering ? 6 : 2, x: 0, y: isHovering ? 3 : 1)
            )
            .scaleEffect(isHovering ? 1.03 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovering = $0 }
    }
}

struct ToolDetailContainer: View {
    let tool: ToolType
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text(tool.rawValue)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.primary.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Image(systemName: tool.icon)
                    .foregroundColor(tool.color.opacity(0.8))
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(Divider().opacity(0.1), alignment: .bottom)
            
            // Tool Content
            ScrollView {
                VStack(spacing: 16) {
                    switch tool {
                    case .timestamp: TimestampToolView()
                    case .json: JsonTreeViewWrapper()
                    case .clipboard: ClipboardHistoryToolView()
                    case .password: PasswordGeneratorView()
                    case .md5: HashCalculatorView()
                    case .encoder: EncoderDecoderView()
                    }
                }
                .padding(20)
            }
        }
        .background(AcrylicBackground())
        .cornerRadius(0) 
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Specific Tools

// 0. Timestamp Tool
struct TimestampToolView: View {
    @State private var now: Date = Date()
    @State private var inputTs: String = ""
    @State private var result: String = "等待输入..."
    @State private var isFlipped = false
    @State private var rotation: Double = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 24) {
            // Current Time
            VStack(spacing: 8) {
                Text("当前 Unix 时间戳 (秒)")
                    .font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("\(Int(now.timeIntervalSince1970))")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.9))
                    Button(action: { copyToClip("\(Int(now.timeIntervalSince1970))") }) {
                        Image(systemName: "doc.on.doc").foregroundColor(.secondary)
                    }.buttonStyle(PlainButtonStyle())
                }
                Text(formatDate(now))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(LiquidInputBackground())
            .onReceive(timer) { _ in now = Date() }
            
            Divider().opacity(0.1)
            
            // Convert
            VStack(alignment: .center, spacing: 20) {
                HStack(alignment: .bottom, spacing: 12) {
                    LiquidTextField(icon: "clock.arrow.circlepath", title: "Unix 时间戳", text: $inputTs, placeholder: "167...")
                    
                    Button(action: convertTimestamp) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.blue.opacity(0.8)).shadow(color: Color.blue.opacity(0.3), radius: 3, y: 2))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 2)
                }
                
                // Flip Card Result
                ZStack {
                    // Front
                    ResultCard(title: "准备就绪", value: "点击转换查看结果", icon: "hourglass")
                        .opacity(isFlipped ? 0 : 1)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    
                    // Back
                    ResultCard(title: "转换结果", value: result, icon: "calendar")
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                }
                .frame(height: 100)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
            }
        }
    }
    
    func convertTimestamp() {
        if let ts = Double(inputTs) {
            result = formatDate(Date(timeIntervalSince1970: ts))
        } else {
            result = "无效的时间戳格式"
        }
        
        withAnimation {
            isFlipped = true
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
    
    struct ResultCard: View {
        let title: String
        let value: String
        let icon: String
        
        var body: some View {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon).foregroundColor(.secondary)
                    Text(title).font(.caption).bold().foregroundColor(.secondary)
                }
                
                HStack {
                    Text(value)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.primary)
                    if value != "等待输入..." && value != "点击转换查看结果" {
                         Button(action: { copyToClip(value) }) {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LiquidInputBackground())
        }
    }
}

// 1. JSON Tree View
struct JsonTreeViewWrapper: View {
    @State private var input = ""
    @State private var jsonObject: Any? = nil
    @State private var errorMsg = ""
    @State private var isAutoParsed = false
    
    var body: some View {
        ZStack {
            if let obj = jsonObject {
                // MARK: - Preview Mode
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "curlybraces").foregroundColor(.blue)
                        Text("结构视图").font(.system(size: 13, weight: .bold)).foregroundColor(.primary.opacity(0.9))
                        Spacer()
                        
                        // Actions in Preview
                        HStack(spacing: 12) {
                            Button(action: { 
                                // Open independent window with current data
                                JsonDetailWindowController.shared.show(jsonObject: obj)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "macwindow")
                                    Text("全屏")
                                }
                            }
                            .buttonStyle(LiquidPillButtonStyle())
                            
                            Button(action: { 
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    input = ""
                                    jsonObject = nil
                                    errorMsg = ""
                                }
                            }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(LiquidIconButtonStyle())
                        }
                    }
                    
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            JsonNodeView(key: "Root", value: obj, isRoot: true)
                        }
                        .padding(16)
                    }
                    .frame(height: 240)
                    .background(LiquidInputBackground())
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // MARK: - Input Mode
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text.fill").foregroundColor(.secondary)
                        Text("JSON 源数据").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                        Spacer()
                        if isAutoParsed {
                            Text("已自动读取剪贴板").font(.caption2).foregroundColor(.green).transition(.opacity)
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        LiquidInputBackground()
                        
                        if input.isEmpty {
                            Text("粘贴 JSON 内容...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                        
                        // Custom Editor without Scrollbars
                        JsonInputEditor(text: $input)
                            .padding(6)
                    }
                    .frame(height: 200)
                    
                    HStack {
                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: parseJson) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("格式化")
                            }
                        }
                        .buttonStyle(LiquidPillButtonStyle())
                        .disabled(input.isEmpty)
                        .opacity(input.isEmpty ? 0.5 : 1)
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: jsonObject != nil)
        .onAppear {
            checkClipboard()
        }
    }
    
    func checkClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            // Simple heuristic to avoid parsing random text
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
                if let data = trimmed.data(using: .utf8),
                   (try? JSONSerialization.jsonObject(with: data, options: [])) != nil {
                    self.input = trimmed
                    self.parseJson()
                    self.isAutoParsed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.isAutoParsed = false }
                }
            }
        }
    }
    
    func parseJson() {
        guard let data = input.data(using: .utf8) else { return }
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            errorMsg = ""
        } catch {
            errorMsg = "无效的 JSON 格式"
            withAnimation { jsonObject = nil }
        }
    }
    
    func openDetailWindow() {
        if let obj = jsonObject {
            JsonDetailWindowController.shared.show(jsonObject: obj)
        }
    }
}

// Custom Editor to hide scrollbars
struct JsonInputEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false // Hide Scrollbar
        scrollView.hasHorizontalScroller = false
        
        let textView = scrollView.documentView as! NSTextView
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.isRichText = false
        
        // Padding
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JsonInputEditor
        init(_ parent: JsonInputEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

struct JsonNodeView: View {
    let key: String
    let value: Any
    var isRoot: Bool = false
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Node Header
            HStack(spacing: 6) {
                if isContainer {
                    Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundColor(.secondary.opacity(0.8))
                            .frame(width: 14, height: 14)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer().frame(width: 14)
                }
                
                // Key
                if !isRoot {
                    Text(key)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.9))
                    Text(":")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                // Value
                if !isContainer {
                    Text("\(String(describing: value))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(valueColor)
                        .lineLimit(1)
                } else {
                    Text(typeDescription)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.1)))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.vertical, 2)
            
            // Children
            if isExpanded && isContainer {
                VStack(alignment: .leading, spacing: 2) {
                    if let dict = value as? [String: Any] {
                        ForEach(dict.keys.sorted(), id: \.self) { k in
                            JsonNodeView(key: k, value: dict[k]!)
                        }
                    } else if let array = value as? [Any] {
                        ForEach(0..<array.count, id: \.self) { i in
                            JsonNodeView(key: "[\(i)]", value: array[i])
                        }
                    }
                }
                .padding(.leading, 9) // Indentation
                .overlay(
                    // Hierarchy Line
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.05)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 1)
                        .padding(.top, 4)
                        .padding(.bottom, 4),
                    alignment: .leading
                )
                .padding(.leading, 5) // Spacing for line
            }
        }
    }
    
    var isContainer: Bool {
        value is [String: Any] || value is [Any]
    }
    
    var typeDescription: String {
        if let arr = value as? [Any] { return "Array [\(arr.count)]" }
        if let dict = value as? [String: Any] { return "Object {\(dict.count)}" }
        return ""
    }
    
    var valueColor: Color {
        if value is String { return .green.opacity(0.8) }
        if value is NSNumber { return .blue.opacity(0.8) } // Covers Int, Double, Bool
        return .primary.opacity(0.8)
    }
}

// MARK: - Reusable styles replaced by global definitions

// 2. Password Generator
struct PasswordGeneratorView: View {
    @State private var length: Double = 12
    @State private var useNumbers = true
    @State private var useSymbols = true
    @State private var useUppercase = true
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Result Display
            HStack {
                Text(password.isEmpty ? "点击生成" : password)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(password.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: { copyToClip(password) }) {
                    Image(systemName: "doc.on.doc")
                }.buttonStyle(LiquidIconButtonStyle())
            }
            .padding(16)
            .background(LiquidInputBackground())
            
            // Controls
            VStack(spacing: 20) {
                HStack {
                    Text("长度: \(Int(length))")
                    Slider(value: $length, in: 6...32, step: 1)
                }
                
                HStack(spacing: 20) {
                    Toggle("数字 (0-9)", isOn: $useNumbers)
                    Toggle("符号 (!@#)", isOn: $useSymbols)
                }
                HStack {
                    Toggle("大写 (A-Z)", isOn: $useUppercase)
                    Spacer()
                }
                
                Button(action: generatePassword) {
                    Text("生成密码")
                }.buttonStyle(LiquidPillButtonStyle())
            }
        }
        .onAppear(perform: generatePassword)
    }
    
    func generatePassword() {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let numbers = "0123456789"
        let symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        var chars = letters
        if useNumbers { chars += numbers }
        if useSymbols { chars += symbols }
        if useUppercase { chars += upper }
        
        password = String((0..<Int(length)).map { _ in chars.randomElement()! })
    }
}

// 3. Hash Calculator
struct HashCalculatorView: View {
    @State private var input = ""
    
    var md5: String {
        let digest = Insecure.MD5.hash(data: input.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    var sha256: String {
        let digest = SHA256.hash(data: input.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            LiquidTextField(icon: "text.quote", title: "输入文本", text: $input, placeholder: "Type something...")
            
            ResultRow(title: "MD5", value: input.isEmpty ? "" : md5)
            ResultRow(title: "SHA256", value: input.isEmpty ? "" : sha256)
        }
    }
    
    struct ResultRow: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).bold().foregroundColor(.secondary)
                HStack {
                    Text(value.isEmpty ? "Waiting for input..." : value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(value.isEmpty ? .secondary.opacity(0.5) : .primary)
                        .lineLimit(1)
                    Spacer()
                    if !value.isEmpty {
                        Button(action: { copyToClip(value) }) {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(12)
                .background(LiquidInputBackground())
            }
        }
    }
}

// 4. Encoder / Decoder
struct EncoderDecoderView: View {
    @State private var mode = 0 // 0: Base64, 1: URL
    @State private var input = ""
    @State private var output = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("", selection: $mode) {
                Text("Base64").tag(0)
                Text("URL Encode").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            LiquidTextField(icon: "arrow.right", title: "输入", text: $input, placeholder: "Raw text")
            
            HStack(spacing: 20) {
                Button(action: encode) { Text("编码 (Encode)") }.buttonStyle(LiquidPillButtonStyle())
                Button(action: decode) { Text("解码 (Decode)") }.buttonStyle(LiquidPillButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("结果").font(.caption).bold().foregroundColor(.secondary)
                HStack {
                    Text(output.isEmpty ? "Result..." : output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(4)
                    Spacer()
                    if !output.isEmpty {
                        Button(action: { copyToClip(output) }) {
                            Image(systemName: "doc.on.doc")
                        }.buttonStyle(LiquidIconButtonStyle())
                    }
                }
                .padding(12)
                .background(LiquidInputBackground())
            }
        }
    }
    
    func encode() {
        if mode == 0 {
            output = input.data(using: .utf8)?.base64EncodedString() ?? ""
        } else {
            output = input.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        }
    }
    
    func decode() {
        if mode == 0 {
            if let data = Data(base64Encoded: input) {
                output = String(data: data, encoding: .utf8) ?? "Invalid Base64"
            } else { output = "Invalid Base64" }
        } else {
            output = input.removingPercentEncoding ?? "Invalid URL"
        }
    }
}

// Helper
func copyToClip(_ text: String) {
    let p = NSPasteboard.general
    p.clearContents()
    p.setString(text, forType: .string)
}

struct LiquidIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue.opacity(0.8))
            .padding(6)
            .background(configuration.isPressed ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
    }
}

// 5. Clipboard History Tool
struct ClipboardHistoryToolView: View {
    @ObservedObject var manager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @Environment(\.colorScheme) var colorScheme
    
    var filteredHistory: [ClipboardItem] {
        if searchText.isEmpty {
            return manager.history
        } else {
            return manager.history.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Bar & Actions
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("搜索历史记录...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11.5))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(LiquidInputBackground())
                
                Button(action: { manager.clearHistory() }) {
                    ZStack {
                        LiquidInputBackground()
                        
                        Image(systemName: "trash")
                            .foregroundColor(.orange.opacity(0.85))
                            .font(.system(size: 11))
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .help("清空历史记录")
            }
            .padding(.horizontal, 2)
            
            // List
            ScrollViewReader { proxy in
                ScrollView {
                    if filteredHistory.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.2))
                            Text("暂无记录")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                                ClipboardHistoryRow(item: item, isSelected: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture {
                                        selectedIndex = index
                                        manager.pasteToActiveApp(item)
                                    }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 12)
                    }
                }
                .onChange(of: selectedIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .onChange(of: searchText) { _ in selectedIndex = 0 }
            }
            
            // Footer Hint
            Text("快捷键: ⌥ (Option) + Space 唤出悬浮窗")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.bottom, 4)
        }
        .background(
            LocalEventMonitor { event in
                handleKey(event)
            }
        )
    }
    
    func handleKey(_ event: NSEvent) -> Bool {
        let maxIndex = filteredHistory.count - 1
        guard maxIndex >= 0 else { return false }
        
        switch event.keyCode {
        case 126: // Up Arrow
            if selectedIndex > 0 { selectedIndex -= 1; return true }
        case 125: // Down Arrow
            if selectedIndex < maxIndex { selectedIndex += 1; return true }
        case 36: // Enter
            let item = filteredHistory[selectedIndex]
            manager.pasteToActiveApp(item)
            return true
        default: return false
        }
        return false
    }
    
    struct ClipboardHistoryRow: View {
        let item: ClipboardItem
        let isSelected: Bool
        @State private var isHovering = false
        @State private var showCopied = false
        @Environment(\.colorScheme) var colorScheme
        
        // Helper to get app icon
        func getAppIcon(bundleId: String?) -> NSImage? {
            guard let bundleId = bundleId,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return nil
            }
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                // Source App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    
                    if let bundleId = item.bundleId, let icon = getAppIcon(bundleId: bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(3)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .frame(width: 28, height: 28)
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.text)
                        .font(.system(size: 11, design: .default))
                        .lineLimit(2)
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    Text(timeString(from: item.date))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                // Action
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue.opacity(0.6))
                } else if isHovering {
                    Button(action: {
                        copyToClip(item.text)
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopied = false }
                        }
                    }) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(showCopied ? .green : .secondary.opacity(0.6))
                            .padding(4)
                            .background(Circle().fill(Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.1))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
                }
            )
            .scaleEffect(isHovering ? 1.005 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovering)
            .onHover { isHovering = $0 }
        }
        
        func timeString(from date: Date) -> String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
    }
}

// MARK: - Reusable Liquid Components for Tools

struct LiquidInputBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

struct LiquidTextField: View {
    let icon: String
    let title: String
    @Binding var text: String
    var placeholder: String
    var isCode: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.6)).padding(.leading, 4)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(.secondary.opacity(0.5)).font(.system(size: 13)).frame(width: 18)
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(isCode ? .system(.caption, design: .monospaced) : .system(.body))
            }
            .padding(12)
            .background(LiquidInputBackground())
        }
    }
}