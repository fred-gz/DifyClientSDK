import Foundation

/// `StreamProcessor` is an `NSObject` subclass conforming to `URLSessionDataDelegate`.
/// It is responsible for processing Server-Sent Events (SSE) from a Dify API stream.
/// It decodes incoming data chunks into a specified `Decodable` type `T` and yields them through an `AsyncThrowingStream`.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
class StreamProcessor<T: Decodable>: NSObject, URLSessionDataDelegate {
    /// The continuation for the `AsyncThrowingStream` that yields decoded data or throws errors.
    private var continuation: AsyncThrowingStream<T, Error>.Continuation?
    /// A buffer to accumulate incoming data chunks from `URLSessionDataDelegate` methods.
    private var buffer = Data()
    /// The `URLSessionDataTask` associated with this stream. Used for cancellation.
    private var task: URLSessionDataTask?

    /// A `JSONDecoder` instance for decoding the `data:` field of SSE events.
    private let decoder = JSONDecoder()
    /// The `Decodable` type that the `data:` field of SSE events is expected to conform to.
    private let eventDataType: T.Type

    /// Initializes a new `StreamProcessor`.
    /// - Parameters:
    ///   - eventDataType: The `Decodable` type to which incoming SSE data events will be decoded.
    ///   - continuation: The `AsyncThrowingStream.Continuation` to yield decoded objects or finish with an error.
    init(eventDataType: T.Type, continuation: AsyncThrowingStream<T, Error>.Continuation) {
        self.eventDataType = eventDataType
        self.continuation = continuation
    }

    /// Assigns the `URLSessionDataTask` to this processor.
    /// This is typically called by the `NetworkService` immediately after the task is created.
    /// Allows the processor to cancel the task if needed (e.g., on a fatal parsing error).
    /// - Parameter task: The `URLSessionDataTask` handling the streaming connection.
    public func setTask(_ task: URLSessionDataTask) {
        self.task = task
    }

    // MARK: - URLSessionDataDelegate Methods

