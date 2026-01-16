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
    
    private var saveTimer: Timer?
    
    init(note: NoteItem, viewModel: AppViewModel) {
        var initialNote = note
        if initialNote.cornerRadius == 0 { initialNote.cornerRadius = 15.0 }
        
        self.note = initialNote
        self.viewModel = viewModel
        super.init()
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialX = initialNote.x ?? Double(screenRect.midX - 150)
        let initialY = initialNote.y ?? Double(screenRect.midY - 125)
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
        window.invalidateShadow()
        
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
    
    func windowDidMove(_ notification: Notification) { updatePosition(save: false); scheduleSave() }
    func windowDidResize(_ notification: Notification) { updatePosition(save: false); scheduleSave() }
    func windowDidEndLiveResize(_ notification: Notification) { updatePosition(save: true) }
    
    func updateContent(_ newContent: String) {
        self.note.content = newContent
        viewModel.updateNote(self.note, saveImmediately: false)
        scheduleSave()
    }
    
    func updateStyle(blur: Double, opacity: Double, corner: Double) {
        self.note.blurRadius = blur
        self.note.tintOpacity = opacity
        self.note.cornerRadius = corner
        viewModel.updateNote(self.note, saveImmediately: false)
        scheduleSave()
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
            self?.viewModel.saveNotes()
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
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active, cornerRadius: controller.note.cornerRadius)
                        .clipShape(RoundedRectangle(cornerRadius: controller.note.cornerRadius, style: .continuous))
                        .opacity(min(1.0, controller.note.blurRadius / 20.0))
                    
                    RoundedRectangle(cornerRadius: controller.note.cornerRadius, style: .continuous)
                        .fill(tintColor.opacity(controller.note.tintOpacity))
                    
                    RoundedRectangle(cornerRadius: controller.note.cornerRadius, style: .continuous)
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
                    
                    RoundedRectangle(cornerRadius: controller.note.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        .padding(1)
                }
            }
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            
            ZStack(alignment: .topLeading) {
                if isEditing {
                    MacTransparentTextView(text: $content, font: .systemFont(ofSize: 15, weight: .regular))
                        .padding(.top, 44)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .onChange(of: content) { newVal in controller.updateContent(newVal) }
                } else {
                    MacMarkdownPreview(content: controller.note.content)
                        .padding(.top, 44)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if !controller.note.isLocked {
                                content = controller.note.content
                                withAnimation(.spring()) { isEditing = true }
                            }
                        }
                }
            }
            
            VStack {
                if isHovering || isEditing || showColorPicker || showSettings {
                    toolbarView
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                
                if !controller.note.isLocked && isHovering {
                    HStack {
                        if isEditing {
                            Text("Markdown Enabled")
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
        .onChange(of: controller.note.content) { newVal in if !isEditing && content != newVal { content = newVal } }
        .onTapGesture {
            if showSettings { withAnimation { showSettings = false } }
            if showColorPicker { withAnimation { showColorPicker = false } }
        }
    }
    
    var toolbarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.3))
                .padding(.leading, 12)
            
            Spacer()
            
            HStack(spacing: 4) {
                LiquidToolButton(icon: controller.note.isLocked ? "lock.fill" : "lock.open", color: controller.note.isLocked ? .orange : .secondary, isActive: controller.note.isLocked) {
                    toggleLock()
                }
                
                LiquidToolButton(icon: "slider.horizontal.3", color: .primary, isActive: showSettings) {
                    withAnimation { showSettings.toggle(); showColorPicker = false }
                }
                .overlay(
                    Group {
                        if showSettings {
                            VisualSettingsPopup(
                                blur: Binding(get: { controller.note.blurRadius }, set: { controller.updateStyle(blur: $0, opacity: controller.note.tintOpacity, corner: controller.note.cornerRadius) }),
                                opacity: Binding(get: { controller.note.tintOpacity }, set: { controller.updateStyle(blur: controller.note.blurRadius, opacity: $0, corner: controller.note.cornerRadius) }),
                                corner: Binding(get: { controller.note.cornerRadius }, set: { controller.updateStyle(blur: controller.note.blurRadius, opacity: controller.note.tintOpacity, corner: $0) })
                            )
                            .offset(y: 130)
                            .zIndex(100)
                        }
                    }, alignment: .center
                )
                
                LiquidToolButton(icon: "paintpalette.fill", color: tintColor, isActive: showColorPicker) {
                    withAnimation { showColorPicker.toggle(); showSettings = false }
                }
                .overlay(
                    Group {
                        if showColorPicker {
                            ColorPickerPopup(selectedColor: controller.note.color) { newColor in
                                updateColor(newColor)
                                withAnimation { showColorPicker = false }
                            }
                            .offset(y: 40)
                            .zIndex(100)
                        }
                    }, alignment: .center
                )
                
                LiquidToolButton(icon: isEditing ? "checkmark" : "pencil", color: isEditing ? .blue : .secondary, isActive: isEditing) {
                    if isEditing { saveContent() }
                    withAnimation(.spring()) { isEditing.toggle() }
                }
                
                LiquidToolButton(icon: "pip.exit", color: .secondary) { dockNote() }
            }
            .padding(4)
            .padding(.trailing, 8)
        }
    }
    
    var tintColor: Color { getColor(controller.note.color) }
    func getColor(_ name: String) -> Color {
        switch name {
        case "red": return .red; case "orange": return .orange; case "green": return .green; case "purple": return .purple; case "pink": return .pink; case "yellow": return .yellow; case "gray": return .gray; default: return .blue
        }
    }
    func toggleLock() {
        var updated = controller.note; updated.isLocked.toggle(); controller.updateNoteData(updated); viewModel.updateNote(updated)
    }
    func updateColor(_ color: String) {
        var updated = controller.note; updated.color = color; controller.updateNoteData(updated); viewModel.updateNote(updated)
    }
    func saveContent() {
        var updated = controller.note; updated.content = content; viewModel.updateNote(updated)
    }
    func dockNote() {
        var updated = controller.note; updated.isDesktopWidget = false; viewModel.updateNote(updated); controller.closeWindow()
    }
}

