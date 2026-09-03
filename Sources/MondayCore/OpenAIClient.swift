import Foundation

public protocol OpenAIClientProtocol: Sendable {
    func testConnection(apiKey: String) async throws -> Bool
    func streamChat(
        messages: [ChatMessagePayload],
        apiKey: String,
        model: String
    ) -> AsyncThrowingStream<String, Error>
}

public final class OpenAIClient: OpenAIClientProtocol, @unchecked Sendable {
    public static let shared = OpenAIClient()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func testConnection(apiKey: String) async throws -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw MondayError.missingAPIKey("OpenAI")
        }

        let url = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MondayError.networkError("Invalid server response")
            }

            if httpResponse.statusCode == 200 {
                return true
            } else if httpResponse.statusCode == 401 {
                throw MondayError.invalidAPIKey("OpenAI")
            } else if httpResponse.statusCode == 429 {
                throw MondayError.rateLimited
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
                    continuation.finish(throwing: MondayError.missingAPIKey("OpenAI"))
                    return
                }

                let url = baseURL.appendingPathComponent("chat/completions")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 60.0

                let payload = ChatCompletionRequest(
                    model: model,
                    messages: messages,
                    stream: true
                )

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
                            if errorData.count > 4096 { break }
                        }
                        let errorMsg = extractErrorMessage(from: errorData) ?? "HTTP \(httpResponse.statusCode)"
                        if httpResponse.statusCode == 401 {
                            continuation.finish(throwing: MondayError.invalidAPIKey("OpenAI"))
                        } else if httpResponse.statusCode == 429 {
                            continuation.finish(throwing: MondayError.rateLimited)
                        } else {
                            continuation.finish(throwing: MondayError.serverError(statusCode: httpResponse.statusCode, message: errorMsg))
                        }
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
                                if let chunk = try? decoder.decode(ChatCompletionChunk.self, from: jsonData),
                                   let deltaContent = chunk.choices.first?.delta?.content,
                                   !deltaContent.isEmpty {
                                    continuation.yield(deltaContent)
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
        if let decoded = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            return decoded.error.message
        }
        return String(data: data, encoding: .utf8)
    }
}
