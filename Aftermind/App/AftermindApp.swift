import SwiftUI
import SwiftData

@main
struct AftermindApp: App {
    @StateObject private var chatHistory = ChatHistoryService()

    init() {
        AppConfig.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [SessionModel.self, MemoryItemModel.self])
        .environmentObject(chatHistory)
    }
}
