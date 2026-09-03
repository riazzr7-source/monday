import Foundation

public struct ChatMessagePayload: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [ChatMessagePayload]
    public let stream: Bool

    public init(model: String, messages: [ChatMessagePayload], stream: Bool = true) {
        self.model = model
        self.messages = messages
        self.stream = stream
    }
}

public struct ChatCompletionChunk: Codable, Sendable {
    public let id: String?
    public let choices: [StreamChoice]

    public struct StreamChoice: Codable, Sendable {
        public let index: Int?
        public let delta: StreamDelta?
        public let finish_reason: String?
    }

    public struct StreamDelta: Codable, Sendable {
        public let role: String?
        public let content: String?
    }
}

public struct OpenAIErrorResponse: Codable, Sendable {
    public let error: ErrorDetails

    public struct ErrorDetails: Codable, Sendable {
        public let message: String
        public let type: String?
        public let code: String?
    }
}

public struct OpenAIModelOption: Identifiable, Sendable, Hashable {
    public let id: String
    public let displayName: String
    public let description: String

    public static let defaults: [OpenAIModelOption] = [
        OpenAIModelOption(id: "gpt-4o-mini", displayName: "GPT-4o Mini", description: "Fast, lightweight & smart"),
        OpenAIModelOption(id: "gpt-4o", displayName: "GPT-4o", description: "High intelligence for complex tasks"),
        OpenAIModelOption(id: "gpt-3.5-turbo", displayName: "GPT-3.5 Turbo", description: "Legacy lightweight model")
    ]
}
