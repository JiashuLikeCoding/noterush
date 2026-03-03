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

// MARK: - Tint button style (used by multiple screens)

struct JellyPill: View {
    let text: LocalizedStringKey
    let tint: Color

    init(text: LocalizedStringKey, tint: Color = KidTheme.primary) {
        self.text = text
        self.tint = tint
    }

    init(text: String, tint: Color = KidTheme.primary) {
        self.text = LocalizedStringKey(text)
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundColor(KidTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
            .cornerRadius(12)
    }
}

struct JellyTintButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundColor(KidTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(tint.opacity(pressed ? 0.22 : 0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint.opacity(pressed ? 0.55 : 0.28), lineWidth: 1)
            )
            .cornerRadius(14)
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

// MARK: - Section header + chips (SelectionView)

struct JellySectionHeader: View {
    let titleEN: String
    let titleZH: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleEN)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textSecondary)
                Text(titleZH)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(KidTheme.textPrimary)
            }

            Spacer()
        }
    }
}

struct JellyLetterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundColor(isSelected ? KidTheme.textPrimary : KidTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? KidTheme.primary.opacity(0.18) : Color.black.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? KidTheme.primary.opacity(0.55) : KidTheme.border, lineWidth: 1)
            )
            .cornerRadius(14)
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
