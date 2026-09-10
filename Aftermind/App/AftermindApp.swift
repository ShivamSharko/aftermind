import SwiftUI
import SwiftData

@main
struct AftermindApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [SessionModel.self, MemoryItemModel.self])
    }
}
