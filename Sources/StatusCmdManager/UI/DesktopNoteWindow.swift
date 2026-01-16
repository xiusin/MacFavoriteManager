import SwiftUI
import AppKit

// MARK: - Desktop Note Window

class DesktopNoteWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Controller

class DesktopNoteWindowController: NSObject, ObservableObject, NSWindowDelegate {
    var window: DesktopNoteWindow!
    @Published var note: NoteItem
    var viewModel: AppViewModel
    
    // Debounce timer for saving position
    private var saveTimer: Timer?
    
    init(note: NoteItem, viewModel: AppViewModel) {
        self.note = note
        self.viewModel = viewModel
        super.init()
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialX = note.x ?? Double(screenRect.midX - 150)
        let initialY = note.y ?? Double(screenRect.midY - 125)
        let initialW = note.width ?? 300
        let initialH = note.height ?? 250
        
        let initialRect = NSRect(x: initialX, y: initialY, width: initialW, height: initialH)
        
        window = DesktopNoteWindow(
            contentRect: initialRect,
            styleMask: [.borderless, .resizable], 
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        // Important: Setting this false allows the custom shape to define the shadow
        window.invalidateShadow()
        
        // We handle moving manually via background view hit testing if needed, 
        // but NSWindow.isMovableByWindowBackground = true is the easiest way for "click anywhere to drag".
        // However, if we want to type, we need to be careful. 
        // Actually, TextEditor usually captures mouse clicks.
        window.isMovableByWindowBackground = !note.isLocked
        window.delegate = self
        
        let contentView = DesktopNoteView(controller: self, viewModel: viewModel)
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }
    
    func updateNoteData(_ newNote: NoteItem) {
        DispatchQueue.main.async {
            self.note = newNote
            self.window.isMovableByWindowBackground = !newNote.isLocked
        }
    }
    
    // MARK: - Window Delegate
    
    func windowDidMove(_ notification: Notification) {
        updatePosition(save: false)
        scheduleSave()
    }
    
    func windowDidResize(_ notification: Notification) {
        updatePosition(save: false)
        scheduleSave()
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        updatePosition(save: true)
    }
    
    private func updatePosition(save: Bool) {
        guard let window = window else { return }
        var updated = self.note
        updated.x = Double(window.frame.origin.x)
        updated.y = Double(window.frame.origin.y)
        updated.width = Double(window.frame.size.width)
        updated.height = Double(window.frame.size.height)
        
        self.note = updated
        viewModel.updateNote(updated, saveImmediately: save)
    }
    
    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.saveNotes()
        }
    }
    
    func closeWindow() {
        saveTimer?.invalidate()
        window.close()
    }
}

// MARK: - View

struct DesktopNoteView: View {
    @ObservedObject var controller: DesktopNoteWindowController
    @ObservedObject var viewModel: AppViewModel
    
    @State private var isEditing: Bool = false
    @State private var content: String = ""
    @State private var isHovering: Bool = false
    @State private var showColorPicker: Bool = false
    
