import Foundation

/// `DifyError` defines the possible errors that can occur when interacting with the Dify API through the SDK.
public enum DifyError: Error, LocalizedError, Equatable {
    /// Indicates that the URL constructed for the API request was invalid.
    case invalidURL
    /// Encapsulates a network-related error that occurred during the request (e.g., no internet connection).
    case networkError(Error)
    /// Represents an error returned by the Dify API itself, including an HTTP status code and an optional error message from the API.
    case apiError(statusCode: Int, message: String?)
    /// Occurs when the SDK fails to decode the API response (e.g., unexpected JSON structure).
    case decodingError(Error)
    /// Occurs when the SDK fails to encode the request body (e.g., invalid input data for JSON conversion).
    case encodingError(Error)
    /// A generic error for situations not covered by other specific error types.
    case unknownError
    /// Indicates that the API request was cancelled by the client.
    case requestCancelled
    /// Occurs during streaming if an SSE event cannot be parsed correctly or if the data within an event is malformed.
    case streamParsingError(String)
    /// Indicates that the API key was not provided or is empty when making a request.
    case missingAPIKey

    /// Provides a human-readable description for each error type.
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL。"
        case .networkError(let error):
            return "网络请求失败: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API 错误，状态码: \(statusCode), 信息: \(message ?? "无")"
        case .decodingError(let error):
            return "响应数据解码失败: \(error.localizedDescription)"
        case .encodingError(let error):
            return "请求数据编码失败: \(error.localizedDescription)"
        case .unknownError:
            return "发生未知错误。"
        case .requestCancelled:
            return "请求已取消。"
        case .streamParsingError(let details):
            return "流数据解析错误: \(details)"
        case .missingAPIKey:
            return "API 密钥缺失。"
        }
    }

    /// Conformance to `Equatable` for comparing `DifyError` instances, primarily useful for testing.
    public static func == (lhs: DifyError, rhs: DifyError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.networkError(let lError), .networkError(let rError)):
            // Comparing underlying NSError domain and code for network errors
            return (lError as NSError).domain == (rError as NSError).domain && (lError as NSError).code == (rError as NSError).code
        case (.apiError(let lCode, let lMessage), .apiError(let rCode, let rMessage)):
            return lCode == rCode && lMessage == rMessage
        case (.decodingError(let lError), .decodingError(let rError)):
            return (lError as NSError).domain == (rError as NSError).domain && (lError as NSError).code == (rError as NSError).code
        case (.encodingError(let lError), .encodingError(let rError)):
            return (lError as NSError).domain == (rError as NSError).domain && (lError as NSError).code == (rError as NSError).code
        case (.unknownError, .unknownError):
            return true
        case (.requestCancelled, .requestCancelled):
            return true
        case (.streamParsingError(let lDetails), .streamParsingError(let rDetails)):
            return lDetails == rDetails
        case (.missingAPIKey, .missingAPIKey):
            return true
        default:
            return false
        }
    }
}

