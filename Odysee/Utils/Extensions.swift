//
//  Extensions.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/11/2020.
//

import Foundation
import UIKit

extension String {
    var isBlank: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        DispatchQueue.global().async { [weak self] in
            DispatchQueue.main.async {
                self?.image = nil
            }
            
            var image: UIImage? = nil
            if let cacheData = Cache.getImage(url: url.absoluteString) {
                image = UIImage(data: cacheData)
            } else if let data = try? Data(contentsOf: url) {
                image = UIImage(data: data)
                if (image != nil) {
                    Cache.putImage(url: url.absoluteString, image: data)
                }
            }
            DispatchQueue.main.async {
                self?.image = image
            }
        }
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
