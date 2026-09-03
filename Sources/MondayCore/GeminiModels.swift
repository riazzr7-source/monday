import Foundation

public struct GeminiPart: Codable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct GeminiContent: Codable, Sendable {
    public let role: String?
    public let parts: [GeminiPart]

    public init(role: String?, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

public struct GeminiGenerateContentRequest: Codable, Sendable {
    public let contents: [GeminiContent]
    public let systemInstruction: GeminiContent?

    public init(contents: [GeminiContent], systemInstruction: GeminiContent? = nil) {
        self.contents = contents
        self.systemInstruction = systemInstruction
    }
}

public struct GeminiResponseChunk: Codable, Sendable {
    public let candidates: [GeminiCandidate]?

    public struct GeminiCandidate: Codable, Sendable {
        public let content: GeminiCandidateContent?
        public let finishReason: String?
    }

    public struct GeminiCandidateContent: Codable, Sendable {
        public let parts: [GeminiPart]?
        public let role: String?
    }
}

public struct GeminiErrorResponse: Codable, Sendable {
    public let error: ErrorDetails

    public struct ErrorDetails: Codable, Sendable {
        public let code: Int?
        public let message: String
        public let status: String?
    }
}

public struct ModelOption: Identifiable, Sendable, Hashable {
    public let id: String
    public let provider: AIProvider
    public let displayName: String
    public let description: String

    public static let defaults: [ModelOption] = [
        // Gemini
        ModelOption(id: "gemini-2.0-flash", provider: .gemini, displayName: "Gemini 2.0 Flash", description: "Ultra-fast, highly intelligent (Recommended)"),
        ModelOption(id: "gemini-1.5-flash", provider: .gemini, displayName: "Gemini 1.5 Flash", description: "High-speed & versatile"),
        ModelOption(id: "gemini-1.5-pro", provider: .gemini, displayName: "Gemini 1.5 Pro", description: "Advanced complex reasoning"),
        ModelOption(id: "gemini-2.5-flash", provider: .gemini, displayName: "Gemini 2.5 Flash", description: "Flash experimental"),
        ModelOption(id: "gemini-2.5-pro", provider: .gemini, displayName: "Gemini 2.5 Pro", description: "Pro experimental"),
        // OpenAI
        ModelOption(id: "gpt-4o-mini", provider: .openAI, displayName: "GPT-4o Mini", description: "Fast, lightweight & smart"),
        ModelOption(id: "gpt-4o", provider: .openAI, displayName: "GPT-4o", description: "High intelligence for complex tasks"),
        ModelOption(id: "gpt-3.5-turbo", provider: .openAI, displayName: "GPT-3.5 Turbo", description: "Legacy model")
    ]
}
