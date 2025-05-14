import Foundation

/// `DifyClient` is the main entry point for interacting with the Dify API.
/// It provides methods for both non-streaming (blocking) and streaming API calls
/// for text completion and chat functionalities.
///
/// ## Initialization
/// Initialize `DifyClient` with your API key and an optional base URL if you are using a self-hosted Dify instance:
/// ```swift
/// let client = DifyClient(apiKey: "YOUR_DIFY_API_KEY")
/// // For self-hosted Dify:
/// // let client = DifyClient(apiKey: "YOUR_DIFY_API_KEY", baseURL: URL(string: "https://your-dify-instance.com/v1"))
/// ```
///
/// ## Making Requests
/// All request methods are asynchronous and use Swift's `async/await` syntax.
///
/// ### Non-Streaming (Blocking) Requests
/// These methods return a single response object upon completion.
///
/// **Completion Message:**
/// ```swift
/// do {
///     let response = try await client.getCompletionMessage(
///         inputs: ["prompt": "Write a short story about a robot."],
///         user: "user-123"
///     )
///     print("Answer: \(response.message.answer)")
/// } catch {
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
///
/// **Chat Message:**
/// ```swift
/// do {
///     // Start a new conversation or continue an existing one
///     let response = try await client.sendChatMessage(
///         query: "Hello, Dify!",
///         user: "user-456",
///         conversationId: nil // or provide an existing conversationId
///     )
///     print("Dify says: \(response.answer)")
///     // Use response.conversationId for subsequent messages in the same chat
/// } catch {
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
///
/// ### Streaming Requests
/// These methods return an `AsyncThrowingStream` that yields data chunks as they arrive from the API.
///
/// **Stream Completion Message:**
/// ```swift
/// let streamTask = Task {
///     do {
///         let stream = client.streamCompletionMessage(
///             inputs: ["prompt": "Tell me a joke."],
///             user: "user-789"
///         )
///         for try await chunk in stream {
///             print(chunk.answer, terminator: "") // Print parts of the answer as they arrive
///         }
///         print()
///     } catch {
///         print("Streaming error: \(error.localizedDescription)")
///     }
/// }
/// // To cancel the stream: streamTask.cancel()
/// ```
///
/// **Stream Chat Message:**
/// ```swift
/// let chatStreamTask = Task {
///     do {
///         let stream = client.streamChatMessage(
///             query: "What is Swift programming?",
///             user: "user-101",
///             conversationId: nil // or an existing ID
///         )
///         var fullResponse = ""
///         for try await chunk in stream {
///             fullResponse += chunk.answer
///             print(chunk.answer, terminator: "")
///         }
///         print("\nFull streamed response: \(fullResponse)")
///     } catch {
///         print("Chat streaming error: \(error.localizedDescription)")
///     }
/// }
/// // To cancel the stream: chatStreamTask.cancel()
/// ```
///
/// ## Error Handling
/// All methods can throw `DifyError` for issues like network problems, API errors, or data parsing failures.
///
/// ## Cancellation
/// - **Non-Streaming Requests:** Cancel the `Task` that is awaiting the `async` method.
/// - **Streaming Requests:** Cancel the `Task` that is iterating over the `AsyncThrowingStream`.
///   This will trigger the stream's termination handler, which in turn cancels the underlying network request.
///   You can also call `client.cancelAllStreams()` to attempt to cancel all active streaming tasks initiated by that client instance,
///   though individual task cancellation is generally preferred.
public class DifyClient {
    /// The `NetworkService` instance responsible for actual HTTP communication.
    private let networkService: NetworkService
    /// The API key used for authenticating requests.
    private let apiKey: String
    /// The base URL for the Dify API.
    private let baseURL: URL

    /// Initializes a new `DifyClient`.
    /// - Parameters:
    ///   - apiKey: Your Dify API key.
    ///   - baseURL: Optional. The base URL for the Dify API. If `nil`, the default Dify cloud API URL (`https://api.dify.ai/v1`) is used.
    ///              Provide this if you are using a self-hosted Dify instance.
    ///   - networkService: Optional. A `NetworkService` instance. Used primarily for testing to inject a mock service.
    public init(apiKey: String, baseURL: URL? = nil, networkService: NetworkService? = nil) {
        self.apiKey = apiKey
        self.baseURL = baseURL ?? DifyAPIEndpoint.completionMessages.baseURL // Default to Dify cloud if not provided
        self.networkService = networkService ?? NetworkService(apiKey: apiKey, baseURL: self.baseURL)
    }

    // MARK: - Completion Messages (Non-Streaming)

