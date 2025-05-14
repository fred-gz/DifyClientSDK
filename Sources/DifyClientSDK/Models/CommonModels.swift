import Foundation

// MARK: - Common Request Structures

/// Common fields for Dify API requests.
public struct DifyRequestCommon: Codable {
    /// The response mode, either streaming or blocking.
    public let responseMode: ResponseMode
    /// A unique identifier for the user making the request.
    public let user: String
    /// A dictionary of input variables for the Dify application. 
    /// The keys and expected values depend on the specific Dify application's configuration.
    public var inputs: [String: String]

    /// Initializes a common request structure.
    /// - Parameters:
    ///   - responseMode: The desired response mode (e.g., `.streaming` or `.blocking`).
    ///   - user: The unique identifier for the end-user.
    ///   - inputs: A dictionary of input variables for the Dify application.
    public init(responseMode: ResponseMode, user: String, inputs: [String: String]) {
        self.responseMode = responseMode
        self.user = user
        self.inputs = inputs
    }

    enum CodingKeys: String, CodingKey {
        case responseMode = "response_mode"
        case user
        case inputs
    }
}

/// Specifies the response mode for an API request.
public enum ResponseMode: String, Codable {
    /// Server-Sent Events will be used for a streaming response.
    case streaming = "streaming"
    /// A single, complete response will be sent after processing.
    case blocking = "blocking"
}

// MARK: - Common Response Structures

/// Common fields that might appear in Dify API responses.
public struct DifyResponseCommon: Codable {
    /// Optional metadata associated with the response, such as usage statistics.
    public let metadata: Metadata?
    /// Optional timestamp of when the response was created, typically in Unix epoch seconds.
    public let createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case metadata
        case createdAt = "created_at"
    }
}

/// Metadata associated with an API response, often including token usage and retrieved resources.
public struct Metadata: Codable {
    /// Token usage statistics for the request.
    public let usage: Usage?
    /// Information about resources retrieved by the Dify application, if applicable.
    public let retrieverResources: [RetrieverResource]?

    enum CodingKeys: String, CodingKey {
        case usage
        case retrieverResources = "retriever_resources"
    }
}

/// Detailed token usage statistics for an API call.
public struct Usage: Codable {
    public let promptTokens: Int
    public let promptUnitPrice: String?
    public let promptPrice: String?
    public let promptPriceUnit: String?
    public let completionTokens: Int
    public let completionUnitPrice: String?
    public let completionPrice: String?
    public let completionPriceUnit: String?
    public let totalTokens: Int
    public let totalPrice: String?
    public let totalPriceUnit: String?
    public let currency: String?
    public let latency: Double?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case promptUnitPrice = "prompt_unit_price"
        case promptPrice = "prompt_price"
        case promptPriceUnit = "prompt_price_unit"
        case completionTokens = "completion_tokens"
        case completionUnitPrice = "completion_unit_price"
        case completionPrice = "completion_price"
        case completionPriceUnit = "completion_price_unit"
        case totalTokens = "total_tokens"
        case totalPrice = "total_price"
        case totalPriceUnit = "total_price_unit"
        case currency
        case latency
    }
}

/// Represents a resource retrieved by the Dify application, often from a knowledge base.
public struct RetrieverResource: Codable {
    public let position: Int
    public let datasetId: String
    public let datasetName: String
    public let documentId: String
    public let documentName: String
    public let segmentId: String
    public let score: Double?
    public let content: String

    enum CodingKeys: String, CodingKey {
        case position
        case datasetId = "dataset_id"
        case datasetName = "dataset_name"
        case documentId = "document_id"
        case documentName = "document_name"
        case segmentId = "segment_id"
        case score
        case content
    }
}

