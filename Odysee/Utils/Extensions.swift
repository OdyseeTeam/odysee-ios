//
//  Extensions.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/11/2020.
//

import Combine
import FirebaseCrashlytics
import Foundation
import OrderedCollections
import PINRemoteImage
import SwiftUI
import UIKit

extension String {
    var isBlank: Bool {
        return !contains { !$0.isWhitespace && !$0.isNewline }
    }

    var data: Data {
        return Data(utf8)
    }

    subscript(bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ... end])
    }

    subscript(bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ..< end])
    }

    public static func localized(_ key: String, comment: String? = nil) -> String {
        return NSLocalizedString(key, comment: comment ?? "")
    }
}

extension Optional where Wrapped == String {
    var isBlank: Bool {
        guard let s = self else { return true }
        return s.isBlank
    }

    var isEmpty: Bool {
        guard let s = self else { return true }
        return s.isEmpty
    }
}

extension UIImageView {
    func load(url: URL) {
        pin_setImage(from: url)
    }

    func rounded() {
        layer.masksToBounds = false
        layer.cornerRadius = frame.height / 2
        clipsToBounds = true
    }
}

extension UIApplication {
    class func currentViewController(
        _ viewController: UIViewController? = UIApplication.shared.windows
            .filter(\.isKeyWindow).first?.rootViewController
    ) -> UIViewController? {
        if let main = viewController as? MainViewController {
            return currentViewController(main.mainNavigationController)
        }
        if let nav = viewController as? UINavigationController {
            return currentViewController(nav.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            if let selected = tab.selectedViewController {
                return currentViewController(selected)
            }
        }
        if let presented = viewController?.presentedViewController {
            return currentViewController(presented)
        }
        return viewController
    }
}

extension URLSession {
    struct DataTaskSuccess {
        var data: Data
        var response: URLResponse
    }

    // A convenience wrapper for dataTask() that gives a Result instead of three optionals.
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Result<DataTaskSuccess, Error>) -> Void
    ) -> URLSessionDataTask {
        return dataTask(with: request) { data, response, error in
            let result = Result<DataTaskSuccess, Error> {
                if let error = error {
                    throw error
                }
                guard let data = data, let response = response else {
                    assertionFailure()
                    throw GenericError("no error but no data and/or no response")
                }
                return DataTaskSuccess(data: data, response: response)
            }
            completionHandler(result)
        }
    }
}

extension Result {
    // If the result contains an error, show it.
    // Must be called from the main thread.
    func showErrorIfPresent() {
        assert(Thread.isMainThread)
        if case let .failure(error) = self {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }
}

// These extensions are useful for Lbry.swift – so that we can support old methods that haven't
// migrated to their own Params type yet and still use dictionaries.
extension NSString: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        try (self as String).encode(to: encoder)
    }
}

extension NSNull: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

extension NSDictionary: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        for (k, v) in self {
            guard let keyString = k as? String else {
                throw EncodingError.invalidValue(k, .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "NSDictionary key"
                ))
            }
            let nestedEncoder = c.superEncoder(forKey: .init(stringValue: keyString))
            guard let encodableValue = v as? Encodable else {
                throw EncodingError.invalidValue(v, .init(
                    codingPath: nestedEncoder.codingPath,
                    debugDescription: "NSDictionary value"
                ))
            }
            try encodableValue.encode(to: nestedEncoder)
        }
    }

    // A dummy CodingKeys that lets you use any string you want.
    private struct CodingKeys: CodingKey {
        var stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
}

extension NSArray: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        for v in self {
            let nestedEncoder = c.superEncoder()
            guard let encodableValue = v as? Encodable else {
                throw EncodingError.invalidValue(v, .init(
                    codingPath: nestedEncoder.codingPath,
                    debugDescription: "NSArray"
                ))
            }
            try encodableValue.encode(to: nestedEncoder)
        }
    }
}

