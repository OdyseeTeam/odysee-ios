//
//  Extensions.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/11/2020.
//

import Foundation
import PINRemoteImage
import UIKit

extension String {
    var isBlank: Bool {
        return !contains { !$0.isWhitespace && !$0.isNewline }
    }

    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }

    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
    public static func localized(_ key: String, comment: String? = nil) -> String {
        return NSLocalizedString(key, comment: comment ?? "")
    }
}

extension UIImageView {
    func load(url: URL) {
        self.pin_setImage(from: url)
    }
    
    func rounded() {
        self.layer.masksToBounds = false
        self.layer.cornerRadius = self.frame.height / 2
        self.clipsToBounds = true
    }
}

extension UIApplication {
    class func currentViewController(_ viewController: UIViewController? = UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.rootViewController
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
    func dataTask(with request: URLRequest,
                  completionHandler: @escaping (Result<DataTaskSuccess, Error>) -> Void) -> URLSessionDataTask {
        return self.dataTask(with: request) { data, response, error in
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
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
        }
    }
}

extension Optional {
    // Assert this optional is not nil (so we catch it in debug), and return `self ?? defaultValue`
    func assertAndDefault(_ defaultValue: @autoclosure () -> Wrapped) -> Wrapped {
        assert(self != nil)
        return self ?? defaultValue()
    }
}

// These extensions are useful for Lbry.swift – so that we can support old methods that haven't
// migrated to their own Params type yet and still use dictionaries.
extension NSString: Encodable {
    public func encode(to encoder: Encoder) throws {
        try (self as String).encode(to: encoder)
    }
}

extension NSNull: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

extension NSDictionary: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        for (k, v) in self {
            guard let keyString = k as? String else {
                throw EncodingError.invalidValue(k, .init(codingPath: encoder.codingPath,
                                                          debugDescription: "NSDictionary key"))
            }
            let nestedEncoder = c.superEncoder(forKey: .init(stringValue: keyString))
            guard let encodableValue = v as? Encodable else {
                throw EncodingError.invalidValue(v, .init(codingPath: nestedEncoder.codingPath,
                                                          debugDescription: "NSDictionary value"))
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

extension NSArray: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        for v in self {
            let nestedEncoder = c.superEncoder()
            guard let encodableValue = v as? Encodable else {
                throw EncodingError.invalidValue(v, .init(codingPath: nestedEncoder.codingPath,
                                                          debugDescription: "NSArray"))
            }
            try encodableValue.encode(to: nestedEncoder)
        }
    }
}

extension NSNumber: Encodable {
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
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath,
                                                         debugDescription: "NSNumber"))
        }
    }
}
