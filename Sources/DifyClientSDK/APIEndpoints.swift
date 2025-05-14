import Foundation

/// Defines the HTTP methods used by the API client.
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    // Add other methods like PUT, DELETE, PATCH if needed by the API.
}

/// A protocol that defines the requirements for an API endpoint.
/// Each endpoint specifies its base URL, path, HTTP method, headers, and parameters.
public protocol APIEndpoint {
    /// The base URL for the endpoint (e.g., `https://api.dify.ai/v1`).
    var baseURL: URL { get }
    /// The specific path for the endpoint (e.g., `/completion-messages`).
    var path: String { get }
    /// The HTTP method to be used for the request (e.g., `.post`).
    var method: HTTPMethod { get }
    /// Optional HTTP headers specific to this endpoint.
    /// Common headers like `Authorization` and `Content-Type` are often handled by the `NetworkService`.
    var headers: [String: String]? { get }
    /// Optional URL parameters for GET requests. For POST/PUT requests, the body is handled separately.
    var parameters: [String: Any]? { get }
}

/// An enumeration of available Dify API endpoints.
/// This provides a type-safe way to define and use different API endpoints.
public enum DifyAPIEndpoint {
    /// Endpoint for text completion messages.
    case completionMessages
    /// Endpoint for chat messages.
    case chatMessages
    // Add other Dify API endpoints here as needed.
}

extension DifyAPIEndpoint: APIEndpoint {
    /// The base URL for all Dify API v1 endpoints.
    /// This can be overridden if the client needs to point to a self-hosted Dify instance.
    public var baseURL: URL {
        // It's generally better to make this configurable at the DifyClient level
        // to support self-hosted Dify instances easily. This serves as a default.
        guard let url = URL(string: "https://api.dify.ai/v1") else {
            // This fatalError is for development; in a production SDK, this might throw an error or be handled differently.
            fatalError("Invalid base URL string for Dify API. This should not happen.")
        }
        return url
    }

    /// The specific path component for each Dify API endpoint.
    public var path: String {
        switch self {
        case .completionMessages:
            return "/completion-messages"
        case .chatMessages:
            return "/chat-messages"
        }
    }

    /// The HTTP method required for each Dify API endpoint.
    /// Dify's primary interaction endpoints (completion, chat) use POST.
    public var method: HTTPMethod {
        switch self {
        case .completionMessages, .chatMessages:
            return .post
        }
    }

    /// Default headers for Dify API requests.
    /// The `Authorization` header (Bearer token) will be added by the `NetworkService`.
    /// `Content-Type` is typically `application/json` for POST requests with a body.
    public var headers: [String: String]? {
        return [
            "Content-Type": "application/json"
            // "Accept" header for streaming ("text/event-stream") is handled in NetworkService for stream requests.
        ]
    }

    /// URL parameters for the Dify API endpoints.
    /// The Dify endpoints covered (`completion-messages`, `chat-messages`) use a JSON body for parameters in POST requests,
    /// so no URL parameters are defined here.
    public var parameters: [String: Any]? {
        return nil
    }
}

