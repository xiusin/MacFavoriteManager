import SwiftUI
import Combine

struct BrewManagerView: View {
    @ObservedObject var viewModel: AppViewModel
    var onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedTab: Int = 0 // 0: My Services, 1: Library
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Neumorphic Segmented Control
                HStack(spacing: 0) {
                    SegmentButton(title: "我的服务", isSelected: selectedTab == 0) { selectedTab = 0 }
                    SegmentButton(title: "服务库", isSelected: selectedTab == 1) { selectedTab = 1 }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                        )
                )
                
                Spacer()
                
                // Refresh Button
                NeumorphicIconButton(icon: "arrow.clockwise", color: .blue) {
                    if selectedTab == 0 { viewModel.refreshBrewServices() }
                    else { if !viewModel.searchQuery.isEmpty { viewModel.searchBrew() } else { viewModel.refreshBrewServices() } }
                }
                .rotationEffect(.degrees(viewModel.isBrewLoading || viewModel.isSearching ? 360 : 0))
                .animation(viewModel.isBrewLoading || viewModel.isSearching ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isBrewLoading || viewModel.isSearching)
                .disabled(viewModel.isBrewLoading || viewModel.isSearching)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .modifier(GlassPaneModifier())
            
            // Content
            if selectedTab == 0 {
                MyServicesView(viewModel: viewModel)
            } else {
                ServiceStoreView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.refreshBrewServices()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    struct SegmentButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color(NSColor.windowBackgroundColor) : Color.clear)
                            .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0), radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - My Services Tab
struct MyServicesView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            if viewModel.isBrewLoading && viewModel.brewServices.isEmpty {
                ProgressView("加载中...")
                    .padding(.top, 50)
            } else if viewModel.brewServices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
                    Text("未发现已安装的服务").font(.body).foregroundColor(.secondary)
                }
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.brewServices) { service in
                        BrewServiceRow(service: service, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - Store Tab
struct ServiceStoreView: View {
    @ObservedObject var viewModel: AppViewModel
    
    // De-bounce search
    let searchPublisher = PassthroughSubject<String, Never>()
    
    var displayList: [String] {
        if viewModel.searchQuery.isEmpty {
            return viewModel.recommendedServices
        } else {
            return viewModel.searchResults
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索 Homebrew 服务 (如 mysql, nginx)...", text: $viewModel.searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .onChange(of: viewModel.searchQuery) { val in
                        if !val.isEmpty {
                            viewModel.searchBrew()
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = ""; viewModel.searchResults = [] }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(10)
            .background(NeumorphicInputBackground())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            // Results
            ScrollView {
                if viewModel.isSearching {
                    HStack {
                        ProgressView().scaleEffect(0.6)
                        Text("正在搜索...").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }
                
                LazyVStack(spacing: 8) {
                    if displayList.isEmpty && !viewModel.isSearching {
                        Text("没有找到结果").foregroundColor(.secondary).padding(.top, 30)
                    } else {
                        ForEach(displayList, id: \.self) { name in
                            StoreItemRow(name: name, viewModel: viewModel)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

struct StoreItemRow: View {
    let name: String
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var isInstalled: Bool {
        viewModel.installedFormulae.contains(name) || viewModel.brewServices.contains(where: { $0.name == name })
    }
    
    var icon: String {
        IconMatcher.suggest(for: name)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.6), radius: 1, x: -1, y: -1)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 1, y: 1)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(width: 36, height: 36)
            
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))
            
            Spacer()
            
            if isInstalled {
                Button(action: {
                    viewModel.uninstallBrewService(BrewService(name: name))
                }) {
                    Text("卸载")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .shadow(color: Color.white.opacity(0.5), radius: 1, x: -1, y: -1)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 1, y: 1)
                            }
                        )
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    viewModel.installBrewService(name)
                }) {
                    Text("安装")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 2)
                            }
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct BrewServiceRow: View {
    let service: BrewService
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var statusColor: Color {
        switch service.status {
        case "started": return .green
        case "stopped": return .secondary
        case "error": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Dot
            ZStack {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.white.opacity(0.5), radius: 1, x: -0.5, y: -0.5)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0.5, y: 0.5)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusColor.opacity(0.6), radius: 2, x: 0, y: 0)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                HStack(spacing: 4) {
                    Text(service.status.capitalized)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                    if let user = service.user {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(user)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                // Uninstall (danger)
                NeumorphicActionButton(icon: "trash", color: .red.opacity(0.8)) {
                    viewModel.uninstallBrewService(service)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}