extension NSNumber: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        // NSNumber in swift is weird. You have to use value(of:) to find bools, but you can't use
        // value(of:) to find ints and floats correctly.
        if let b = value(of: Bool.self) {
            try c.encode(b)
        } else if let i = self as? Int {
            try c.encode(i)
        } else if let d = self as? Double {
            try c.encode(d)
        } else {
            throw EncodingError.invalidValue(self, .init(
                codingPath: encoder.codingPath,
                debugDescription: "NSNumber"
            ))
        }
    }
}

extension Thread {
    // Run the closure on the main thread. If this is called on main, run it immediately. Otherwise
    // dispatch async onto the main queue.
    static func performOnMain(_ f: @escaping () -> Void) {
        if isMainThread {
            f()
        } else {
            DispatchQueue.main.async(execute: f)
        }
    }
}

extension Publisher {
    // A convenience function to hook up a completion block that takes a Result to a publisher
    // that is expected to publish only one value, or fail. For example, an API call.
    func subscribeResult(_ f: @escaping (Result<Output, Failure>) -> Void) {
        subscribe(
            Subscribers.Sink(receiveCompletion: {
                if case let .failure(error) = $0 {
                    f(.failure(error))
                }
            }, receiveValue: {
                f(.success($0))
            })
        )
    }

    // A convenience function to hook up a completion block that takes a Result to a publisher
    // that is expected to publish only one value, or fail. For example, an API call.
    func subscribeResultFinally(_ f: @escaping (Result<Output?, Failure>) -> Void) {
        subscribe(
            Subscribers.Sink(receiveCompletion: {
                if case let .failure(error) = $0 {
                    f(.failure(error))
                } else {
                    f(.success(nil))
                }
            }, receiveValue: {
                f(.success($0))
            })
        )
    }
}

extension Collection {
    /// Modified implementation of sorted(like:keyPath:) from SwifterSwift that applies a transform
    ///
    /// SwifterSwift: Sort an array like another array based on a key path. If the other array doesn't contain a certain value, it will be sorted last. If transform throws the element will be sorted last.
    ///
    ///        [MyStruct(x: 4), MyStruct(x: 2), MyStruct(x: 3)].sorted(like: [1, 2, 3], keyPath: \.x, transform: { $0 - 1 })
    ///            -> [MyStruct(x: 1), MyStruct(x: 2), MyStruct(x: 3)]
    ///
    /// - Parameters:
    ///   - otherArray: array containing elements in the desired order.
    ///   - keyPath: keyPath indicating the property that the array should be sorted by
    ///   - transform: function applying a transform on the keyPath property before sorting.
    /// - Returns: sorted array.
    func sorted<T: Hashable>(
        like otherArray: [T],
        keyPath: KeyPath<Element, T>,
        transform: (T) throws -> T
    ) -> [Element] {
        let dict = otherArray.enumerated().reduce(into: [:]) { $0[$1.element] = $1.offset }
        return sorted {
            guard let thisElem = try? transform($0[keyPath: keyPath]) else { return false }
            guard let otherElem = try? transform($1[keyPath: keyPath]) else { return true }
            guard let thisIndex = dict[thisElem] else { return false }
            guard let otherIndex = dict[otherElem] else { return true }
            return thisIndex < otherIndex
        }
    }
}

extension Crashlytics {
    func recordImmediate(error: any Error, userInfo: [String: Any]? = nil) {
        record(error: error, userInfo: userInfo)
        sendUnsentReports()
    }
}

// https://stackoverflow.com/a/77735876
extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

// swift-format-ignore
// Localization helper (same as web)
func __(_ string: String.LocalizationValue) -> String {
    String(localized: string)
}

extension OrderedSet {
    subscript(mutating position: Int) -> Element {
        get {
            self[position]
        }
        set {
            update(newValue, at: position)
        }
    }
}

extension ButtonRole {
    static let closeOrCancel = if #available(iOS 26, *) {
        close
    } else {
        cancel
    }
}

extension Text {
    func wrap() -> some View {
        fixedSize(horizontal: false, vertical: true)
    }
}
