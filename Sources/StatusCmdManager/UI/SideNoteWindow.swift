import SwiftUI
import AppKit

// MARK: - Custom Window Subclass
class SideNoteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Controller
class SideNoteWindowController: ObservableObject {
    static let shared = SideNoteWindowController()
    
    var window: NSWindow?
    var edgeMonitorTimer: Timer?
    var hideTimer: Timer?
    
    @Published var isVisible: Bool = false
    
    // Desktop Notes Management
    var desktopControllers: [UUID: DesktopNoteWindowController] = [:]
    
    let windowWidth: CGFloat = 320
    let appViewModel = AppViewModel()
    
    init() {
        createWindow()
        startEdgeMonitoring()
        // Restore desktop notes after a short delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restoreDesktopNotes()
        }
    }
    
    func restoreDesktopNotes() {
        for note in appViewModel.notes where note.isDesktopWidget {
            openDesktopNote(note)
        }
    }
    
    func toggleDesktopMode(for note: NoteItem) {
        if note.isDesktopWidget {
            // Currently open, so close it (dock it)
            var updated = note
            updated.isDesktopWidget = false
            appViewModel.updateNote(updated)
            closeDesktopNote(note.id)
        } else {
            // Open it
            var updated = note
            updated.isDesktopWidget = true
            appViewModel.updateNote(updated)
            openDesktopNote(updated)
        }
    }
    
    func toggle() {
        // Use window.isVisible as an additional source of truth
        if isVisible || (window?.isVisible ?? false) {
            hide()
        } else {
            if let screen = NSScreen.main {
                show(on: screen)
            }
        }
    }
    
    func openDesktopNote(_ note: NoteItem) {
        if desktopControllers[note.id] == nil {
            let controller = DesktopNoteWindowController(note: note, viewModel: appViewModel)
            desktopControllers[note.id] = controller
        }
    }
    
    func closeDesktopNote(_ noteId: UUID) {
        if let controller = desktopControllers[noteId] {
            controller.closeWindow()
            desktopControllers.removeValue(forKey: noteId)
        }
    }
    
    private func createWindow() {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height = screenRect.height - 200
        
        let window = SideNoteWindow(
            contentRect: NSRect(x: screenRect.width, y: (screenRect.height - height) / 2, width: windowWidth, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let contentView = SideNoteView(controller: self, viewModel: appViewModel)
        window.contentView = NSHostingView(rootView: contentView)
        
        self.window = window
    }
    
    func startEdgeMonitoring() {
        edgeMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
    }
    
    private func checkMousePosition() {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) else { return }
        
        let screenMaxX = screen.frame.maxX
        
        if mouseLoc.x >= screenMaxX - 2 {
            show(on: screen)
        } else {
            if isVisible {
                if let windowFrame = window?.frame {
                    let activeZone = windowFrame.insetBy(dx: -20, dy: -20)
                    if !activeZone.contains(mouseLoc) {
                        scheduleHide()
                    } else {
                        cancelHide()
                    }
                }
            }
        }
    }
    
    func show(on targetScreen: NSScreen) {
        guard !isVisible, let window = window else { return }
        
        cancelHide()
        isVisible = true
        
        let screenFrame = targetScreen.frame
        let height = window.frame.height
        let y = screenFrame.minY + (screenFrame.height - height) / 2
        
        window.setFrameOrigin(NSPoint(x: screenFrame.maxX, y: y))
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(NSRect(x: screenFrame.maxX - windowWidth, y: y, width: windowWidth, height: height), display: true)
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        guard isVisible, let window = window else { return }
        
        isVisible = false
        guard let screen = window.screen else { 
            window.orderOut(nil)
            return 
        }
        
        let screenMaxX = screen.frame.maxX
        let height = window.frame.height
        let y = window.frame.origin.y
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(NSRect(x: screenMaxX, y: y, width: windowWidth, height: height), display: true)
        }) {
            // window.orderOut(nil)
        }
    }
    
    private func scheduleHide() {
        if hideTimer == nil {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.hide()
                self?.hideTimer = nil
            }
        }
    }
    
    private func cancelHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
}

// MARK: - View
struct SideNoteView: View {
    @ObservedObject var controller: SideNoteWindowController
    @ObservedObject var viewModel: AppViewModel
    @State private var isAddingNote = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background - Liquid Glass Style
            AcrylicBackground(radius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: -5, y: 5)
            
            if isAddingNote {
                NoteEditorView(
                    onCancel: { withAnimation(.spring()) { isAddingNote = false } },
                    onSave: { content in
                        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            withAnimation(.spring()) {
                                viewModel.addNote(content: trimmed)
                                isAddingNote = false
                            }
                        }
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1) // Ensure it sits on top
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("速记")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary.opacity(0.9))
                        Spacer()
                        
