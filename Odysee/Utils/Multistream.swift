//
//  Multistream.swift
//  Odysee
//
//  Created by Adlai on 5/21/21.
//

import Foundation

private let kBufferSize = 1024 * 1024

class Multistream: InputStream, StreamDelegate {
    private let streams: [InputStream]
    private var nextInputIndex = 0
    private var currentInputIndex: Int?
    private var input: InputStream
    private var output: OutputStream
    private var buffer = Data(count: kBufferSize)
    private var bufferLength = 0
    var error: Error?

    // MARK: - Pass-through to underlying bound stream

    override var streamStatus: Stream.Status {
        return input.streamStatus
    }

    override func open() {
        input.open()
        output.open()
    }

    override func close() {
        input.close()
    }

    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        input.setProperty(property, forKey: key)
    }

    override func property(forKey key: Stream.PropertyKey) -> Any? {
        return input.property(forKey: key)
    }

    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        input.schedule(in: aRunLoop, forMode: mode)
        output.schedule(in: aRunLoop, forMode: mode)
    }

    override var delegate: StreamDelegate? {
        get {
            return input.delegate
        }
        set {
            input.delegate = newValue
        }
    }

    override var hasBytesAvailable: Bool {
        return input.hasBytesAvailable
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        assert(input.streamStatus == .open)
        return input.read(buffer, maxLength: len)
    }

    override func getBuffer(
        _ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        length len: UnsafeMutablePointer<Int>
    ) -> Bool {
        return input.getBuffer(buffer, length: len)
    }

    // Streams should be open before this.
    // Don't mess with the streams otherwise.
    init(streams: [InputStream]) {
        self.streams = streams
        assert(!streams.contains { $0.streamStatus != .open })
        var read: Unmanaged<CFReadStream>?
        var write: Unmanaged<CFWriteStream>?
        CFStreamCreateBoundPair(nil, &read, &write, kBufferSize)
        input = read!.takeRetainedValue()
        output = write!.takeRetainedValue()
        super.init(data: Data())
        output.delegate = self
    }

    private func openNextInput() -> Bool {
        if let currentIndex = currentInputIndex {
            streams[currentIndex].close()
            currentInputIndex = nil
        }

        if nextInputIndex < streams.count {
            // Don't actually need to open the stream. It's already open.
            currentInputIndex = nextInputIndex
            nextInputIndex += 1
            return true
        }
        return false
    }

    @discardableResult private func refillBuffer() -> Bool {
        let bytesRead: Int = buffer.withUnsafeMutableBytes { ptr in
            let y = ptr.bindMemory(to: UInt8.self).baseAddress!
            return internalRead(y + bufferLength, maxLength: kBufferSize - bufferLength)
        }
        if bytesRead <= 0 {
            return false
        }
        bufferLength += bytesRead
        return true
    }

    private func writeToOutput() -> Bool {
        assert(bufferLength > 0)
        let bytesWritten: Int = buffer.withUnsafeBytes {
            let ptr = $0.bindMemory(to: UInt8.self).baseAddress!
            return output.write(ptr, maxLength: bufferLength)
        }
        if bytesWritten <= 0 {
            error = output.streamError
            return false
        }
        assert(bytesWritten <= bufferLength)
        bufferLength -= bytesWritten
        // Shift unwritten data to the beginning of buffer
        buffer.withUnsafeMutableBytes {
            let ptr = $0.baseAddress!
            memmove(ptr, ptr + bytesWritten, bufferLength)
        }
        if bufferLength <= kBufferSize / 2 {
            refillBuffer()
        }
        return bufferLength > 0
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        assert(aStream == output)
        switch eventCode {
        case .openCompleted:
            if openNextInput() {
                refillBuffer()
            }
        case .hasSpaceAvailable:
            if let idx = currentInputIndex, streams[idx].streamStatus.rawValue < Stream.Status.open.rawValue {
                // If we are still waiting for one of our input streams to open, just retry again
                // later. This doesn't happen in practice with data-streams or file-streams.
                RunLoop.current.schedule(after: RunLoop.SchedulerTimeType(Date().addingTimeInterval(0.1))) {
                    self.stream(aStream, handle: .hasSpaceAvailable)
                }
            } else if !writeToOutput() {
                output.close()
                if let idx = currentInputIndex {
                    streams[idx].close()
                    currentInputIndex = nil
                    nextInputIndex = streams.count
                }
            }
        default: ()
        }
    }

    private func internalRead(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        var buf = buffer
        var l = len
        var totalBytesRead = 0
        while let inputIndex = currentInputIndex, l > 0 {
            let currentInput = streams[inputIndex]
            switch currentInput.read(buf, maxLength: l) {
            case let bytesRead where bytesRead > 0:
                totalBytesRead += bytesRead
                buf += bytesRead
                l -= bytesRead
            case 0:
                if !openNextInput() {
                    break
                }
            default:
                error = currentInput.streamError
                return -1
            }
        }
        return totalBytesRead
    }
}
