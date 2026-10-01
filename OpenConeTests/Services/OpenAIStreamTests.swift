import XCTest
@testable import OpenCone

/// The streamed answer's text, from a stand-in for OpenAI's Responses stream. Event shapes follow
/// OpenAI's Responses streaming events reference (read 2026-10-01): `response.output_text.delta`
/// carries each piece, and `response.output_item.done` repeats the finished message in full.
@MainActor
final class OpenAIStreamTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        URLProtocol.unregisterClass(MockURLProtocol.self)
        super.tearDown()
    }

    private func stream(_ events: [(String, [String: Any])]) -> Data {
        events.map { event, payload in
            let json = String(data: try! JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
            return "event: \(event)\ndata: \(json)\n\n"
        }
        .joined()
        .data(using: .utf8)!
    }

    private func streamedText(for events: [(String, [String: Any])]) async throws -> String {
        let body = stream(events)
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/event-stream"])!
            return (response, body)
        }
        var text = ""
        try await OpenAIService(apiKey: "test").streamCompletion(
            systemPrompt: "Answer.",
            userMessage: "Question",
            context: "Context",
            onTextDelta: { text += $0 },
            allowCodeInterpreter: false,
            onCompleted: {}
        )
        return text
    }

    private func doneEvent(id: String, text: String) -> (String, [String: Any]) {
        ("response.output_item.done", [
            "type": "response.output_item.done",
            "output_index": 0,
            "item": [
                "id": id,
                "type": "message",
                "role": "assistant",
                "status": "completed",
                "content": [["type": "output_text", "text": text, "annotations": []]],
            ],
        ])
    }

    func testAStreamedAnswerIsNotRepeatedByItsDoneEvent() async throws {
        let text = try await streamedText(for: [
            ("response.output_text.delta", ["type": "response.output_text.delta", "item_id": "msg_1", "delta": "Filters last "]),
            ("response.output_text.delta", ["type": "response.output_text.delta", "item_id": "msg_1", "delta": "96 hours [S1]."]),
            doneEvent(id: "msg_1", text: "Filters last 96 hours [S1]."),
            ("response.completed", ["type": "response.completed", "response": ["id": "resp_1", "status": "completed"]]),
        ])

        XCTAssertEqual(text, "Filters last 96 hours [S1].")
    }

    func testAMessageThatStreamedNoTextUsesItsDoneText() async throws {
        let text = try await streamedText(for: [
            doneEvent(id: "msg_2", text: "Only in the done event."),
            ("response.completed", ["type": "response.completed", "response": ["id": "resp_2", "status": "completed"]]),
        ])

        XCTAssertEqual(text, "Only in the done event.")
    }
}
