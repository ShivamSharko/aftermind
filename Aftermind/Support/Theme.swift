import SwiftUI

enum Theme {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let card = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let cardSecondary = Color(red: 0.17, green: 0.17, blue: 0.21)
    static let accent = Color(red: 0.82, green: 0.96, blue: 0.28)
    static let purpleLight = Color(red: 0.80, green: 0.68, blue: 0.96)
    static let purpleDeep = Color(red: 0.45, green: 0.30, blue: 0.68)
    static let textSecondary = Color.white.opacity(0.60)

    static func color(for type: String) -> Color {
        switch type {
        case "commitment": return accent
        case "task": return Color(red: 1.00, green: 0.65, blue: 0.30)
        case "decision": return purpleLight
        case "fact": return Color(red: 0.40, green: 0.75, blue: 1.00)
        case "idea": return Color(red: 1.00, green: 0.45, blue: 0.65)
        case "preference": return Color(red: 0.40, green: 0.90, blue: 0.80)
        default: return Color.white.opacity(0.70)
        }
    }
}

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Circle()
                .fill(Color(red: 0.85, green: 0.25, blue: 0.55).opacity(0.32))
                .frame(width: 340, height: 340)
                .blur(radius: 110)
                .offset(x: 70, y: -300)
            Circle()
                .fill(Color(red: 0.45, green: 0.25, blue: 0.75).opacity(0.28))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -110, y: 60)
            Circle()
                .fill(Color(red: 0.95, green: 0.55, blue: 0.25).opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 120, y: 380)
        }
        .ignoresSafeArea()
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct PillChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(isSelected ? Theme.accent : Theme.cardSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct CircleIconButton: View {
    let systemName: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.10))
                .clipShape(Circle())
        }
        .buttonStyle(PressableStyle())
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

struct TypeBadge: View {
    let type: String
    var body: some View {
        Text(type.capitalized)
            .font(.caption2.weight(.bold))
            .foregroundColor(Theme.color(for: type))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.color(for: type).opacity(0.18))
            .clipShape(Capsule())
    }
}