// MARK: - Refined Components

struct MacMarkdownPreview: NSViewRepresentable {
    let content: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let textView = scrollView.documentView as! NSTextView
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 0, height: 0)
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        let processed = content
            .replacingOccurrences(of: "- [ ]", with: "☐")
            .replacingOccurrences(of: "- [x]", with: "☑")
        
        // Use AttributedString for initial parse
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        guard var attrStr = try? AttributedString(markdown: processed, options: options) else {
            textView.string = processed
            return
        }
        
        // Final layout styling
        var nsAttrStr = NSMutableAttributedString(attrStr)
        let fullRange = NSRange(location: 0, length: nsAttrStr.length)
        
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.lineSpacing = 6
        defaultPara.paragraphSpacing = 12
        
        nsAttrStr.addAttribute(.foregroundColor, value: NSColor.labelColor.withAlphaComponent(0.9), range: fullRange)
        nsAttrStr.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .regular), range: fullRange)
        nsAttrStr.addAttribute(.paragraphStyle, value: defaultPara, range: fullRange)
        
        // Manual styling based on existing attributes
        let presentationIntentKey = NSAttributedString.Key("presentationIntent")
        let inlinePresentationIntentKey = NSAttributedString.Key("inlinePresentationIntent")
        
        nsAttrStr.enumerateAttribute(presentationIntentKey, in: fullRange, options: []) { value, range, _ in
            if let intent = value as? PIIntent {
                for component in intent.components {
                    switch component.kind {
                    case .header(let level):
                        let size: CGFloat = level == 1 ? 26 : (level == 2 ? 20 : 18)
                        nsAttrStr.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: range)
                    case .listItem:
                        let lPara = defaultPara.mutableCopy() as! NSMutableParagraphStyle
                        lPara.headIndent = 28
                        lPara.firstLineHeadIndent = 0
                        lPara.tabStops = [NSTextTab(textAlignment: .left, location: 28, options: [:])]
                        nsAttrStr.addAttribute(.paragraphStyle, value: lPara, range: range)
                    default: break
                    }
                }
            }
        }
        
        nsAttrStr.enumerateAttribute(inlinePresentationIntentKey, in: fullRange, options: []) { value, range, _ in
            if let intent = value as? InlinePresentationIntent, intent.contains(.code) {
                nsAttrStr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), range: range)
                nsAttrStr.addAttribute(.backgroundColor, value: NSColor.labelColor.withAlphaComponent(0.05), range: range)
            }
        }
        
        if textView.attributedString() != nsAttrStr {
            textView.textStorage?.setAttributedString(nsAttrStr)
        }
    }
}

