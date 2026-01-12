import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Clipboard History Card
                ToolCard(
                    title: "剪贴板记录",
                    description: "自动保存最近复制的文本历史，支持快速回填。",
                    icon: "doc.on.clipboard",
                    color: .blue
                ) {
                    // Placeholder for future action or toggle
                    NeumorphicToggle(isOn: .constant(true))
                }
                
                // Selection Translation Card
                ToolCard(
                    title: "划词翻译",
                    description: "选中任意文本，按下快捷键立即翻译。",
                    icon: "character.book.closed.fill",
                    color: .orange
                ) {
                    NeumorphicToggle(isOn: .constant(false))
                }
                
                // OCR Card (Example extra)
                ToolCard(
                    title: "截图 OCR",
                    description: "截图并识别图片中的文字。",
                    icon: "text.viewfinder",
                    color: .purple
                ) {
                    NeumorphicToggle(isOn: .constant(false))
                }
            }
            .padding(20)
        }
    }
}

struct ToolCard<Content: View>: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.6), radius: 2, x: -1, y: -1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            .frame(width: 48, height: 48)
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary.opacity(0.9))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Custom Content (e.g. Toggle)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct NeumorphicToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .labelsHidden()
    }
}
