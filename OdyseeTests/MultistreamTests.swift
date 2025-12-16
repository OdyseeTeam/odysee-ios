//
//  MultistreamTests.swift
//  OdyseeTests
//
//  Created by Adlai on 5/21/21.
//

@testable import Odysee
import XCTest

class MultistreamTests: XCTestCase, StreamDelegate {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    var streamOpenExpectation: XCTestExpectation?
    var streamEndExpectation: XCTestExpectation?
    var streamData = Data()

    @objc func testBasic() {
        let str1 = "Hello, world: "
        let stream1 = InputStream(data: str1.data)
        stream1.open()

        let str2 = "my name is Odysee! "
        let stream2 = InputStream(data: str2.data)
        stream2.open()

        let fm = FileManager.default
        let filePath = fm.temporaryDirectory.appendingPathComponent("ms_test.dat").path
        if !fm.fileExists(atPath: filePath) {
            let str3 = "This is file data."
            fm.createFile(atPath: filePath, contents: str3.data, attributes: nil)
        }
        let stream3 = InputStream(fileAtPath: filePath)!
        stream3.open()

        let ms = Multistream(streams: [stream1, stream2, stream3])
        ms.schedule(in: RunLoop.current, forMode: .default)
        ms.delegate = self

        streamOpenExpectation = expectation(description: "stream is open")
        streamEndExpectation = expectation(description: "stream ended")
        ms.open()
        waitForExpectations(timeout: 10, handler: nil)

        XCTAssertEqual("Hello, world: my name is Odysee! This is file data.", String(data: streamData, encoding: .utf8))
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        let iStream = aStream as! InputStream
        switch eventCode {
        case .openCompleted:
            streamOpenExpectation!.fulfill()
        case .hasBytesAvailable:
            do {
                try streamData.append(iStream.swiftRead(limit: 10))
            } catch let e {
                XCTFail("read error: \(e)")
            }
        case .endEncountered:
            streamEndExpectation!.fulfill()
        default: ()
        }
    }
}

enum StreamError: Error {
    case Error(error: Error?, partialData: [UInt8])
}

extension InputStream {
    func swiftRead(limit: Int) throws -> Data {
        var chunk = Data(count: limit)
        let count: Int = try chunk.withUnsafeMutableBytes {
            let ptr = $0.bindMemory(to: UInt8.self).baseAddress!
            let bytesRead = self.read(ptr, maxLength: limit)
            if bytesRead < 0 {
                throw self.streamError!
            }
            return bytesRead
        }
        return chunk.prefix(count)
    }
}
