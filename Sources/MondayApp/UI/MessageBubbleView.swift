import SwiftUI
import MondayCore
import AppKit

public struct MessageBubbleView: View {
    public let message: Message
    @State private var isHovered: Bool = false
    @State private var copied: Bool = false

    public init(message: Message) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 40)
                userMessageBubble
            } else {
                assistantMessageBubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var userMessageBubble: some View {
        Text(message.content)
            .font(.system(size: 14.5, weight: .regular, design: .default))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .fill(Theme.userBubble)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .stroke(Theme.subtleBorder, lineWidth: 0.8)
            )
            .textSelection(.enabled)
    }

    private var assistantMessageBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isStreaming && message.content.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Thinking...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, 6)
            } else {
                Text(LocalizedStringKey(message.content))
                    .font(.system(size: 14.5, weight: .regular, design: .default))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)
                    .textSelection(.enabled)

                if message.isStreaming {
                    Circle()
                        .fill(Theme.textTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(0.8)
                }
            }

            if !message.content.isEmpty && !message.isStreaming {
                HStack {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1.0 : 0.0)
                    .animation(Theme.defaultAnimation, value: isHovered)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
