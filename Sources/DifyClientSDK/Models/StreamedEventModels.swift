import Foundation

// MARK: - Streamed Event Structures

/// Represents the different types of events Dify might send in a Server-Sent Events (SSE) stream.
/// The `event` field in an SSE line (e.g., `event: message_end`).
public enum DifyStreamEventType: String, Decodable {
    /// Indicates a standard message chunk containing part of the response.
    case message        = "message"
    /// Indicates an agent message chunk, if the Dify application uses agents.
    case agentMessage   = "agent_message"
    /// Marks the end of a message stream, often accompanied by metadata in its data field.
    case messageEnd     = "message_end"
    /// Indicates that a previous part of the message should be replaced (if supported by the API).
    case messageReplace = "message_replace"
    /// Indicates an error occurred during the streaming process. The data field may contain error details.
    case error          = "error"
    /// A keep-alive or other non-data event, typically used to prevent connection timeouts.
    case ping           = "ping"
    // Add other event types as discovered from Dify's API behavior or documentation.
}

// MARK: - Streamed Completion Message Event Data

/// Represents the data structure expected within the `data:` field of an SSE event
/// when streaming completion messages from the Dify API.
public struct StreamedCompletionData: Decodable {
    /// The unique identifier for the message, which may appear in chunks.
    public let id: String?
    /// The identifier for the task associated with this completion, may appear in chunks.
    public let task_id: String?
    /// The mode of the Dify application (e.g., "completion").
    public let mode: String?
    /// The chunk of the generated text answer.
    public let answer: String
    /// Optional timestamp of when this chunk was created, typically in Unix epoch seconds.
    public let createdAt: Int?
    /// Optional identifier of the conversation this completion belongs to.
    public let conversationId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case task_id
        case mode
        case answer
        case createdAt = "created_at"
        case conversationId = "conversation_id"
    }
}

// MARK: - Streamed Chat Message Event Data

/// Represents the data structure expected within the `data:` field of an SSE event
/// when streaming chat messages from the Dify API.
public struct StreamedChatData: Decodable {
    /// The unique identifier for the message.
    public let id: String?
    /// The identifier for the task associated with this chat message.
    public let task_id: String?
    /// The identifier of the conversation this chat message belongs to.
    public let conversationId: String
    /// The mode of the Dify application (e.g., "chat").
    public let mode: String?
    /// The chunk of the generated text answer.
    public let answer: String
    /// Optional timestamp of when this chunk was created, typically in Unix epoch seconds.
    public let createdAt: Int?
    /// Often the same as `id`, or a more specific message identifier within the conversation.
    public let messageId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case task_id
        case conversationId = "conversation_id"
        case mode
        case answer
        case createdAt = "created_at"
        case messageId = "message_id"
    }
}

// MARK: - Stream End Metadata / Final Event Data

/// Represents metadata that might be sent with a special 'message_end' event in an SSE stream.
/// This structure captures information often provided at the conclusion of a streamed response.
public struct StreamEndMetadata: Decodable {
    /// The identifier of the conversation.
    public let conversationId: String?
    /// The unique identifier of the completed message.
    public let messageId: String?
    /// The identifier of the completed task.
    public let taskId: String?
    /// Usage statistics and other metadata for the entire streamed transaction.
    public let metadata: Metadata? // Reusing from CommonModels
    /// Timestamp of when the stream concluded or the final message was created.
    public let createdAt: Int?
    // Add any other fields that Dify sends at the end of a stream.

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case messageId = "message_id"
        case taskId = "task_id"
        case metadata
        case createdAt = "created_at"
    }
}

// MARK: - Stream Error Detail

/// Represents the structure of an error object sent as data within an 'error' event in an SSE stream.
public struct StreamErrorDetail: Decodable {
    /// An optional error code provided by the API.
    public let code: Int?
    /// A descriptive message detailing the error.
    public let message: String?
    /// An optional status string associated with the error (e.g., "error").
    public let status: String?
}

