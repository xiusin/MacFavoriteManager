import SwiftUI
import AppKit

// MARK: - AI Chat Window Controller
class AIChatWindowController: ObservableObject {
    static let shared = AIChatWindowController()
    var window: NSWindow?
    @Published var isVisible: Bool = false
    var viewModel: AppViewModel?
    
    init() { createWindow() }
    
    private func createWindow() {
        let window = AIChatFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true 
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 380, height: 450)
        self.window = window
    }
    
    func show(viewModel: AppViewModel) {
        self.viewModel = viewModel
        guard let window = window else { return }
        if window.contentView == nil || (window.contentView as? NSHostingView<AIChatRootView>) == nil {
            let rootView = AIChatRootView(controller: self).environmentObject(viewModel)
            window.contentView = NSHostingView(rootView: rootView)
        }
        NSApp.unhide(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        withAnimation { isVisible = true }
    }
    
    func hide() {
        withAnimation { isVisible = false }
        window?.orderOut(nil)
    }
    
    func toggle(viewModel: AppViewModel) {
        if window?.isVisible == true { hide() } else { show(viewModel: viewModel) }
    }
}

// MARK: - Root View
struct AIChatRootView: View {
    @ObservedObject var controller: AIChatWindowController
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showSettings = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            AcrylicBackground(radius: 24)
                .background(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.02))
            
            VStack(spacing: 0) {
                headerArea
                    .contentShape(Rectangle())
                    .gesture(WindowDragGesture())
                
                Divider().opacity(0.08)
                
                chatContentArea
                
                Divider().opacity(0.08)
                
                inputArea
            }
            
            if showSettings {
                settingsOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    private var headerArea: some View {
        HStack {
            Menu {
                ForEach(AIProvider.allCases) { provider in
                    Button(action: {
                        viewModel.chatSettings.selectedProvider = provider
                        viewModel.saveChatSettings()
                    }) {
                        Label(provider.rawValue, systemImage: viewModel.chatSettings.selectedProvider == provider ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.chatSettings.selectedProvider.rawValue).font(.system(size: 13, weight: .bold))
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.05)))
                .foregroundColor(.primary.opacity(0.8))
            }.menuStyle(BorderlessButtonMenuStyle()).frame(width: 140, alignment: .leading)
            
            Spacer()
            
            LiquidIconButton(icon: "gearshape.fill", color: .secondary) { withAnimation(.spring()) { showSettings = true } }
            LiquidIconButton(icon: "xmark", color: .orange) { controller.hide() }.padding(.leading, 8)
        }.padding(.horizontal, 20).padding(.vertical, 14).background(Color.white.opacity(0.001))
    }
    
    private var chatContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                // 性能优化：改用普通 VStack 解决高度反馈不及时导致的间距 Creep 问题
                VStack(spacing: 16) {
                    ForEach(viewModel.chatMessages) { msg in
                        ChatBubble(message: msg, isLast: viewModel.chatMessages.last?.id == msg.id, isSending: viewModel.isChatSending)
                            .id(msg.id)
                    }
                    if viewModel.isChatSending && (viewModel.chatMessages.last?.content.isEmpty ?? true) {
                        HStack { ThinkingBubble(); Spacer() }.padding(.horizontal, 16).id("thinking")
                    }
                }.padding(16)
            }
            .onChange(of: viewModel.chatMessages) { _ in
                if let last = viewModel.chatMessages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $viewModel.chatInput, onCommit: {
                handleSendAction()
            })
            .textFieldStyle(PlainTextFieldStyle()).padding(10).background(GlassInputBackground()).font(.system(size: 13))
            
            Button(action: handleSendAction) {
                ZStack {
                    Circle().fill(viewModel.chatInput.isEmpty ? Color.secondary.opacity(0.1) : Color.blue.opacity(0.8))
                    Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }.frame(width: 28, height: 28)
            }.buttonStyle(PlainButtonStyle()).disabled(viewModel.chatInput.isEmpty || viewModel.isChatSending)
        }.padding(16)
    }
    
    private func handleSendAction() {
        guard !viewModel.chatInput.isEmpty && !viewModel.isChatSending else { return }
        viewModel.sendChatMessage()
        // 关键：延迟清空并强制同步 UI
        DispatchQueue.main.async {
            viewModel.chatInput = ""
        }
    }
    
    private var settingsOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation { showSettings = false } }
            AIChatSettingsView(settings: $viewModel.chatSettings, isPresented: $showSettings, onSave: viewModel.saveChatSettings)
                .padding(24).transition(.scale(scale: 0.9).combined(with: .opacity))
        }.zIndex(10)
    }
}

