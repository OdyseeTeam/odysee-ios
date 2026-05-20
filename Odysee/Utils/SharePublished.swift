//
//  SharePublished.swift
//  Odysee
//
//  Created by Keith Toh on 20/05/2026.
//

import AsyncExtensions
import Foundation

/// Like `Published` but can be accessed from multiple client loops
@propertyWrapper
public struct SharePublished<T> where T: Equatable {
    private var value: T

    private var share: AsyncShareSequence<AsyncBufferedChannel<T>>
    private let queue = AsyncBufferedChannel<T>()

    public var wrappedValue: T {
        get {
            value
        }
        set {
            if value != newValue {
                queue.send(newValue)
                value = newValue
            }
        }
    }

    public var projectedValue: AsyncShareSequence<AsyncBufferedChannel<T>> {
        share
    }

    public init(wrappedValue: T) {
        value = wrappedValue
        share = queue.share()
    }
}
