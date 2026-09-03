import Foundation

public enum MessageRole: String, Codable, Sendable, CaseIterable {
    case system
    case user
    case assistant
}

public struct Message: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var role: MessageRole
    public var content: String
    public let createdAt: Date
    public var isStreaming: Bool
    public var isError: Bool

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        isStreaming: Bool = false,
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isStreaming = isStreaming
        self.isError = isError
    }
}

public struct Conversation: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var messages: [Message]

    public init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

public enum MondayError: LocalizedError, Sendable, Equatable {
    case missingAPIKey(String)
    case invalidAPIKey(String)
    case rateLimited
    case networkError(String)
    case serverError(statusCode: Int, message: String)
    case cancelled
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key is missing. Please add your key in Settings."
        case .invalidAPIKey(let provider):
            return "Invalid \(provider) API key. Please verify the key in Settings."
        case .rateLimited:
            return "Rate limit reached. Please wait a moment and try again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .cancelled:
            return "Response generation was stopped."
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}
