import SwiftUI
import UIKit

/// Compact elapsed-time pill. `Text(_:style: .timer)` updates itself every second.
struct TimerBadge: View {
    let start: Date

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(start, style: .timer)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elapsed time")
        .accessibilityValue(Text(start, style: .timer))
    }
}

/// A short message at the top of the screen, e.g. "Copied".
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        UIAccessibility.post(notification: .announcement, argument: message)
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.snappy, value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

/// Small uppercase label above each pane.
struct PaneHeader: View {
    let title: String
    let systemImage: String
    var trailing: String?

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
