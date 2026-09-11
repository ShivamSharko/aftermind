import SwiftUI
import SwiftData

@main
struct AftermindApp: App {
    @State private var chatHistory = ChatHistoryService()

    init() {
        AppConfig.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [SessionModel.self, MemoryItemModel.self])
        .environment(chatHistory)
    }
}
