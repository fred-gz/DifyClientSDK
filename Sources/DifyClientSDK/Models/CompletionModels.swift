import Foundation

// MARK: - Completion Messages Request

/// Represents the request body for a Dify completion message API call.
public struct CompletionRequest: Codable {
    /// A dictionary of input variables for the Dify application. 
    /// The keys and expected values depend on the specific Dify application's configuration.
    /// For completion messages, this typically includes the main input text.
    public let inputs: [String: String]
    /// The desired response mode (e.g., `.streaming` or `.blocking`).
    public let responseMode: ResponseMode
    /// A unique identifier for the user making the request.
    public let user: String
    // `query` is not used for completion messages according to the Dify documentation; `inputs` holds the primary content.
    // `conversation_id` is not used for completion messages.

    /// Initializes a new completion request.
    /// - Parameters:
    ///   - inputs: A dictionary of input variables. For example, `["text": "Translate this to French:"]`.
    ///   - responseMode: The response mode. Defaults to `.blocking`.
    ///   - user: The unique identifier for the end-user.
    public init(inputs: [String: String], responseMode: ResponseMode = .blocking, user: String) {
        self.inputs = inputs
        self.responseMode = responseMode
        self.user = user
    }

    enum CodingKeys: String, CodingKey {
        case inputs
        case responseMode = "response_mode"
        case user
    }
}

// MARK: - Completion Messages Response (Non-Streaming / Blocking)

/// Represents the response from a non-streaming Dify completion message API call.
public struct CompletionResponse: Codable {
    /// The main content of the message, including the generated answer.
    public let message: MessageContent
    /// Optional metadata associated with the response, such as usage statistics.
    public let metadata: Metadata? // Included from CommonModels
    /// Timestamp of when the response was created, typically in Unix epoch seconds.
    public let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case message
        case metadata
        case createdAt = "created_at"
    }
}

/// Represents the content of a message within a Dify API response.
public struct MessageContent: Codable {
    /// The unique identifier for this specific message.
    public let id: String
    /// The identifier of the conversation this message belongs to.
    public let conversationId: String
    /// The generated answer or text from the Dify application.
    public let answer: String
    /// Timestamp of when the message was created, typically in Unix epoch seconds.
    public let createdAt: Int
    // Other fields like 'tool_calls', 'files', etc., might be present depending on the Dify application's capabilities.
    // These are not included by default but can be added if needed.

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case answer
        case createdAt = "created_at"
    }
}

