//
//  Helper.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Base58Swift
import Foundation
import UIKit

final class Helper {
    static let minimumSpend: Decimal = 0.0001
    static let minimumDeposit: Decimal = 0.001
    static let commentMinLength: Int = 50
    static let commentMaxLength: Int = 2000
    static let txLinkPrefix = "https://explorer.lbry.com/tx"
    static let keyReceiveAddress = "walletReceiveAddress"
    
    static let primaryColor: UIColor = UIColor.init(red: 229.0/255.0, green: 0, blue: 84.0/255.0, alpha: 1)
    static let lightPrimaryColor: UIColor = UIColor.init(red: 250.0/255.0, green: 97.0/255.0, blue: 101.0/255.0, alpha: 1)
    static let fireActiveColor: UIColor = UIColor.init(red: 255.0/255.0, green: 102.0/255.0, blue: 53.0/255.0, alpha: 1)
    static let slimeActiveColor: UIColor = UIColor.init(red: 129.0/255.0, green: 197.0/255.0, blue: 84.0/255.0, alpha: 1)
    
    static let sortByItemNames = ["Trending content", "New content", "Top content"]
    static let contentFromItemNames = ["Past 24 hours", "Past week", "Past month", "Past year", "All time"]
    static let sortByItemValues = [
        ["trending_group", "trending_mixed"], ["release_time"], ["effective_amount"]
    ];
    
    static let apiDateFormatter = DateFormatter()
    static let sdkAmountFormatter = NumberFormatter()
    static let currencyFormatter = NumberFormatter()
    static let currencyFormatter4 = NumberFormatter()
    static func initFormatters() {
        currencyFormatter.roundingMode = .down
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .decimal
        currencyFormatter.locale = Locale.current
        
        currencyFormatter4.roundingMode = .up
        currencyFormatter4.minimumFractionDigits = 4
        currencyFormatter4.maximumFractionDigits = 4
        currencyFormatter4.usesGroupingSeparator = true
        currencyFormatter4.numberStyle = .decimal
        currencyFormatter4.locale = Locale.current
        
        sdkAmountFormatter.minimumFractionDigits = 2
        sdkAmountFormatter.maximumFractionDigits = 8
        sdkAmountFormatter.usesGroupingSeparator = false
        sdkAmountFormatter.numberStyle = .decimal
        sdkAmountFormatter.locale = Locale.init(identifier: "en_US")
        
        apiDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    }

    static func isAddressValid(address: String?) -> Bool {
        if (address ?? "").isBlank {
            return false
        }
        // TODO: Figure out why regex is broken
        /*
        if LbryUri.regexAddress.firstMatch(in: address!, options: [], range: NSRange(address!.startIndex..., in:address!)) == nil {
            return false
        }*/
        if !address!.starts(with: "b") {
            return false
        }
        if Base58.base58CheckDecode(address!) == nil {
            return false
        }
        
        return true
    }
    
    static func buildReleaseTime(contentFrom: String?) -> String? {
        if (contentFrom == contentFromItemNames[4]) {
            return nil
        }
        
        var time = Int64(Date().timeIntervalSince1970)
        if (contentFrom == contentFromItemNames[0]) {
            time = time - (60 * 60 * 24)
        } else if (contentFrom == contentFromItemNames[1]) {
            time = time - (60 * 60 * 24 * 7)
        } else if (contentFrom == contentFromItemNames[2]) {
            time = time - (60 * 60 * 24 * 30) // conservative month estimate?
        } else if (contentFrom == contentFromItemNames[3]) {
            time = time - (60 * 60 * 24 * 365)
        }
        
        return String(format: ">%d", time)
    }
    