    /// Called when the data task receives a portion of the response data.
    /// Appends the received data to an internal buffer and attempts to process it.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        processBuffer()
    }

    /// Called when the data task completes, either successfully or with an error.
    /// Finishes the `AsyncThrowingStream`'s continuation appropriately.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                continuation?.finish(throwing: DifyError.requestCancelled)
            } else {
                continuation?.finish(throwing: DifyError.networkError(error))
            }
        } else {
            // Process any remaining data in the buffer before finishing successfully.
            processBuffer(isStreamEnd: true)
            continuation?.finish()
        }
        continuation = nil // Prevent further use of the continuation.
    }

    // MARK: - Private Processing Logic

    /// Processes the internal data buffer, attempting to parse complete SSE events.
    /// This method is called incrementally as data is received and once more when the stream ends.
    /// - Parameter isStreamEnd: A boolean indicating if this is the final call after the stream has ended.
    private func processBuffer(isStreamEnd: Bool = false) {
        // Loop as long as complete SSE events can be parsed from the buffer.
        while let (event, range) = parseNextSSEEvent(from: buffer) {
            buffer.removeSubrange(range) // Remove the processed event from the buffer.
            
            // Handle the parsed SSE event based on its type (e.g., message, error, message_end).
            switch event.type {
            case .message, .agentMessage: // Treat `agent_message` similarly to `message` for data parsing.
                if let jsonData = event.data.data(using: .utf8) {
                    do {
                        let decodedObject = try decoder.decode(T.self, from: jsonData)
                        continuation?.yield(decodedObject) // Yield the decoded object to the stream.
                    } catch {
                        // If decoding fails, finish the stream with a parsing error and cancel the task.
                        continuation?.finish(throwing: DifyError.streamParsingError("Failed to decode data: \(error.localizedDescription), data: \(event.data)"))
                        self.task?.cancel()
                        return
                    }
                }
            case .messageEnd:
                // The `message_end` event often signals the successful completion of the stream for a given message ID.
                // It might contain metadata, but the current generic StreamProcessor yields `T`.
                // If `T` is an enum like `StreamEvent<DataType>`, then `.end(metadata)` could be yielded here.
                // For now, `message_end` is primarily a signal; the stream finishes via `didCompleteWithError`.
                // If specific metadata from `message_end` needs to be captured, `T` or the stream's element type should be adjusted.
                break 
            case .error:
                // If an `error` event is received from the stream.
                if let jsonData = event.data.data(using: .utf8) {
                    do {
                        let errorDetail = try decoder.decode(StreamErrorDetail.self, from: jsonData)
                        continuation?.finish(throwing: DifyError.apiError(statusCode: errorDetail.code ?? 500, message: errorDetail.message ?? "Stream error"))
                    } catch {
                        continuation?.finish(throwing: DifyError.streamParsingError("Failed to decode stream error event: \(error.localizedDescription), data: \(event.data)"))
                    }
                } else {
                     continuation?.finish(throwing: DifyError.streamParsingError("Received error event with no data."))
                }
                self.task?.cancel() // Cancel the task upon receiving an error event.
                return
            case .ping:
                // `ping` events are typically keep-alive signals and are ignored.
                break
            // default: // Handle unknown event types if necessary, or ignore them.
            }
        }
        // If it's the end of the stream and there's still unparseable data in the buffer, it might indicate an issue.
        if isStreamEnd && !buffer.isEmpty {
            // Log or handle potentially incomplete data if necessary.
            // print("Stream ended with unprocessed buffer data: \(String(data: buffer, encoding: .utf8) ?? "")")
        }
    }

    /// Parses the next complete Server-Sent Event (SSE) from the provided data.
    /// SSE events are newline-separated and an event ends with a double newline.
    /// - Parameter data: The raw `Data` buffer to parse.
    /// - Returns: A tuple containing the parsed `SSEEvent` and the range it occupied in the input data, or `nil` if no complete event is found.
    private func parseNextSSEEvent(from data: Data) -> (event: SSEEvent, range: Range<Data.Index>)? {
        guard let stringData = String(data: data, encoding: .utf8) else { return nil }
        
        var eventType: DifyStreamEventType? = nil
        var eventData = "" // Accumulates data from `data:` lines.
        var eventId: String? = nil
        // var retry: Int? = nil // Dify API examples do not typically use the 'retry:' field.

        var consumedLength = 0 // Tracks the number of bytes consumed from the original `Data` buffer.
        var currentPosition = stringData.startIndex
        let endIndex = stringData.endIndex

        while currentPosition < endIndex {
            // Find the end of the current line.
            guard let newlineIndex = stringData[currentPosition...].firstIndex(of: "\n") else {
                // No complete line found, need more data.
                return nil
            }
            let line = String(stringData[currentPosition...newlineIndex].dropLast()) // Extract line, remove trailing \n.
            
            consumedLength += line.utf8.count + 1 // Add line length + newline character to consumed length.
            currentPosition = stringData.index(after: newlineIndex) // Move to the start of the next line.

            if line.isEmpty { // An empty line signifies the end of an SSE event.
                if eventType != nil || !eventData.isEmpty { // Ensure some data was parsed for this event.
                    // Dify specific: if event type is not explicitly set, but data exists, assume it's a 'message' event.
                    let finalEventType = eventType ?? (eventData.isEmpty ? nil : .message)
                    
                    if let finalEventType = finalEventType {
                         return (SSEEvent(type: finalEventType, data: eventData.trimmingCharacters(in: .newlines), id: eventId), data.startIndex..<data.startIndex.advanced(by: consumedLength))
                    }
                }
                // Reset for the next potential event, though this function returns after one complete event.
                eventType = nil
                eventData = ""
                eventId = nil
            }

            // Parse field type based on prefix.
            if line.starts(with: "event:") {
                let value = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
                eventType = DifyStreamEventType(rawValue: value)
            } else if line.starts(with: "data:") {
                // SSE spec: `data:` field can span multiple lines. Append with newline for multi-line data.
                let value = line.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines) // Trim leading/trailing whitespace from data line content.
                eventData.append(value + "\n") // Append data line; multiple data lines are concatenated with newlines.
            } else if line.starts(with: "id:") {
                eventId = line.dropFirst("id:".count).trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: ":") {
                // This is a comment line according to SSE spec; ignore it.
            }
            // The 'retry:' field is not handled as Dify examples don't typically show its use.
        }
        return nil // No complete event found in the current buffer.
    }

    /// A helper struct to represent a parsed SSE event before its `data` field is decoded into the target type `T`.
    struct SSEEvent {
        let type: DifyStreamEventType?
        let data: String
        let id: String?
    }
    
    /// Cancels the underlying `URLSessionDataTask` associated with this stream processor.
    /// This will trigger the `urlSession(_:task:didCompleteWithError:)` delegate method with a cancellation error.
    public func cancel() {
        task?.cancel()
    }
}

