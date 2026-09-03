import Foundation

public protocol GeminiClientProtocol: Sendable {
    func testConnection(apiKey: String) async throws -> Bool
    func streamChat(
        messages: [ChatMessagePayload],
        apiKey: String,
        model: String
    ) -> AsyncThrowingStream<String, Error>
}

public final class GeminiClient: GeminiClientProtocol, @unchecked Sendable {
    public static let shared = GeminiClient()

    private let session: URLSession
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func testConnection(apiKey: String) async throws -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw MondayError.missingAPIKey("Google Gemini")
        }

        guard var components = URLComponents(string: "\(baseURL)/models") else {
            throw MondayError.networkError("Invalid Gemini URL")
        }
        components.queryItems = [URLQueryItem(name: "key", value: trimmedKey)]

        guard let url = components.url else {
            throw MondayError.networkError("Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MondayError.networkError("Invalid server response")
            }

            if httpResponse.statusCode == 200 {
                return true
            } else {
                let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                throw MondayError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
            }
        } catch let err as MondayError {
            throw err
        } catch {
            throw MondayError.networkError(error.localizedDescription)
        }
    }

    public func streamChat(
        messages: [ChatMessagePayload],
        apiKey: String,
        model: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(String.self) { continuation in
            let task = Task {
                let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedKey.isEmpty else {
                    continuation.finish(throwing: MondayError.missingAPIKey("Google Gemini"))
                    return
                }

                // Format model identifier: strip "models/" if present
                let cleanModel = model.replacingOccurrences(of: "models/", with: "")
                guard var components = URLComponents(string: "\(baseURL)/models/\(cleanModel):streamGenerateContent") else {
                    continuation.finish(throwing: MondayError.networkError("Invalid Gemini URL"))
                    return
                }
                components.queryItems = [
                    URLQueryItem(name: "alt", value: "sse"),
                    URLQueryItem(name: "key", value: trimmedKey)
                ]

                guard let url = components.url else {
                    continuation.finish(throwing: MondayError.networkError("Invalid URL components"))
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 60.0

                // Build contents ensuring alternation and non-empty text
                var contents: [GeminiContent] = []
                var systemText: String? = nil

                for msg in messages {
                    let cleanText = msg.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanText.isEmpty else { continue }

                    if msg.role == "system" {
                        if let existing = systemText {
                            systemText = "\(existing)\n\(cleanText)"
                        } else {
                            systemText = cleanText
                        }
                    } else {
                        let geminiRole = (msg.role == "assistant") ? "model" : "user"

                        if let last = contents.last, last.role == geminiRole {
                            // Merge consecutive turns of same role to satisfy Gemini API requirements
                            let combinedParts = last.parts + [GeminiPart(text: cleanText)]
                            contents[contents.count - 1] = GeminiContent(role: geminiRole, parts: combinedParts)
                        } else {
                            contents.append(GeminiContent(role: geminiRole, parts: [GeminiPart(text: cleanText)]))
                        }
                    }
                }

                // Gemini must start with a user message
                if contents.first?.role == "model" {
                    contents.removeFirst()
                }

                guard !contents.isEmpty else {
                    continuation.finish(throwing: MondayError.unknown("No messages to send."))
                    return
                }

                let systemInstruction = systemText.map { GeminiContent(role: nil, parts: [GeminiPart(text: $0)]) }
                let payload = GeminiGenerateContentRequest(contents: contents, systemInstruction: systemInstruction)

                do {
                    request.httpBody = try JSONEncoder().encode(payload)
                } catch {
                    continuation.finish(throwing: MondayError.unknown("Failed to encode request: \(error.localizedDescription)"))
                    return
                }

                do {
                    let (asyncBytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: MondayError.networkError("Invalid server response"))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                            if errorData.count > 8192 { break }
                        }
                        let errorMsg = extractErrorMessage(from: errorData) ?? "HTTP \(httpResponse.statusCode)"
                        continuation.finish(throwing: MondayError.serverError(statusCode: httpResponse.statusCode, message: errorMsg))
                        return
                    }

                    let decoder = JSONDecoder()

                    for try await rawLine in asyncBytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: MondayError.cancelled)
                            return
                        }

                        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        if line.isEmpty || line.hasPrefix(":") {
                            continue
                        }

                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                            if jsonString == "[DONE]" {
                                break
                            }

                            if let jsonData = jsonString.data(using: .utf8) {
                                if let chunk = try? decoder.decode(GeminiResponseChunk.self, from: jsonData),
                                   let parts = chunk.candidates?.first?.content?.parts {
                                    for part in parts {
                                        if !part.text.isEmpty {
                                            continuation.yield(part.text)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: MondayError.cancelled)
                } catch {
                    continuation.finish(throwing: MondayError.networkError(error.localizedDescription))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        if let decoded = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
            return decoded.error.message
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errorObj = json["error"] as? [String: Any], let msg = errorObj["message"] as? String {
                return msg
            }
        }
        if let str = String(data: data, encoding: .utf8), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return str
        }
        return nil
    }
}
