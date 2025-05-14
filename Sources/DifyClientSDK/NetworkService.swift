import Foundation

/// `NetworkService` is responsible for handling all network communication with the Dify API.
/// It constructs requests, sends them, and processes responses, including handling streaming data.
public class NetworkService {
    /// The `URLSession` instance used for non-streaming requests.
    private let session: URLSession
    /// A list to keep track of active `URLSessionDataTask`s, primarily for streaming tasks that might need explicit cancellation.
    private var dataTasks = [URLSessionDataTask]()
    /// The API key for authenticating with the Dify API.
    private let apiKey: String
    /// The base URL for the Dify API (e.g., `https://api.dify.ai/v1`).
    private let baseURL: URL

    /// A lazy-initialized `URLSession` specifically configured for streaming requests.
    /// It uses a delegate queue to handle `URLSessionDataDelegate` callbacks.
    // This session is not directly used in the current implementation as new sessions are created per stream for delegate assignment.
    // private lazy var streamingSession: URLSession = {
    //     let configuration = URLSessionConfiguration.default
    //     return URLSession(configuration: configuration, delegate: nil, delegateQueue: OperationQueue())
    // }()

    /// Initializes a new `NetworkService`.
    /// - Parameters:
    ///   - apiKey: The API key for Dify.
    ///   - baseURL: The base URL of the Dify API. Defaults to the Dify cloud API URL.
    ///   - session: An optional `URLSession` instance, primarily for testing purposes (e.g., injecting a mock session). Defaults to `URLSession.shared`.
    public init(apiKey: String, baseURL: URL = DifyAPIEndpoint.completionMessages.baseURL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Non-Streaming Request

    /// Performs a non-streaming (blocking) API request.
    /// - Parameters:
    ///   - endpoint: The `APIEndpoint` to target.
    ///   - method: The `HTTPMethod` for the request (defaults to `.post`).
    ///   - body: An optional `Encodable` object to be sent as the request body (JSON encoded).
    ///   - additionalHeaders: Optional additional HTTP headers for the request.
    /// - Returns: A `Decodable` object of type `T` representing the parsed API response.
    /// - Throws: A `DifyError` if the request fails due to network issues, API errors, or (de)serialization problems.
    public func request<T: Decodable, U: Encodable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .post,
        body: U? = nil,
        additionalHeaders: [String: String]? = nil
    ) async throws -> T {
        guard !apiKey.isEmpty else {
            throw DifyError.missingAPIKey
        }

        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Set common and endpoint-specific headers
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        additionalHeaders?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Encode and set the request body if provided
        if let body = body, (method == .post || method == .put || method == .patch) { // Add other methods if needed
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw DifyError.encodingError(error)
            }
        }
        
        // Perform the network request using async/await
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            throw DifyError.requestCancelled // Handle explicit task cancellation
        } catch {
            throw DifyError.networkError(error) // Handle other network errors
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DifyError.unknownError // Should be an HTTPURLResponse
        }

        // Check for successful HTTP status codes
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) // Try to get error message from response body
            throw DifyError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode the successful response data
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DifyError.decodingError(error)
        }
    }
    
    // MARK: - Streaming Request

    /// Performs a streaming API request using Server-Sent Events (SSE).
    /// - Parameters:
    ///   - endpoint: The `APIEndpoint` to target (must support streaming).
    ///   - method: The `HTTPMethod` for the request (defaults to `.post`).
    ///   - body: An `Encodable` object to be sent as the request body (JSON encoded). Must include `"response_mode": "streaming"`.
    ///   - additionalHeaders: Optional additional HTTP headers for the request.
    ///   - eventDataType: The `Decodable` type `T` that individual SSE `data:` fields are expected to conform to.
    /// - Returns: An `AsyncThrowingStream<T, Error>` that yields decoded objects of type `T` for each relevant SSE event.
    /// - Throws: A `DifyError` if the initial setup fails (e.g., encoding error, missing API key).
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func requestStream<T: Decodable, U: Encodable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .post,
        body: U, // Body is non-optional for streaming POST requests
        additionalHeaders: [String: String]? = nil,
        eventDataType: T.Type
    ) -> AsyncThrowingStream<T, Error> {
        guard !apiKey.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: DifyError.missingAPIKey)
            }
        }

        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Set headers for streaming
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept") // Crucial for SSE
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        additionalHeaders?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Encode request body
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: DifyError.encodingError(error))
            }
        }

        // Create and return the AsyncThrowingStream
        return AsyncThrowingStream { continuation in
            // Create a StreamProcessor instance to handle SSE parsing for this specific stream.
            let processor = StreamProcessor(eventDataType: eventDataType, continuation: continuation)
            
            // Create a new URLSession for this specific stream, with the StreamProcessor as its delegate.
            // This ensures delegate callbacks are routed to the correct processor.
            // An OperationQueue is used for delegate callbacks to ensure serial processing of events.
            let sessionWithDelegate = URLSession(configuration: .default, delegate: processor, delegateQueue: OperationQueue())
            
            let task = sessionWithDelegate.dataTask(with: request)
            processor.setTask(task) // Allow processor to hold a reference to its task for cancellation

            // Handle termination of the stream (e.g., if the consuming Task is cancelled).
            continuation.onTermination = @Sendable { _ in
                task.cancel() // Cancel the underlying URLSessionDataTask
            }
            
            self.dataTasks.append(task) // Keep track of the task (optional, for global cancellation)
            task.resume() // Start the request
        }
    }
    
    /// Cancels all active streaming tasks that were initiated by this `NetworkService` instance.
    /// Note: Individual streams are typically cancelled by cancelling the Task that consumes the `AsyncThrowingStream`.
    public func cancelAllStreamingTasks() {
        dataTasks.forEach { $0.cancel() }
        dataTasks.removeAll()
    }
}