                        // Add Desktop Note Button
                        Button(action: {
                            // 1. Prepare Data
                            let newNote = NoteItem(content: "双击编辑内容...", isDesktopWidget: true)
                            
                            // 2. Update Model (This triggers UI refresh)
                            withAnimation(.spring()) {
                                viewModel.addNote(content: newNote.content, color: newNote.color) // addNote inserts at 0
                            }
                            
                            // 3. Open Window (Defer slightly to let data settle)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Find the note we just added (it's at index 0 or by content/time)
                                // Since addNote generates a new ID internally inside ViewModel (look at ViewModel.addNote),
                                // we actually need to capture that ID or correct how we add it.
                                // Let's fix this by finding the most recent note.
                                if let newest = viewModel.notes.first {
                                    var updated = newest
                                    updated.isDesktopWidget = true // Force desktop mode
                                    // Update without animation to avoid double refresh issues
                                    viewModel.updateNote(updated)
                                    controller.openDesktopNote(updated)
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.1))
                                Image(systemName: "plus.rectangle.on.rectangle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange.opacity(0.9))
                            }
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("新建桌面便签")
                        
                        Spacer().frame(width: 8)

                        // Add List Note Button
                        Button(action: { withAnimation(.spring()) { isAddingNote = true } }) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue.opacity(0.9))
                            }
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("新建列表事项")
                        
                        Spacer().frame(width: 12)
                        
                        Button(action: { controller.hide() }) {
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.01))
                    
                    // List
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.notes) { note in
                                NoteRow(note: note, onToggle: {
                                    var updated = note
                                    updated.isCompleted.toggle()
                                    viewModel.updateNote(updated)
                                }, onDelete: {
                                    withAnimation {
                                        // 顺序修复：先关闭对应的桌面窗口，再从数据源删除
                                        controller.closeDesktopNote(note.id)
                                        viewModel.deleteNote(id: note.id)
                                    }
                                }, onDetach: {
                                    DispatchQueue.main.async {
                                        controller.toggleDesktopMode(for: note)
                                    }
                                })
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}


struct NoteEditorView: View {
    var onCancel: () -> Void
    var onSave: (String) -> Void
    @State private var content: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor Header
            HStack {
                Button("取消", action: onCancel)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                Spacer()
                Text("新事项")
                    .font(.headline)
                    .foregroundColor(.primary.opacity(0.9))
                Spacer()
                Button("保存") { onSave(content) }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .bold))
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            
            // Editor Area
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("在此输入内容，支持 Markdown 语法...")
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 16)
                        .padding(.leading, 20)
                        .allowsHitTesting(false)
                }
                
                // Use custom TransparentTextEditor for macOS 12 support
                TransparentTextEditor(text: $content)
                    .padding(12)
                    .background(Color.clear)
                    .frame(maxHeight: .infinity)
            }
            
            // Markdown Hint Footer
            HStack {
                Image(systemName: "text.badge.checkmark")
                Text("Markdown Enabled")
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.5))
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
        }
        .background(AcrylicBackground(radius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

// Custom Transparent Text Editor for macOS 12
struct TransparentTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false // Transparent ScrollView
        scrollView.hasVerticalScroller = false // Hide scrollbar per request
        
        let textView = scrollView.documentView as! NSTextView
        textView.drawsBackground = false // Transparent TextView
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        
        // Ensure textView resizes with scrollView (Wrap text)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        
        // Inset to match SwiftUI padding look
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TransparentTextEditor

        init(_ parent: TransparentTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

struct NoteRow: View {
    let note: NoteItem
    var onToggle: () -> Void
    var onDelete: () -> Void
    var onDetach: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(note.isCompleted ? .green : .secondary.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 2)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(note.content))
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(note.isCompleted)
                    .foregroundColor(note.isCompleted ? .secondary : .primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                
                Text(formatDate(note.createdAt))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            Spacer(minLength: 0)
            
            // Actions (Hover only)
            if isHovering {
                HStack(spacing: 8) {
                    // Detach / Dock
                    Button(action: onDetach) {
                        Image(systemName: note.isDesktopWidget ? "pip.exit" : "pip.enter")
                            .font(.system(size: 12))
                            .foregroundColor(.blue.opacity(0.7))
                            .help(note.isDesktopWidget ? "收回" : "桌面贴纸")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Delete
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.clear]), startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
        )
        .onHover { isHovering = $0 }
    }
    
    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}