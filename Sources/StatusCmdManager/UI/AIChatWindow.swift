import SwiftUI
import AppKit

// MARK: - AI Chat Window Controller
class AIChatWindowController: ObservableObject {
    static let shared = AIChatWindowController()
    
    var window: NSWindow?
    @Published var isVisible: Bool = false
    
    // Dependencies
    var viewModel: AppViewModel?
    
    init() {
        createWindow()
    }
    
    private func createWindow() {
        // Increased width from 400 to 500
        let window = FloatingPanel(
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.window = window
    }
    
    func show(viewModel: AppViewModel) {
        self.viewModel = viewModel
        guard let window = window else { return }
        
        if window.contentView == nil || (window.contentView as? NSHostingView<AIChatRootView>) == nil {
            let rootView = AIChatRootView(controller: self).environmentObject(viewModel)
            window.contentView = NSHostingView(rootView: rootView)
        }
        
        // Ensure app is active
        NSApp.unhide(nil)
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        withAnimation {
            isVisible = true
        }
    }
    
    func hide() {
        withAnimation {
            isVisible = false
        }
        window?.orderOut(nil)
    }
    
    func toggle(viewModel: AppViewModel) {
        if window?.isVisible == true {
            hide()
        } else {
            show(viewModel: viewModel)
        }
    }
}

// MARK: - Root View
struct AIChatRootView: View {
    @ObservedObject var controller: AIChatWindowController
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Main Acrylic Layer
            AcrylicBackground()
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Menu {
                        ForEach(AIProvider.allCases) { provider in
                            Button(action: {
                                viewModel.chatSettings.selectedProvider = provider
                                viewModel.saveChatSettings()
                            }) {
                                HStack {
                                    if viewModel.chatSettings.selectedProvider == provider {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(provider.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.chatSettings.selectedProvider.rawValue)
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .foregroundColor(.primary.opacity(0.8))
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    Button(action: { withAnimation(.spring(response: 0.4)) { showSettings = true } }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { controller.hide() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.01)) // Minimal background
                
                Divider().opacity(0.08)
                
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.chatMessages) { msg in
                                ChatBubble(
                                    message: msg,
                                    isLast: viewModel.chatMessages.last?.id == msg.id,
                                    isSending: viewModel.isChatSending
                                )
                                .id(msg.id)
                            }
                            if viewModel.isChatSending && viewModel.chatMessages.last?.role == .user {
                                HStack {
                                    LoadingBubble()
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .id("loading")
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: viewModel.chatMessages) { _ in
                        if let last = viewModel.chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isChatSending) { isSending in
                        if isSending {
                            withAnimation {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider().opacity(0.08)
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("输入消息...", text: $viewModel.chatInput, onCommit: {
                        viewModel.sendChatMessage()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(GlassInputBackground())
                    .font(.system(size: 13))
                    
                    Button(action: { viewModel.sendChatMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(viewModel.chatInput.isEmpty ? .secondary.opacity(0.2) : .blue.opacity(0.8))
                            .background(Circle().fill(Color.white.opacity(0.1)).padding(2))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.chatInput.isEmpty || viewModel.isChatSending)
                }
                .padding(16)
            }
            
            // Settings Overlay
            if showSettings {
                ZStack {
                    Color.black.opacity(0.1).edgesIgnoringSafeArea(.all)
                        .onTapGesture { withAnimation { showSettings = false } }
                        .transition(.opacity)
                    
                    AIChatSettingsView(settings: $viewModel.chatSettings, isPresented: $showSettings, onSave: viewModel.saveChatSettings)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                .zIndex(2)
            }
        }
        .frame(width: 500, height: 650)
    }
}

// MARK: - Components

struct ChatBubble: View {
    let message: AIChatMessage
    var isLast: Bool = false
    var isSending: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer() }
            
            if !isUser {
                // Neumorphic AI Icon
                ZStack {
                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.8), radius: 1, x: -1, y: -1)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 2, y: 2)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.indigo.opacity(0.8))
                }
                .frame(width: 28, height: 28)
            }
            
            Text(message.content + (shouldShowCursor ? " ▋" : ""))
                .font(.system(size: 13, weight: .regular, design: .default))
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundColor(isUser ? .white : .primary.opacity(0.9))
                .background(
                    ConversationalBubbleShape(isUser: isUser)
                        .fill(
                            isUser ?
                            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(gradient: Gradient(colors: [Color(NSColor.controlBackgroundColor).opacity(0.6), Color(NSColor.controlBackgroundColor).opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                // Neumorphic Depth
                .shadow(
                    color: isUser ? Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                    radius: 3, x: 0, y: 2
                )
                .overlay(
                    ConversationalBubbleShape(isUser: isUser)
                        .stroke(
                            isUser ? Color.white.opacity(0.2) : Color.white.opacity(0.4),
                            lineWidth: 0.5
                        )
                )
                .textSelection(.enabled)
            
            if !isUser { Spacer() }
        }
        .padding(.vertical, 2)
    }
    
    var shouldShowCursor: Bool {
        !isUser && isLast && isSending
    }
}

struct LoadingBubble: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 4, height: 4).opacity(isAnimating ? 1 : 0.3)
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 4, height: 4).opacity(isAnimating ? 0.3 : 1)
            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 4, height: 4).opacity(isAnimating ? 1 : 0.3)
        }
        .padding(10)
        .background(
            ConversationalBubbleShape(isUser: false)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            ConversationalBubbleShape(isUser: false)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(Animation.linear(duration: 0.6).repeatForever()) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shapes
struct ConversationalBubbleShape: Shape {
    var isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailRadius: CGFloat = 4
        
        var path = Path()
        
        let tl: CGFloat = radius
        let tr: CGFloat = radius
        let br: CGFloat = isUser ? tailRadius : radius
        let bl: CGFloat = isUser ? radius : tailRadius
        
        // Start Top Left
        path.move(to: CGPoint(x: 0, y: tl))
        
        // Top Left
        path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        
        // Top Right
        path.addLine(to: CGPoint(x: rect.width - tr, y: 0))
        path.addArc(center: CGPoint(x: rect.width - tr, y: tr), radius: tr, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        
        // Bottom Right
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - br))
        path.addArc(center: CGPoint(x: rect.width - br, y: rect.height - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        
        // Bottom Left
        path.addLine(to: CGPoint(x: bl, y: rect.height))
        path.addArc(center: CGPoint(x: bl, y: rect.height - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        path.closeSubpath()
        return path
    }
}

struct GlassInputBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

struct AIChatSettingsView: View {
    @Binding var settings: AIChatSettings
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @State private var currentTab: AIProvider
    @Environment(\.colorScheme) var colorScheme
    
    init(settings: Binding<AIChatSettings>, isPresented: Binding<Bool>, onSave: @escaping () -> Void) {
        self._settings = settings
        self._isPresented = isPresented
        self.onSave = onSave
        self._currentTab = State(initialValue: settings.wrappedValue.selectedProvider)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("模型配置")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary.opacity(0.9))
                    Text("个性化您的 AI 助手")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                Spacer()
                Button(action: { withAnimation { isPresented = false } }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Tab Selection (Neumorphic Tabs)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIProvider.allCases) { provider in
                        Button(action: { withAnimation(.spring(response: 0.3)) { currentTab = provider } }) {
                            Text(provider.rawValue)
                                .font(.system(size: 10, weight: currentTab == provider ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    ZStack {
                                        if currentTab == provider {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2))
                                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 1, y: 1)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.clear)
                                        }
                                    }
                                )
                                .foregroundColor(currentTab == provider ? .primary : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            
            Divider().opacity(0.05).padding(.horizontal, 20)
            
            // Config Content
            ScrollView {
                VStack(spacing: 16) {
                    if currentTab == .custom {
                        compactTextField(
                            icon: "server.rack",
                            title: "Base URL",
                            text: Binding(
                                get: { settings.customBaseUrls[.custom] ?? "" },
                                set: { settings.customBaseUrls[.custom] = $0 }
                            ),
                            placeholder: "http://localhost:11434/v1"
                        )
                    }
                    
                    if currentTab != .custom {
                        compactTextField(
                            icon: "key.fill",
                            title: "API Key",
                            text: Binding(
                                get: { settings.apiKeys[currentTab] ?? "" },
                                set: { settings.apiKeys[currentTab] = $0 }
                            ),
                            placeholder: "sk-...",
                            isSecure: true
                        )
                    }
                    
                    compactTextField(
                        icon: "cube.fill",
                        title: "Model Name",
                        text: Binding(
                            get: { settings.selectedModels[currentTab] ?? currentTab.defaultModel },
                            set: { settings.selectedModels[currentTab] = $0 }
                        ),
                        placeholder: currentTab.defaultModel
                    )
                    
                    // Tip Box
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.4))
                        Text("密钥将加密存储在本地。建议使用 DeepSeek 或 OpenAI 以获得最佳体验。")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.5))
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
                    .padding(.top, 10)
                }
                .padding(24)
            }
            
            Spacer()
            
            // Footer
            HStack(spacing: 16) {
                Button(action: { withAnimation { isPresented = false } }) {
                    Text("取消")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    settings.selectedProvider = currentTab
                    onSave()
                    withAnimation { isPresented = false }
                }) {
                    Text("保存配置")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]), startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(8)
                        .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
        }
        .background(
            ZStack {
                AcrylicBackground()
                Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05)
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 25, x: 0, y: 15)
    }
    
    // Helper for compact inputs
    func compactTextField(icon: String, title: String, text: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 14)
                
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11, design: .monospaced))
                } else {
                    TextField(placeholder, text: text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            )
        }
    }
}