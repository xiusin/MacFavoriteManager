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
            AcrylicBackground()
                .cornerRadius(16)
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
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { controller.hide() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.02))
                
                Divider().opacity(0.1)
                
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.chatMessages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                            if viewModel.isChatSending {
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
                
                Divider().opacity(0.1)
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("输入消息...", text: $viewModel.chatInput, onCommit: {
                        viewModel.sendChatMessage()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(NeumorphicInputBackground())
                    .font(.body)
                    
                    Button(action: { viewModel.sendChatMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.chatInput.isEmpty ? .secondary.opacity(0.3) : .blue)
                            .background(Circle().fill(Color.white).padding(2))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.chatInput.isEmpty || viewModel.isChatSending)
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
            }
            
            // Settings Overlay
            if showSettings {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                    .onTapGesture { showSettings = false }
                    .cornerRadius(16)
                
                AIChatSettingsView(settings: $viewModel.chatSettings, isPresented: $showSettings, onSave: viewModel.saveChatSettings)
                    .frame(width: 280) // More compact
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .frame(width: 500, height: 650) // Updated frame size
    }
}

// MARK: - Components

struct ChatBubble: View {
    let message: AIChatMessage
    @Environment(\.colorScheme) var colorScheme
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer() }
            
            if !isUser {
                // AI Icon
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 12)).foregroundColor(.white))
            }
            
            Text(message.content)
                .font(.system(size: 13))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundColor(isUser ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            isUser ? Color.blue : Color(NSColor.controlBackgroundColor)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(isUser ? 0.2 : 0.1), lineWidth: 0.5)
                )
                .textSelection(.enabled) // Enable text selection
            
            if !isUser { Spacer() }
        }
    }
}

struct LoadingBubble: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.secondary).frame(width: 5, height: 5).opacity(isAnimating ? 1 : 0.3)
            Circle().fill(Color.secondary).frame(width: 5, height: 5).opacity(isAnimating ? 0.3 : 1)
            Circle().fill(Color.secondary).frame(width: 5, height: 5).opacity(isAnimating ? 1 : 0.3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .onAppear {
            withAnimation(Animation.linear(duration: 0.6).repeatForever()) {
                isAnimating = true
            }
        }
    }
}

struct AIChatSettingsView: View {
    @Binding var settings: AIChatSettings
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @State private var currentTab: AIProvider
    
    init(settings: Binding<AIChatSettings>, isPresented: Binding<Bool>, onSave: @escaping () -> Void) {
        self._settings = settings
        self._isPresented = isPresented
        self.onSave = onSave
        self._currentTab = State(initialValue: settings.wrappedValue.selectedProvider)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Header
            HStack {
                Text("模型配置")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            
            // Tab Selection (Compact)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIProvider.allCases) { provider in
                        Button(action: { withAnimation { currentTab = provider } }) {
                            Text(provider.rawValue)
                                .font(.system(size: 11, weight: currentTab == provider ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(currentTab == provider ? Color.blue.opacity(0.2) : Color.clear)
                                )
                                .foregroundColor(currentTab == provider ? .blue : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Divider().opacity(0.1)
            
            // Config Content
            VStack(spacing: 12) {
                if currentTab == .custom {
                    NeumorphicTextField(
                        icon: "server.rack",
                        title: "Base URL",
                        text: Binding(
                            get: { settings.customBaseUrls[.custom] ?? "" },
                            set: { settings.customBaseUrls[.custom] = $0 }
                        ),
                        placeholder: "http://localhost:11434/v1",
                        isCode: true
                    )
                }
                
                if currentTab != .custom {
                    NeumorphicTextField(
                        icon: "key.fill",
                        title: "API Key",
                        text: Binding(
                            get: { settings.apiKeys[currentTab] ?? "" },
                            set: { settings.apiKeys[currentTab] = $0 }
                        ),
                        placeholder: "sk-...",
                        isCode: true
                    )
                }
                
                NeumorphicTextField(
                    icon: "cube.fill",
                    title: "Model Name",
                    text: Binding(
                        get: { settings.selectedModels[currentTab] ?? currentTab.defaultModel },
                        set: { settings.selectedModels[currentTab] = $0 }
                    ),
                    placeholder: currentTab.defaultModel,
                    isCode: true
                )
            }
            .padding(16)
            
            // Footer
            HStack {
                Button(action: {
                    // Also switch the active provider to the one being edited
                    settings.selectedProvider = currentTab
                    onSave()
                    isPresented = false
                }) {
                    Text("保存并使用")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
        }
        .background(
            ZStack {
                AcrylicBackground()
                Color(NSColor.windowBackgroundColor).opacity(0.8)
            }
        )
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }
}