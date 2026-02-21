import SwiftUI

// MARK: - Jelly Card

struct JellyCard<Content: View>: View {
    let tint: Color?
    let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KidTheme.Radius.card)
                .fill(KidTheme.surface)
                .overlay(
                    // top highlight
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.card))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KidTheme.Radius.card)
                        .stroke(KidTheme.border, lineWidth: 1)
                )
                .shadow(color: KidTheme.shadow, radius: 18, x: 0, y: 12)

            if let tint {
                RoundedRectangle(cornerRadius: KidTheme.Radius.card)
                    .fill(tint.opacity(0.10))
                    .blendMode(.plusLighter)
            }

            content
                .padding(18)
        }
    }
}

// MARK: - Jelly Buttons

enum JellyButtonKind {
    case primary
    case secondary
}

struct JellyButtonStyle: ButtonStyle {
    let kind: JellyButtonKind

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        let fill: Color = {
            switch kind {
            case .primary:
                return isPressed ? KidTheme.primaryPressed : KidTheme.primary
            case .secondary:
                return isPressed ? KidTheme.surfaceStrong.opacity(0.92) : KidTheme.surfaceStrong
            }
        }()

        let stroke: Color = {
            switch kind {
            case .primary:
                return Color.white.opacity(0.18)
            case .secondary:
                return KidTheme.border
            }
        }()

        let text: Color = (kind == .primary) ? .white : KidTheme.textPrimary

        return configuration.label
            .font(.system(size: KidTheme.FontSize.body, weight: .semibold, design: .rounded))
            .foregroundColor(text)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: KidTheme.Radius.button)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: KidTheme.Radius.button)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

// MARK: - Top Bar (bilingual)

struct JellyTopBar: View {
    let titleEN: String
    let titleZH: String
    let onBack: (() -> Void)?
    let onSettings: (() -> Void)?

    var body: some View {
        ZStack {
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(KidTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(KidTheme.surface)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(KidTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 40)
                }

                Spacer()

                if let onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(KidTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(KidTheme.surface)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(KidTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 40)
                }
            }

            VStack(spacing: 2) {
                Text(titleEN.uppercased())
                    .font(.system(size: KidTheme.FontSize.title, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textPrimary)
                Text(titleZH)
                    .font(.system(size: KidTheme.FontSize.tiny, weight: .semibold, design: .rounded))
                    .foregroundColor(KidTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
    }
}
