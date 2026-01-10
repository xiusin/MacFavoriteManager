import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var commands: [CommandItem] = []
    @Published var commandStates: [UUID: Bool] = [:]
    @Published var isLoading: [UUID: Bool] = [:]
    
    // UI 状态
    @Published var showErrorToast: Bool = false
    @Published var errorMessage: String = ""
    @Published var isEditingMode: Bool = false
    
    private let storageKey = "UserCommands_v1"
    
    init() {
        loadCommands()
    }
    
    // MARK: - Persistence
    func loadCommands() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CommandItem].self, from: data) {
            self.commands = decoded
        } else {
            // 默认初始数据
            self.commands = [
                CommandItem(
                    name: "MySQL",
                    description: "Homebrew Service",
                    iconName: "server.rack",
                    startCommand: "brew services start mysql",
                    stopCommand: "brew services stop mysql",
                    checkCommand: "pgrep mysqld"
                ),
                CommandItem(
                    name: "Redis",
                    description: "Homebrew Service",
                    iconName: "memorychip",
                    startCommand: "brew services start redis",
                    stopCommand: "brew services stop redis",
                    checkCommand: "pgrep redis-server"
                )
            ]
        }
        checkAllStatus()
    }
    
    func saveCommands() {
        if let encoded = try? JSONEncoder().encode(commands) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    // MARK: - Command Management
    func addCommand(_ item: CommandItem) {
        commands.append(item)
        saveCommands()
        checkStatus(for: item)
    }
    
    func deleteCommand(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
        saveCommands()
    }
    
    func updateCommand(_ item: CommandItem) {
        if let index = commands.firstIndex(where: { $0.id == item.id }) {
            commands[index] = item
            saveCommands()
            checkStatus(for: item)
        }
    }
    
    // MARK: - Execution
    func checkAllStatus() {
        for cmd in commands {
            checkStatus(for: cmd)
        }
    }
    
    func checkStatus(for command: CommandItem) {
        ShellRunner.runAsync(command.checkCommand) { result in
            self.commandStates[command.id] = (result.status == 0)
        }
    }
    
    func toggle(command: CommandItem) {
        let currentState = commandStates[command.id] ?? false
        let cmdStr = currentState ? command.stopCommand : command.startCommand
        
        isLoading[command.id] = true
        
        ShellRunner.runAsync(cmdStr) { result in
            if result.status != 0 {
                // 失败处理
                self.showError(title: "执行失败", message: result.error.isEmpty ? result.output : result.error)
                self.isLoading[command.id] = false
                // 恢复状态检查
                self.checkStatus(for: command)
            } else {
                // 成功后延迟检查
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ShellRunner.runAsync(command.checkCommand) { newResult in
                        self.commandStates[command.id] = (newResult.status == 0)
                        self.isLoading[command.id] = false
                        
                        // 双重检查：如果状态没变，可能是命令执行慢了或者无效
                        if self.commandStates[command.id] == currentState {
                            // 可选：提示用户状态未改变
                        }
                    }
                }
            }
        }
    }
    
    func showError(title: String, message: String) {
        self.errorMessage = "\(title): \(message)"
        self.showErrorToast = true
        
        // 3秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showErrorToast = false
        }
    }
}
