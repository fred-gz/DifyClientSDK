# DifyClientSDK for Swift

`DifyClientSDK` is a Swift package that provides a convenient way to interact with the Dify API. It supports both non-streaming (blocking) and streaming (Server-Sent Events) API calls for Dify's text completion and chat functionalities. The SDK is built with Swift Concurrency (`async/await`) for modern asynchronous programming.

## Features

-   Easy-to-use client for Dify API v1.
-   Support for Text Completion (`/completion-messages`) and Chat (`/chat-messages`) endpoints.
-   Non-streaming (blocking) API calls.
-   Streaming API calls using Server-Sent Events (SSE) and `AsyncThrowingStream`.
-   Built-in request cancellation support through Swift Concurrency Task cancellation.
-   Clear error handling with a dedicated `DifyError` type.
-   Type-safe request and response models using Swift's `Codable` protocol.

## Requirements

-   iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / tvOS 13.0+
-   Swift 5.7+
-   A Dify API Key.

## Installation

`DifyClientSDK` can be added to your project using Swift Package Manager.

1.  In Xcode, select **File > Add Packages...**
2.  Enter the repository URL for this SDK (once it's hosted, e.g., `https://github.com/your-repo/DifyClientSDK.git`).
3.  Choose the version or branch you want to use.
4.  Add `DifyClientSDK` to your target.

Alternatively, you can add it to your `Package.swift` dependencies:

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://your-repo/DifyClientSDK.git", from: "1.0.0") // Replace with actual URL and version
],
targets: [
    .target(
        name: "YourAppTarget",
        dependencies: ["DifyClientSDK"]),
]
```

## Usage

### 1. Initialization

First, import `DifyClientSDK` and initialize the `DifyClient` with your API key. You can also provide a custom base URL if you are using a self-hosted Dify instance.

```swift
import DifyClientSDK

let apiKey = "YOUR_DIFY_API_KEY"
let client = DifyClient(apiKey: apiKey)

