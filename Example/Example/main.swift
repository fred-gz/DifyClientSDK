//
//  main.swift
//  Example
//
//  Created by fred on 2025/5/14.
//

import Foundation
import DifyClientSDK

// 初始化DifyClient
let apiKey = "" // 替换为你的API Key
let client = DifyClient(apiKey: apiKey)

// 测试完成消息功能
Task {
    do {
//        // 1. 测试非流式完成消息
//        print("\n=== 测试非流式完成消息 ===")
//        let completionResponse = try await client.getCompletionMessage(
//            inputs: ["prompt": "写一个关于机器人的短故事。"],
//            user: "test-user-1"
//        )
//        print("回答: \(completionResponse.message.answer)")
//        
//        // 2. 测试流式完成消息
//        print("\n=== 测试流式完成消息 ===")
//        let stream = client.streamCompletionMessage(
//            inputs: ["prompt": "讲个笑话。"],
//            user: "test-user-2"
//        )
//        print("流式回答: ", terminator: "")
//        for try await chunk in stream {
//            print(chunk.answer, terminator: "")
//        }
//        print("\n")
        
//        // 3. 测试非流式聊天消息
//        print("\n=== 测试非流式聊天消息 ===")
//        let chatResponse = try await client.sendChatMessage(
//            query: "Swift编程语言是什么？",
//            user: "test-user-3",
//            inputs: [:]
//        )
//        print("对话ID: \(chatResponse.conversationId)")
//        print("回答: \(chatResponse.answer)")
        
        // 4. 测试流式聊天消息
        print("\n=== 测试流式聊天消息 ===")
        let chatStream = client.streamChatMessage(
            query: "告诉我更多关于Swift的特性。",
            user: "test-user-4",
            inputs: [:]
        )
        print("流式回答: ", terminator: "")
        for try await chunk in chatStream {
            if let answer = chunk.answer {
                print(answer, terminator: "\n")
            } else {
                print("nil", terminator: "\n")
            }
        }
        print("\n")
        
    } catch {
        print("错误: \(error.localizedDescription)")
    }
}

// 保持程序运行，等待异步任务完成
RunLoop.main.run(until: Date(timeIntervalSinceNow: 300))