// MARK: - Components

struct ChatBubble: View {
    let message: AIChatMessage
    var isLast: Bool = false
    var isSending: Bool = false
    var isUser: Bool { message.role == .user }
    
    @State private var dynamicHeight: CGFloat = 40
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer() }
            if !isUser && message.role != .system {
                ZStack {
                    Circle().fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    Image(systemName: "sparkles").font(.system(size: 11)).foregroundColor(.indigo.opacity(0.8))
                }.frame(width: 28, height: 28)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    Text(message.content)
                        .font(.system(size: 13, design: .rounded))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(ConversationalBubbleShape(isUser: true).fill(Color.blue.opacity(0.9)))
                } else {
                    // AI 回复：使用修正后的自适应高度引擎
                    AIRichTextRenderer(content: message.content, isSending: isLast && isSending, dynamicHeight: $dynamicHeight)
                        .frame(height: dynamicHeight)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(ConversationalBubbleShape(isUser: false).fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
                        .overlay(ConversationalBubbleShape(isUser: false).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
            }
            .textSelection(.enabled)
            
            if !isUser { Spacer() }
        }
    }
}

struct AIRichTextRenderer: NSViewRepresentable {
    let content: String
    let isSending: Bool
    @Binding var dynamicHeight: CGFloat
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.layoutManager?.allowsNonContiguousLayout = false // 禁用非连续布局以获得精准高度
        return textView
    }
    
    func updateNSView(_ textView: NSTextView, context: Context) {
        let rawMarkdown = isSending ? content + "▋" : content
        let attributed = parseMarkdown(rawMarkdown)
        
        if textView.attributedString() != attributed {
            textView.textStorage?.setAttributedString(attributed)
            
            // 精准计算高度
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                // 强制容器宽度与当前视图一致
                textContainer.containerSize = NSSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
                layoutManager.ensureLayout(for: textContainer)
                let usedRect = layoutManager.usedRect(for: textContainer)
                
                // 仅当高度变化超过 1 像素时更新，防止震荡
                if abs(self.dynamicHeight - usedRect.height) > 1 {
                    DispatchQueue.main.async {
                        self.dynamicHeight = usedRect.height
                    }
                }
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        guard var attrStr = try? AttributedString(markdown: text, options: options) else {
            return NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        }
        
        let nsAttr = NSMutableAttributedString(attrStr)
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        nsAttr.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .regular), range: fullRange)
        nsAttr.addAttribute(.foregroundColor, value: NSColor.labelColor.withAlphaComponent(0.9), range: fullRange)
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        nsAttr.addAttribute(.paragraphStyle, value: paragraph, range: fullRange)
        
        // 代码块增强
        nsAttr.enumerateAttribute(NSAttributedString.Key("presentationIntent"), in: fullRange, options: []) { value, range, _ in
            if let intent = value as? PresentationIntent {
                for component in intent.components {
                    switch component.kind {
                    case .header(let level):
                        nsAttr.addAttribute(.font, value: NSFont.systemFont(ofSize: level == 1 ? 18 : 15, weight: .bold), range: range)
                    case .codeBlock:
                        nsAttr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: range)
                        nsAttr.addAttribute(.backgroundColor, value: NSColor.labelColor.withAlphaComponent(0.08), range: range)
                    default: break
                    }
                }
            }
        }
        
        // 细线光标
        let str = nsAttr.string as NSString
        let cursorRange = str.range(of: "▋")
        if cursorRange.location != NSNotFound {
            nsAttr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: cursorRange)
        }
        
        return nsAttr
    }
}

// MARK: - Reused Styles

struct ThinkingBubble: View {
    @State private var phase: Double = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle().fill(Color.blue.opacity(0.6)).frame(width: 5, height: 5)
                    .scaleEffect(1.0 + 0.3 * sin(phase + Double(i) * 0.5))
            }
        }.padding(.horizontal, 12).padding(.vertical, 8).background(Capsule().fill(Color.white.opacity(0.05)))
        .onAppear { withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = .pi * 2 } }
    }
}

struct GlassInputBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}

struct WindowDragGesture: Gesture {
    var body: some Gesture {
        DragGesture(minimumDistance: 0).onChanged { value in
            if let window = NSApp.keyWindow {
                var newOrigin = window.frame.origin; newOrigin.x += value.translation.width; newOrigin.y -= value.translation.height
                window.setFrameOrigin(newOrigin)
            }
        }
    }
}