// For a self-hosted Dify instance:
// let customBaseURL = URL(string: "https://your-dify-instance.com/v1")!
// let client = DifyClient(apiKey: apiKey, baseURL: customBaseURL)
```

### 2. Making API Calls

All API methods are asynchronous and should be called using `async/await`.

#### Non-Streaming (Blocking) Requests

These methods wait for the full response from the API before returning.

**Text Completion (`getCompletionMessage`)**

```swift
func fetchCompletion() async {
    do {
        let response = try await client.getCompletionMessage(
            inputs: ["prompt": "Write a short poem about Swift programming."], // `inputs` depends on your Dify app config
            user: "example-user-001" // A unique identifier for your end-user
        )
        print("Generated Text: \(response.message.answer)")
        if let usage = response.metadata?.usage {
            print("Total Tokens: \(usage.totalTokens)")
        }
    } catch let error as DifyError {
        print("Dify API Error: \(error.localizedDescription)")
    } catch {
        print("An unexpected error occurred: \(error.localizedDescription)")
    }
}
```

**Chat Message (`sendChatMessage`)**

```swift
func performChat() async {
    var conversationId: String? = nil // Store this to continue the conversation

    do {
        // First message (starts a new conversation)
        let response1 = try await client.sendChatMessage(
            query: "Hello, what can you do?",
            user: "example-user-002",
            conversationId: conversationId // nil for new conversation
        )
        print("Dify: \(response1.answer)")
        conversationId = response1.conversationId // Save for the next message

        // Subsequent message (continues the conversation)
        if let currentConversationId = conversationId {
            let response2 = try await client.sendChatMessage(
                query: "Tell me more about Dify.",
                user: "example-user-002",
                conversationId: currentConversationId
            )
            print("Dify: \(response2.answer)")
        }
    } catch {
        print("Chat Error: \(error.localizedDescription)")
    }
}
```

#### Streaming Requests

These methods return an `AsyncThrowingStream` that yields data chunks (SSE events) as they are received from the API.

**Stream Text Completion (`streamCompletionMessage`)**

```swift
func streamCompletion() async {
    let streamTask = Task {
        do {
            let stream = client.streamCompletionMessage(
                inputs: ["prompt": "Explain quantum computing in simple terms."],
                user: "example-user-003"
            )
            print("Streaming Completion:")
            for try await chunkData in stream {
                print(chunkData.answer, terminator: "") // `answer` contains a part of the response
            }
            print("\nStream finished.")
        } catch DifyError.requestCancelled {
            print("Stream was cancelled.")
        } catch {
            print("Streaming Error: \(error.localizedDescription)")
        }
    }

    // To cancel the stream (e.g., after a timeout or user action):
    // streamTask.cancel()
}
```

**Stream Chat Message (`streamChatMessage`)**

```swift
func streamChat() async {
    var conversationId: String? = nil
    print("Starting a streaming chat...")

    let chatStreamTask = Task {
        do {
            let stream = client.streamChatMessage(
                query: "What are the main features of Swift?",
                user: "example-user-004",
                conversationId: conversationId // nil for new conversation
            )
            
            var fullResponse = ""
            print("Dify (streaming): ", terminator: "")
            for try await chunkData in stream {
                print(chunkData.answer, terminator: "")
                fullResponse += chunkData.answer
                if conversationId == nil {
                    conversationId = chunkData.conversationId // Capture conversationId from the first chunk
                }
            }
            print("\nStream finished. Full response: \(fullResponse)")
            print("Conversation ID: \(conversationId ?? "N/A")")
        } catch DifyError.requestCancelled {
            print("Chat stream was cancelled.")
        } catch {
            print("Chat Streaming Error: \(error.localizedDescription)")
        }
    }
    // To cancel the stream:
    // chatStreamTask.cancel()
}
```

### 3. Error Handling

The SDK throws `DifyError` for various issues. You can catch this specific error type to handle API-related problems gracefully.

```swift
public enum DifyError: Error, LocalizedError, Equatable {
    case invalidURL
    case networkError(Error)
    case apiError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case unknownError
    case requestCancelled
    case streamParsingError(String)
    case missingAPIKey
    // ... (see DifyError.swift for details)
}
```

### 4. Cancellation

-   **Non-Streaming Requests:** To cancel a non-streaming request, cancel the Swift Concurrency `Task` that is `await`ing the method call.
    ```swift
    let nonStreamingTask = Task {
        // ... await client.getCompletionMessage(...)
    }
    // Sometime later:
    nonStreamingTask.cancel()
    ```

-   **Streaming Requests:** To cancel a streaming request, cancel the Swift Concurrency `Task` that is iterating over the `AsyncThrowingStream` (`for try await ...`). This will trigger the stream's termination handler, which cancels the underlying network request.
    ```swift
    let streamingTask = Task {
        // ... for try await chunk in client.streamChatMessage(...)
    }
    // Sometime later:
    streamingTask.cancel()
    ```
-   **Global Stream Cancellation:** You can also attempt to cancel all active streaming tasks initiated by a specific `DifyClient` instance by calling `client.cancelAllStreams()`. However, cancelling individual tasks is generally the preferred and more precise method.

## SDK Structure

The SDK is organized into the following main components:

-   `DifyClient.swift`: The main public interface for interacting with the API.
-   `NetworkService.swift`: Handles the underlying network requests and SSE stream management.
-   `StreamProcessor.swift`: Parses Server-Sent Events from the data stream.
-   `APIEndpoints.swift`: Defines the Dify API endpoints.
-   `DifyError.swift`: Defines custom error types for the SDK.
-   `Models/`: Contains all `Codable` request and response data structures.
    -   `CommonModels.swift`
    -   `CompletionModels.swift`
    -   `ChatModels.swift`
    -   `StreamedEventModels.swift`

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

This SDK is released under the [MIT License](LICENSE.txt). (You would add a LICENSE.txt file).

