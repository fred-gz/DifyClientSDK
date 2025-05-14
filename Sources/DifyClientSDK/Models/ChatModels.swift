import Foundation

// MARK: - Chat Messages Request

/// Represents the request body for a Dify chat message API call.
public struct ChatMessageRequest: Codable {
    /// Optional. A dictionary of input variables for the Dify application. 
    /// According to Dify documentation, new inputs are ignored if a `conversationId` is provided for an existing conversation.
    public let inputs: [String: String]?
    /// The user's query or message in the conversation.
    public let query: String
    /// The desired response mode (e.g., `.streaming` or `.blocking`).
    public let responseMode: ResponseMode
    /// Optional. The identifier of an existing conversation. If `nil` or omitted, a new conversation will be started.
    public var conversationId: String?
    /// A unique identifier for the user making the request.
    public let user: String

    /// Initializes a new chat message request.
    /// - Parameters:
    ///   - inputs: Optional dictionary of input variables.
    ///   - query: The user's query string.
    ///   - responseMode: The response mode. Defaults to `.blocking`.
    ///   - conversationId: Optional identifier for an existing conversation.
    ///   - user: The unique identifier for the end-user.
    public init(inputs: [String: String]? = nil, query: String, responseMode: ResponseMode = .blocking, conversationId: String? = nil, user: String) {
        self.inputs = inputs
        self.query = query
        self.responseMode = responseMode
        self.conversationId = conversationId
        self.user = user
    }

    enum CodingKeys: String, CodingKey {
        case inputs, query
        case responseMode = "response_mode"
        case conversationId = "conversation_id"
        case user
    }
}

// MARK: - Chat Messages Response (Non-Streaming / Blocking)

/// Represents the response from a non-streaming Dify chat message API call.
public struct ChatMessageResponse: Codable {
    /// The type of event, often "message" for a standard response.
    public let event: String?
    /// An identifier for the task associated with this message, if applicable.
    public let taskId: String?
    /// The identifier of the conversation this message belongs to. This will be populated even for new conversations.
    public let conversationId: String
    /// The mode of the Dify application (e.g., "chat").
    public let mode: String?
    /// The generated answer or reply from the Dify application.
    public let answer: String
    /// Optional metadata associated with the response, such as usage statistics.
    public let metadata: Metadata? // Reusing from CommonModels
    /// Timestamp of when the response was created, typically in Unix epoch seconds.
    public let createdAt: Int
    /// The unique identifier for this specific message.
    public let messageId: String?

    enum CodingKeys: String, CodingKey {
        case event
        case taskId = "task_id"
        case conversationId = "conversation_id"
        case mode
        case answer
        case metadata
        case createdAt = "created_at"
        case messageId = "message_id"
    }
}