    var body: some View {
        ZStack {
            // MARK: - Liquid Glass Background
            GeometryReader { geo in
                ZStack {
                    // 1. Dynamic Blur Base
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    // 2. Tint Color Overlay (Liquid Layer)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    tintColor.opacity(0.15),
                                    tintColor.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // 3. Glass Highlights (Reflections)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // 4. Subtle Inner Glow
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        .padding(1)
                }
            }
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            
            // MARK: - Content Layer (Fills Screen)
            ZStack(alignment: .topLeading) {
                if isEditing {
                    // Fully Transparent Editor
                    MacTransparentTextView(text: $content, font: .systemFont(ofSize: 15, weight: .regular))
                        .padding(.top, 44) // Avoid Toolbar
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                } else {
                    // Markdown Preview
                    ScrollView(showsIndicators: false) {
                        Text(LocalizedStringKey(controller.note.content))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .lineSpacing(4)
                            .foregroundColor(.primary.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 44) // Avoid Toolbar
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Make entire area clickable to edit (Double tap)
                    .contentShape(Rectangle()) 
                    .onTapGesture(count: 2) {
                        if !controller.note.isLocked {
                            content = controller.note.content
                            withAnimation(.spring()) { isEditing = true }
                        }
                    }
                }
            }
            
            // MARK: - Floating Toolbar (Top Layer)
            VStack {
                if isHovering || isEditing || showColorPicker {
                    toolbarView
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                
                // Resize Handle (Bottom Right)
                if !controller.note.isLocked && isHovering {
                    HStack {
                        if isEditing {
                            Text("Markdown")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.leading, 16)
                                .padding(.bottom, 8)
                        }
                        Spacer()
                        ResizeHandle(controller: controller)
                            .padding(8)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onHover { isHovering = $0 }
        .onAppear { content = controller.note.content }
        .onChange(of: controller.note.content) { newVal in
            if !isEditing { content = newVal }
        }
    }
    
    // MARK: - Subviews
    
    var toolbarView: some View {
        HStack(spacing: 8) {
            // Drag Indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.3))
                .padding(.leading, 12)
            
            Spacer()
            
            HStack(spacing: 4) {
                // Lock
                LiquidToolButton(
                    icon: controller.note.isLocked ? "lock.fill" : "lock.open",
                    color: controller.note.isLocked ? .orange : .secondary,
                    isActive: controller.note.isLocked
                ) {
                    toggleLock()
                }
                
                // Color Picker
                ZStack {
                    LiquidToolButton(icon: "paintpalette.fill", color: tintColor, isActive: showColorPicker) {
                        withAnimation { showColorPicker.toggle() }
                    }
                    
                    if showColorPicker {
                        ColorPickerPopup(selectedColor: controller.note.color) { newColor in
                            updateColor(newColor)
                            withAnimation { showColorPicker = false }
                        }
                        .offset(x: -60, y: 35) // Adjust position to not fly off screen
                        .zIndex(10)
                    }
                }
                
                // Edit (Save/Done)
                LiquidToolButton(
                    icon: isEditing ? "checkmark" : "pencil",
                    color: isEditing ? .blue : .secondary,
                    isActive: isEditing
                ) {
                    if isEditing { saveContent() }
                    withAnimation(.spring()) { isEditing.toggle() }
                }
                
                // Dock
                LiquidToolButton(icon: "pip.exit", color: .secondary) {
                    dockNote()
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .background(VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow, state: .active)) // Frosted glass toolbar
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.trailing, 8)
        }
    }
    
    // MARK: - Helpers & Actions
    
    var tintColor: Color {
        getColor(controller.note.color)
    }
    
    func getColor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "gray": return .gray
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }
    
    func toggleLock() {
        var updated = controller.note
        updated.isLocked.toggle()
        controller.updateNoteData(updated) // UI
        viewModel.updateNote(updated)      // Data
    }
    
    func updateColor(_ color: String) {
        var updated = controller.note
        updated.color = color
        controller.updateNoteData(updated)
        viewModel.updateNote(updated)
    }
    
    func saveContent() {
        var updated = controller.note
        updated.content = content
        viewModel.updateNote(updated)
    }
    
    func dockNote() {
        var updated = controller.note
        updated.isDesktopWidget = false
        viewModel.updateNote(updated)
        controller.closeWindow()
    }
}

// MARK: - Components

// Robust Transparent TextView
struct MacTransparentTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false // Hidden scroller for clean look, or true if needed
        scrollView.autohidesScrollers = true
        
        let textView = scrollView.documentView as! NSTextView
        textView.drawsBackground = false
        textView.backgroundColor = .clear // Crucial
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = NSColor.labelColor
        textView.allowsUndo = true
        
        // Layout Config
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Remove default padding/inset issues
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
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
        var parent: MacTransparentTextView
        init(_ parent: MacTransparentTextView) { self.parent = parent }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}

struct LiquidToolButton: View {
    let icon: String
    var color: Color = .secondary
    var isActive: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive || isHovering ? color.opacity(0.15) : Color.clear)
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isActive || isHovering ? color : .secondary.opacity(0.8))
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovering = $0 }
    }
}

struct ColorPickerPopup: View {
    let selectedColor: String
    let onSelect: (String) -> Void
    let colors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "gray"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.self) { colorName in
                Circle()
                    .fill(mapColor(colorName))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedColor == colorName ? 2 : 0)
                            .shadow(radius: 1)
                    )
                    .onTapGesture {
                        onSelect(colorName)
                    }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                .shadow(radius: 5)
        )
    }
    
    func mapColor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .blue
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        
        // Fix for rounded corners on backing layer
        view.wantsLayer = true
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = true
        
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct ResizeHandle: View {
    let controller: DesktopNoteWindowController
    @State private var initialRect: NSRect? = nil
    
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10))
            .foregroundColor(.secondary.opacity(0.4))
            .frame(width: 16, height: 16)
            .background(Color.white.opacity(0.001))
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let window = controller.window else { return }
                        if initialRect == nil { initialRect = window.frame }
                        guard let startRect = initialRect else { return }
                        
                        let deltaW = value.translation.width
                        let deltaH = value.translation.height
                        
                        let newWidth = max(200, startRect.width + deltaW)
                        let newHeight = max(150, startRect.height + deltaH)
                        
                        // Maintain Top-Left origin (Cocoa coordinates conversion)
                        // Cocoa Y grows up. Drag down (+y in swiftui) increases height.
                        // To keep Top-Left visual anchor, Y origin must decrease by the amount height increased.
                        let newY = startRect.origin.y - (newHeight - startRect.height)
                        
                        let newRect = NSRect(x: startRect.origin.x, y: newY, width: newWidth, height: newHeight)
                        window.setFrame(newRect, display: true)
                    }
                    .onEnded { _ in
                        initialRect = nil
                    }
            )
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}