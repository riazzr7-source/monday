import SwiftUI
import MondayCore

public struct ConversationView: View {
    @ObservedObject public var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if appState.conversation.messages.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.conversation.messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }

                    if let error = appState.errorMessage {
                        errorBannerView(error: error)
                            .id("error_banner")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom_anchor")
                }
                .frame(maxWidth: Theme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: appState.conversation.messages.count) {
                withAnimation(Theme.defaultAnimation) {
                    proxy.scrollTo("bottom_anchor", anchor: .bottom)
                }
            }
            .onChange(of: appState.conversation.messages.last?.content) {
                proxy.scrollTo("bottom_anchor", anchor: .bottom)
            }
            .onChange(of: appState.errorMessage) {
                if appState.errorMessage != nil {
                    withAnimation(Theme.defaultAnimation) {
                        proxy.scrollTo("error_banner", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("MONDAY")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(2.5)
                .foregroundColor(Theme.textTertiary)

            Text("How can I help?")
                .font(.system(size: 26, weight: .medium, design: .default))
                .foregroundColor(Theme.textPrimary)

            Spacer()
        }
        .frame(minHeight: 320)
    }

    private func errorBannerView(error: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))

            Text(error)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()

            Button("Retry") {
                appState.retryLastMessage()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Dismiss") {
                appState.errorMessage = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
