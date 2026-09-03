import Foundation
import SwiftUI
import Combine
import MondayCore

@MainActor
public final class AppState: ObservableObject {
    @Published public var conversation: Conversation
    @Published public var isStreaming: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var isSettingsOpen: Bool = false

    public let settings: SettingsManager
    private let storage: LocalStorageManagerProtocol
    private let openAIClient: OpenAIClientProtocol
    private let geminiClient: GeminiClientProtocol
    private var streamingTask: Task<Void, Never>? = nil

    public init(
        settings: SettingsManager? = nil,
        storage: LocalStorageManagerProtocol = LocalStorageManager.shared,
        openAIClient: OpenAIClientProtocol = OpenAIClient.shared,
        geminiClient: GeminiClientProtocol = GeminiClient.shared
    ) {
        let set = settings ?? SettingsManager()
        self.settings = set
        self.storage = storage
        self.openAIClient = openAIClient
        self.geminiClient = geminiClient

        // Restore active conversation or create new
        if let loaded = try? storage.loadActiveConversation() {
            self.conversation = loaded
        } else {
            self.conversation = Conversation()
        }
    }

    public func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil

        // Auto-switch to available provider if needed
        settings.autoSelectAvailableModel()
        let provider = settings.currentProvider

        guard let apiKey = try? settings.getKey(for: provider), !apiKey.isEmpty else {
            errorMessage = "API key not configured. Please open Settings to add your Google Gemini or OpenAI API key."
            isSettingsOpen = true
            return
        }

        // Add user message
        let userMsg = Message(role: .user, content: trimmed)
        conversation.messages.append(userMsg)
        conversation.updatedAt = Date()
        persistConversation()

        // Prepare assistant placeholder message
        let assistantMsgId = UUID()
        let assistantMsg = Message(id: assistantMsgId, role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantMsg)
        isStreaming = true

        // Build message payload excluding empty messages
        var payloads: [ChatMessagePayload] = [
            ChatMessagePayload(role: "system", content: "You are MONDAY, a calm, precise, and helpful personal AI assistant for macOS.")
        ]
        for msg in conversation.messages where !msg.isError && msg.id != assistantMsgId && !msg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payloads.append(ChatMessagePayload(role: msg.role.rawValue, content: msg.content))
        }

        let model = settings.selectedModel

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let stream: AsyncThrowingStream<String, Error>
                switch provider {
                case .openAI:
                    stream = self.openAIClient.streamChat(
                        messages: payloads,
                        apiKey: apiKey,
                        model: model
                    )
                case .gemini:
                    stream = self.geminiClient.streamChat(
                        messages: payloads,
                        apiKey: apiKey,
                        model: model
                    )
                }

                var accumulatedText = ""
                for try await token in stream {
                    if Task.isCancelled { break }
                    accumulatedText += token
                    if let index = self.conversation.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.conversation.messages[index].content = accumulatedText
                    }
                }

                if let index = self.conversation.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.conversation.messages[index].isStreaming = false
                }
                self.isStreaming = false
                self.persistConversation()
            } catch {
                if let index = self.conversation.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    if self.conversation.messages[index].content.isEmpty {
                        self.conversation.messages.remove(at: index)
                    } else {
                        self.conversation.messages[index].isStreaming = false
                    }
                }
                self.isStreaming = false
                if let mondayError = error as? MondayError, mondayError == .cancelled {
                    // User canceled
                } else {
                    self.errorMessage = error.localizedDescription
                }
                self.persistConversation()
            }
        }
    }

    public func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false

        if let lastIndex = conversation.messages.indices.last, conversation.messages[lastIndex].isStreaming {
            conversation.messages[lastIndex].isStreaming = false
        }
        persistConversation()
    }

    public func retryLastMessage() {
        errorMessage = nil
        while let last = conversation.messages.last, last.role == .assistant && (last.content.isEmpty || last.isError) {
            conversation.messages.removeLast()
        }
        guard let lastUserMsgIndex = conversation.messages.lastIndex(where: { $0.role == .user }) else {
            return
        }
        let userContent = conversation.messages[lastUserMsgIndex].content
        conversation.messages.remove(at: lastUserMsgIndex)
        sendMessage(userContent)
    }

    public func newConversation() {
        stopStreaming()
        errorMessage = nil
        conversation = Conversation()
        persistConversation()
    }

    private func persistConversation() {
        try? storage.saveActiveConversation(conversation)
    }
}
