import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }
            
            MemoryListView()
                .tabItem {
                    Label("Memory", systemImage: "brain.head.profile")
                }
            
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
        }
    }
}