struct ConversationalBubbleShape: Shape {
    var isUser: Bool
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18; let tailRadius: CGFloat = 4
        var path = Path()
        let tl: CGFloat = radius; let tr: CGFloat = radius; let br: CGFloat = isUser ? tailRadius : radius; let bl: CGFloat = isUser ? radius : tailRadius
        path.move(to: CGPoint(x: 0, y: tl))
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width - tr, y: 0))
        path.addArc(center: CGPoint(x: rect.width - tr, y: tr), radius: tr, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - br))
        path.addArc(center: CGPoint(x: rect.width - br, y: rect.height - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: bl, y: rect.height))
        path.addArc(center: CGPoint(x: bl, y: rect.height - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct AIChatSettingsView: View {
    @Binding var settings: AIChatSettings; @Binding var isPresented: Bool; var onSave: () -> Void
    @State private var currentTab: AIProvider
    init(settings: Binding<AIChatSettings>, isPresented: Binding<Bool>, onSave: @escaping () -> Void) {
        self._settings = settings; self._isPresented = isPresented; self.onSave = onSave; self._currentTab = State(initialValue: settings.wrappedValue.selectedProvider)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text("AI 配置").font(.system(size: 15, weight: .bold)); Text("管理模型与角色设定").font(.system(size: 10)).foregroundColor(.secondary) }
                Spacer(); Button(action: { withAnimation { isPresented = false } }) { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary) }.buttonStyle(PlainButtonStyle())
            }.padding(20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIProvider.allCases) { p in
                        Button(action: { withAnimation { currentTab = p } }) {
                            Text(p.rawValue).font(.system(size: 10, weight: currentTab == p ? .bold : .medium)).padding(.horizontal, 12).padding(.vertical, 6)
                                .background(currentTab == p ? Color.blue.opacity(0.1) : Color.clear).cornerRadius(8).foregroundColor(currentTab == p ? .blue : .primary)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }.padding(.horizontal, 20)
            }
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "person.text.rectangle").font(.system(size: 10)); Text("角色设定 (System Prompt)").font(.system(size: 10, weight: .bold)) }.foregroundColor(.secondary)
                        TextEditor(text: $settings.systemPrompt).font(.system(size: 12, design: .rounded)).padding(8).frame(height: 100).background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.05))).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                    if currentTab == .custom { compactField(icon: "server", title: "Base URL", text: Binding(get: { settings.customBaseUrls[.custom] ?? "" }, set: { settings.customBaseUrls[.custom] = $0 }), p: "https://api.example.com/v1") }
                    if currentTab != .custom { compactField(icon: "key", title: "API Key", text: Binding(get: { settings.apiKeys[currentTab] ?? "" }, set: { settings.apiKeys[currentTab] = $0 }), p: "sk-...", s: true) }
                    compactField(icon: "cube", title: "Model Name", text: Binding(get: { settings.selectedModels[currentTab] ?? currentTab.defaultModel }, set: { settings.selectedModels[currentTab] = $0 }), p: currentTab.defaultModel)
                }.padding(20)
            }
            HStack { Spacer(); Button(action: { settings.selectedProvider = currentTab; onSave(); withAnimation { isPresented = false } }) { Text("保存配置").font(.system(size: 12, weight: .bold)).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 10).background(Color.blue.opacity(0.8)).cornerRadius(10) }.buttonStyle(PlainButtonStyle()) }.padding(20)
        }.background(AcrylicBackground(radius: 20)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5)).shadow(color: .black.opacity(0.2), radius: 30)
    }
    func compactField(icon: String, title: String, text: Binding<String>, p: String, s: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.6))
            HStack {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(.secondary.opacity(0.5)).frame(width: 14)
                if s { SecureField(p, text: text).textFieldStyle(PlainTextFieldStyle()).font(.system(size: 11, design: .monospaced)) }
                else { TextField(p, text: text).textFieldStyle(PlainTextFieldStyle()).font(.system(size: 11, design: .monospaced)) }
            }.padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
        }
    }
}

class AIChatFloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView], backing: backing, defer: flag)
        self.isFloatingPanel = true; self.level = .floating; self.isMovableByWindowBackground = true; self.standardWindowButton(.closeButton)?.isHidden = true; self.standardWindowButton(.miniaturizeButton)?.isHidden = true; self.standardWindowButton(.zoomButton)?.isHidden = true
    }
    override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { true }
}