    /// Sends a request to the Dify API to get a completion message in a non-streaming (blocking) manner.
    /// - Parameters:
    ///   - inputs: A dictionary of input variables for the Dify application (e.g., `["prompt": "Your prompt here"]`).
    ///   - user: A unique identifier for the end-user making the request.
    /// - Returns: A `CompletionResponse` object containing the Dify application's answer and metadata.
    /// - Throws: A `DifyError` if the request fails.
    public func getCompletionMessage(
        inputs: [String: String],
        user: String
    ) async throws -> CompletionResponse {
        let requestBody = CompletionRequest(inputs: inputs, responseMode: .blocking, user: user)
        return try await networkService.request(
            endpoint: DifyAPIEndpoint.completionMessages,
            method: .post,
            body: requestBody
        )
    }

    // MARK: - Chat Messages (Non-Streaming)

    /// Sends a chat message to the Dify API in a non-streaming (blocking) manner.
    /// - Parameters:
    ///   - query: The user's query or message.
    ///   - user: A unique identifier for the end-user making the request.
    ///   - inputs: Optional. A dictionary of input variables for the Dify application. Ignored if `conversationId` is for an existing conversation.
    ///   - conversationId: Optional. The ID of an existing conversation to continue. If `nil`, a new conversation is started.
    /// - Returns: A `ChatMessageResponse` object containing the Dify application's reply, conversation ID, and metadata.
    /// - Throws: A `DifyError` if the request fails.
    public func sendChatMessage(
        query: String,
        user: String,
        inputs: [String: String]? = nil,
        conversationId: String? = nil
    ) async throws -> ChatMessageResponse {
        let requestBody = ChatMessageRequest(
            inputs: inputs,
            query: query,
            responseMode: .blocking,
            conversationId: conversationId,
            user: user
        )
        return try await networkService.request(
            endpoint: DifyAPIEndpoint.chatMessages,
            method: .post,
            body: requestBody
        )
    }
    
    // MARK: - Completion Messages (Streaming)

    /// Sends a request to the Dify API to get a completion message via a stream (Server-Sent Events).
    /// - Parameters:
    ///   - inputs: A dictionary of input variables for the Dify application (e.g., `["prompt": "Your prompt here"]`).
    ///   - user: A unique identifier for the end-user making the request.
    /// - Returns: An `AsyncThrowingStream<StreamedCompletionData, Error>` that yields `StreamedCompletionData` chunks as they arrive.
    ///            Each chunk typically contains a part of the answer.
    /// - Throws: A `DifyError` if the initial stream setup fails.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func streamCompletionMessage(
        inputs: [String: String],
        user: String
    ) -> AsyncThrowingStream<StreamedCompletionData, Error> {
        let requestBody = CompletionRequest(inputs: inputs, responseMode: .streaming, user: user)
        return networkService.requestStream(
            endpoint: DifyAPIEndpoint.completionMessages,
            method: .post,
            body: requestBody,
            eventDataType: StreamedCompletionData.self
        )
    }

    // MARK: - Chat Messages (Streaming)

    /// Sends a chat message to the Dify API via a stream (Server-Sent Events).
    /// - Parameters:
    ///   - query: The user's query or message.
    ///   - user: A unique identifier for the end-user making the request.
    ///   - inputs: Optional. A dictionary of input variables for the Dify application. Ignored if `conversationId` is for an existing conversation.
    ///   - conversationId: Optional. The ID of an existing conversation to continue. If `nil`, a new conversation is started.
    /// - Returns: An `AsyncThrowingStream<StreamedChatData, Error>` that yields `StreamedChatData` chunks as they arrive.
    ///            Each chunk typically contains a part of the reply and the conversation ID.
    /// - Throws: A `DifyError` if the initial stream setup fails.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func streamChatMessage(
        query: String,
        user: String,
        inputs: [String: String]? = nil,
        conversationId: String? = nil
    ) -> AsyncThrowingStream<StreamedChatData, Error> {
        let requestBody = ChatMessageRequest(
            inputs: inputs,
            query: query,
            responseMode: .streaming,
            conversationId: conversationId,
            user: user
        )
        return networkService.requestStream(
            endpoint: DifyAPIEndpoint.chatMessages,
            method: .post,
            body: requestBody,
            eventDataType: StreamedChatData.self
        )
    }

    // MARK: - Cancellation
    
    /// Attempts to cancel all active streaming tasks that were initiated by this `DifyClient` instance.
    /// For non-streaming requests, cancellation should be handled by cancelling the `Task` that is awaiting the `async` method.
    /// For individual streaming requests, cancellation is best handled by cancelling the `Task` that is consuming the `AsyncThrowingStream`.
    /// This method provides a more general way to attempt to stop all ongoing streams from this client.
    public func cancelAllStreams() {
        networkService.cancelAllStreamingTasks()
    }
}

