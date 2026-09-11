import SwiftUI
import UIKit

enum AppTab: Int, CaseIterable {
    case capture, memory, chat, explore

    var icon: String {
        switch self {
        case .capture: return "mic.fill"
        case .memory: return "square.stack.3d.up.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .explore: return "square.grid.2x2.fill"
        }
    }
}

struct RootView: View {
    @State private var selected: AppTab = .capture

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                CaptureView(onOpenMemory: { selected = .memory }).opacity(selected == .capture ? 1 : 0)
                MemoryListView().opacity(selected == .memory ? 1 : 0)
                ChatView().opacity(selected == .chat ? 1 : 0)
                ExploreView().opacity(selected == .explore ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.2), value: selected)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selected: $selected)
                .padding(.horizontal, 28)
                .padding(.bottom, 10)
        }
        .background(AmbientBackground())
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
    }
}

struct FloatingTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Button {
                    selected = tab
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    ZStack {
                        if selected == tab {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 46, height: 46)
                                .shadow(color: Theme.accent.opacity(0.45), radius: 14, y: 4)
                        }
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(selected == tab ? .black : .white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 10)
        .background(Color(red: 0.10, green: 0.10, blue: 0.13).opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
    }
}