// Internal Typealias for cleaner iteration
typealias PIIntent = PresentationIntent

struct VisualSettingsPopup: View {
    @Binding var blur: Double
    @Binding var opacity: Double
    @Binding var corner: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("视觉调整").font(.caption).bold().foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("模糊 (Blur)").font(.caption2).foregroundColor(.secondary)
                Slider(value: $blur, in: 0...40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("浓度 (Tint)").font(.caption2).foregroundColor(.secondary)
                Slider(value: $opacity, in: 0...1.0)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("圆角 (Corner)").font(.caption2).foregroundColor(.secondary)
                Slider(value: $corner, in: 0...40)
            }
        }
        .padding(12).frame(width: 180)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.5)).shadow(radius: 10))
    }
}

struct LiquidToolButton: View {
    let icon: String; var color: Color = .secondary; var isActive: Bool = false; let action: () -> Void
    @State private var isHovering = false
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(isActive || isHovering ? color.opacity(0.15) : Color.clear)
                Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(isActive || isHovering ? color : .secondary.opacity(0.8))
            }.frame(width: 24, height: 24).contentShape(Circle())
        }.buttonStyle(PlainButtonStyle()).onHover { isHovering = $0 }
    }
}

struct ColorPickerPopup: View {
    let selectedColor: String; let onSelect: (String) -> Void
    let colors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "gray"]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.self) { c in
                Circle().fill(mapColor(c)).frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == c ? 2 : 0).shadow(radius: 1))
                    .onTapGesture { onSelect(c) }
            }
        }.padding(8).background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.5)).shadow(radius: 5))
    }
    func mapColor(_ n: String) -> Color {
        switch n { case "red": return .red; case "orange": return .orange; case "green": return .green; case "purple": return .purple; case "pink": return .pink; case "yellow": return .yellow; case "gray": return .gray; default: return .blue }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material; var blendingMode: NSVisualEffectView.BlendingMode; var state: NSVisualEffectView.State; var cornerRadius: Double = 0
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = blendingMode; v.state = state; v.wantsLayer = true; v.layer?.cornerRadius = cornerRadius; v.layer?.masksToBounds = true; return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material; v.blendingMode = blendingMode; v.state = state; v.layer?.cornerRadius = cornerRadius }
}

struct MacTransparentTextView: NSViewRepresentable {
    @Binding var text: String; var font: NSFont
    func makeNSView(context: Context) -> NSScrollView {
        let s = NSTextView.scrollableTextView(); s.drawsBackground = false; s.hasVerticalScroller = false; s.autohidesScrollers = true
        let t = s.documentView as! NSTextView; t.drawsBackground = false; t.backgroundColor = .clear; t.delegate = context.coordinator; t.font = font; t.textColor = NSColor.labelColor; t.allowsUndo = true; t.isRichText = false; t.isHorizontallyResizable = false; t.isVerticallyResizable = true; t.textContainer?.widthTracksTextView = true; t.textContainer?.containerSize = NSSize(width: s.contentSize.width, height: CGFloat.greatestFiniteMagnitude); t.textContainerInset = NSSize(width: 0, height: 0); return s
    }
    func updateNSView(_ s: NSScrollView, context: Context) { let t = s.documentView as! NSTextView; if t.string != text { t.string = text } }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacTransparentTextView; init(_ p: MacTransparentTextView) { self.parent = p }
        func textDidChange(_ n: Notification) { guard let t = n.object as? NSTextView else { return }; self.parent.text = t.string }
    }
}

struct ResizeHandle: View {
    let controller: DesktopNoteWindowController; @State private var initialRect: NSRect? = nil
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 10)).foregroundColor(.secondary.opacity(0.4)).frame(width: 16, height: 16).background(Color.white.opacity(0.001)).cursor(.resizeLeftRight)
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                guard let w = controller.window else { return }; if initialRect == nil { initialRect = w.frame }
                guard let s = initialRect else { return }
                let nw = max(200, s.width + v.translation.width); let nh = max(150, s.height + v.translation.height); let ny = s.origin.y - (nh - s.height)
                w.setFrame(NSRect(x: s.origin.x, y: ny, width: nw, height: nh), display: true)
            }.onEnded { _ in initialRect = nil })
    }
}

extension View {
    func cursor(_ c: NSCursor) -> some View { self.onHover { if $0 { c.push() } else { NSCursor.pop() } } }
}