    static func buildPickerActionSheet(title: String, dataSource: UIPickerViewDataSource, delegate: UIPickerViewDelegate, parent: UIViewController, handler: ((UIAlertAction) -> Void)? = nil) -> (UIPickerView, UIAlertController) {
        let pickerFrame = CGRect(x: 0, y: 0, width: parent.view.frame.width, height: 160)
        let picker = UIPickerView(frame: pickerFrame)
        picker.dataSource = dataSource
        picker.delegate = delegate
        
        let alert = UIAlertController(title: title, message: "", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: String.localized("Done"), style: .default, handler: handler))
        
        let vc = UIViewController()
        vc.preferredContentSize = CGSize(width: parent.view.frame.width, height: 160)
        vc.view.addSubview(picker)
        alert.setValue(vc, forKey: "contentViewController")
        
        return (picker, alert)
    }

    static func shortCurrencyFormat(value: Decimal?) -> String {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .down
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        
        if (value! > 1000000000) {
            return String(format: "%@B", formatter.string(for: (value! / 1000000000) as NSDecimalNumber)!)
        }
        if (value! > 1000000) {
            return String(format: "%@M", formatter.string(for: (value! / 1000000) as NSDecimalNumber)!)
        }
        if (value! > 1000) {
            return String(format: "%@K", formatter.string(for: (value! / 1000) as NSDecimalNumber)!)
        }
        
        return formatter.string(for: value! as NSDecimalNumber)!
    }
    
    static func buildFileViewTransition() -> CATransition {
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = .fromTop
        return transition
    }
    
    static func miniPlayerBottomWithoutTabBar() -> CGFloat {
        let window = UIApplication.shared.windows.filter{ $0.isKeyWindow }.first!
        let safeAreaFrame = window.safeAreaLayoutGuide.layoutFrame
        return CGFloat(window.frame.maxY - safeAreaFrame.maxY + 2)
    }
    
    static func makeid() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<24).map{ _ in chars.randomElement()! })
    }
    
    static func uploadImage(image: UIImage, completion: @escaping (String?, Error?) -> Void) {
        var mimeType: String? = nil
        var imageData: Data? = nil
        var filename: String? = nil
        if let jpegData = image.jpegData(compressionQuality: 0.9) {
            mimeType = "image/jpeg"
            imageData = jpegData
            filename = "image.jpg"
        } else if let pngData = image.pngData() {
            mimeType = "image/png"
            imageData = pngData
            filename = "image.png"
        }
        if mimeType == nil || imageData == nil {
            completion(nil, GenericError("The selcted image could not be uploaded"))
            return
        }
        
        let name = makeid()
        let boundary = "Boundary-\(UUID().uuidString)"
        var fieldData = "--\(boundary)\r\n"
        fieldData.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n\(name)\r\n")
        
        let data = NSMutableData()
        data.append("--\(boundary)\r\n".data(using: .utf8, allowLossyConversion: false)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename!)\"\r\n".data(using: .utf8, allowLossyConversion: false)!)
        data.append("Content-Type: \(mimeType!)\r\n\r\n".data(using: .utf8, allowLossyConversion: false)!)
        data.append(imageData!)
        data.append("\r\n".data(using: .utf8, allowLossyConversion: false)!)
        
        let reqBody = NSMutableData()
        reqBody.append(fieldData.data(using: .utf8, allowLossyConversion: false)!)
        reqBody.append(data as Data)
        reqBody.append("--\(boundary)--\r\n".data(using: .utf8, allowLossyConversion: false)!)
        
        var req = URLRequest(url: URL(string: "https://spee.ch/api/claim/publish")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(String(reqBody.count), forHTTPHeaderField: "Content-Length")
        req.httpBody = reqBody as Data
        
        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }
            
            do {
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let success = respData?["success"] as? Bool
                if success != nil && success! {
                    if let responseData = respData?["data"] as? [String: Any] {
                        completion(responseData["serveUrl"] as? String, nil)
                        return
                    }
                }
            } catch {
                // failure condition
            }
            
            completion(nil, GenericError("The image upload failed. Please try again."))
        }
        task.resume()
    }
}

struct GenericError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
    public var localizedDescription: String {
        return message
    }
}
