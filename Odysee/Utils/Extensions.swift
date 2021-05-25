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
