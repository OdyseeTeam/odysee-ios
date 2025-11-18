//
//  LbryUriTest.swift
//  OdyseeTests
//
//  Created by Keith Toh on 29/10/2025.
//

import Testing

@testable import Odysee

// NOTE: primary/secondary should be implementation only
// But they're not used in the app at all, so no need to change
struct Expected {
    var path: String?
    var isChannel: Bool = false
    var streamName: String = ""
    var streamClaimId: String?
    var channelName: String?
    var channelClaimId: String?
    var primaryClaimSequence: Int = -1
    var secondaryClaimSequence: Int = -1
    var primaryBidPosition: Int = -1
    var secondaryBidPosition: Int = -1

    var claimName: String?
    var claimId: String?
    var contentName: String?
    var queryString: String?
}

let claimId = "ffffffffffffffffffffffffffffffffffffffff"

struct LbryUriTest {
    // TODO: Test fail cases
    // Not needed for now (2025-11-18), just make sure the unicode crash doesn't occur
    @Test(
        "lbry-sdk test_url.py success cases",
        arguments: [
            // Swift Testing doesn't support 3 parameterized arguments
            "",
            "lbry://",
            "https://",
            "open.lbry.com/",
            "odysee.com/",
            "lbry.tv/",
            "lbry://open.lbry.com/",
            "lbry://odysee.com/",
            "lbry://lbry.tv/",
            "https://open.lbry.com/",
            "https://odysee.com/",
            "https://lbry.tv/",
        ],
        [
            // stream
            ("test", Expected(streamName: "test")),
            (
                "test:\(claimId)",
                Expected(streamName: "test", streamClaimId: claimId)
            ),
            // --- legacy
            ("test*1", Expected(streamName: "test*1")),
            ("test$1", Expected(streamName: "test", primaryBidPosition: 1)),
            (
                "test#\(claimId)",
                Expected(streamName: "test", streamClaimId: claimId)
            ),
            // channel
            ("@test", Expected(channelName: "test")),
            (
                "@test:\(claimId)",
                Expected(channelName: "test", channelClaimId: claimId)
            ),
            // --- legacy
            ("@test$1", Expected(channelName: "test", primaryBidPosition: 1)),
            (
                "@test#\(claimId)",
                Expected(channelName: "test", channelClaimId: claimId)
            ),
            // channel/stream
            (
                "@test/stuff",
                Expected(streamName: "stuff", channelName: "test")
            ),
            (
                "@test:\(claimId)/stuff",
                Expected(
                    streamName: "stuff",
                    channelName: "test",
                    channelClaimId: claimId
                )
            ),
            (
                "@test/stuff:\(claimId)",
                Expected(
                    streamName: "stuff",
                    streamClaimId: claimId,
                    channelName: "test"
                )
            ),
            (
                "@test:\(claimId)/stuff:\(claimId)",
                Expected(
                    streamName: "stuff",
                    streamClaimId: claimId,
                    channelName: "test",
                    channelClaimId: claimId
                )
            ),
            // --- legacy
            (
                "@test$1/stuff",
                Expected(
                    streamName: "stuff",
                    channelName: "test",
                    primaryBidPosition: 1
                )
            ),
            (
                "@test#\(claimId)/stuff",
                Expected(
                    streamName: "stuff",
                    channelName: "test",
                    channelClaimId: claimId
                )
            ),
            // combined legacy and new
            (
                "@test:1/stuff#2",
                Expected(
                    streamName: "stuff",
                    streamClaimId: "2",
                    channelName: "test",
                    channelClaimId: "1"
                )
            ),
            // unicode regex edges
            ("\u{D799}", Expected(streamName: "\u{D799}")),
            ("\u{E000}", Expected(streamName: "\u{E000}")),
            ("\u{FFFD}", Expected(streamName: "\u{FFFD}")),
            // regex range split between unicode graphemes
            (
                "@RandomTypek:e/்:3",
                Expected(
                    streamName: "்",
                    streamClaimId: "3",
                    channelName: "RandomTypek",
                    channelClaimId: "e"
                )
            ),
        ]
    )
    func uriParsing(prefix: String, testCase: (String, Expected)) async throws {
        let url = prefix + testCase.0
        let uri = try! LbryUri.parse(url: url, requireProto: false)

        #expect(uri.streamName == testCase.1.streamName)
        #expect(uri.streamClaimId == testCase.1.streamClaimId)
        #expect(uri.channelName == testCase.1.channelName)
        #expect(uri.channelClaimId == testCase.1.channelClaimId)
    }

    // TEST: requireProto
    // TEST: stringify
}
