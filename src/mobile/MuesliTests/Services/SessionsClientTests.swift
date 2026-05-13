//
//  SessionsClientTests.swift
//  MuesliTests
//
//  Pure unit tests covering JSON encode/decode for SessionsService DTOs.
//  No network calls — verifies that the Swift types match the backend JSON contract.
//

import XCTest
@testable import Muesli

final class SessionsClientTests: XCTestCase {
    func testDecodesBlendResponse() throws {
        let json = #"""
            {
            "blendedMarkdown": "Hello.",
            "userNoteSpans": [{ "start": 0, "end": 6 }],
            "quoteSpans": [{ "start": 0, "end": 5, "transcriptStart": 1.0, "transcriptEnd": 2.0, "speaker": "Sarah" }],
            "imagePlacements": [{ "imageId": "p1", "charOffset": 6 }],
            "citations": [{ "blendStart": 0, "blendEnd": 6, "transcriptStart": 0.0, "transcriptEnd": 1.5 }],
            "chapters": [{ "start": 0, "title": "Opening", "summary": "intro" }],
            "costMicros": 12345
            }
        """#.data(using: .utf8)!

        let resp = try JSONDecoder().decode(BlendResponse.self, from: json)
        XCTAssertEqual(resp.blendedMarkdown, "Hello.")
        XCTAssertEqual(resp.userNoteSpans.count, 1)
        XCTAssertEqual(resp.quoteSpans.first?.speaker, "Sarah")
        XCTAssertEqual(resp.chapters.count, 1)
        XCTAssertEqual(resp.costMicros, 12_345)
    }

    func testEncodesBlendRequest() throws {
        let req = BlendRequest(userNotes: "eval as ENG")
        let data = try JSONEncoder().encode(req)
        let s = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(s.contains("\"userNotes\""))
        XCTAssertTrue(s.contains("eval as ENG"))
    }
}
