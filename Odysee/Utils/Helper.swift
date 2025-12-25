//
//  Helper.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import Base58Swift
import CoreActionSheetPicker
import FirebaseCrashlytics
import Foundation
import UIKit

enum Helper {
    static let minimumSpend: Decimal = 0.0001
    static let minimumDepositString: String = "0.001"
    static let minimumDeposit: Decimal = 0.001
    static let commentMinLength: Int = 50
    static let commentMaxLength: Int = 2000
    static let txLinkPrefix = "https://explorer.lbry.com/tx"
    static let keyReceiveAddress = "walletReceiveAddress"
    /// Can be a reinstall after uninstall, in which case UserDefaults is cleared but not Keychain
    static let keyHasRunAfterInstall = "hasRunAfterInstall"
    static let keyFirstRunCompleted = "firstRunCompleted"
    static let keyPostedCommentHideTos = "postedCommentHideTos"
    static let reactionTypeLike = "like"
    static let reactionTypeDislike = "dislike"
    static let tagDisableComments = "disable-comments"

    // swift-format-ignore
    // Initialized once with static value
    static let thumbUploadURL = URL(string: "https://thumbs.odycdn.com/upload")!

    static let primaryColor = UIColor(red: 229.0 / 255.0, green: 0, blue: 84.0 / 255.0, alpha: 1)
    static let lightPrimaryColor = UIColor(red: 250.0 / 255.0, green: 97.0 / 255.0, blue: 101.0 / 255.0, alpha: 1)
    static let fireActiveColor = UIColor(red: 255.0 / 255.0, green: 102.0 / 255.0, blue: 53.0 / 255.0, alpha: 1)
    static let slimeActiveColor = UIColor(red: 129.0 / 255.0, green: 197.0 / 255.0, blue: 84.0 / 255.0, alpha: 1)
    static let uaGradientStartColor = UIColor(red: 244.0 / 255.0, green: 93.0 / 255.0, blue: 72.0 / 255.0, alpha: 1)
    static let uaGradientEndColor = UIColor(red: 242.0 / 255.0, green: 58.0 / 255.0, blue: 92.0 / 255.0, alpha: 1)

    static let sortByItemNames = ["Trending content", "New content", "Top content"]
    static let contentFromItemNames = ["Past 24 hours", "Past week", "Past month", "Past year", "All time"]
    static let sortByItemValues = [
        ["trending_group", "trending_mixed"], ["release_time"], ["effective_amount"],
    ]

    static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(abbreviation: "UTC")
        return f
    }()

    static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()

    static let sdkAmountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 8
        f.usesGroupingSeparator = false
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.roundingMode = .down
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        f.numberStyle = .decimal
        f.locale = Locale.current
        return f
    }()

    static let currencyFormatter4: NumberFormatter = {
        let f = NumberFormatter()
        f.roundingMode = .up
        f.minimumFractionDigits = 4
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = true
        f.numberStyle = .decimal
        f.locale = Locale.current
        return f
    }()

    static let fullRelativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    static let shortRelativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        return f
    }()

    static let interactionCountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.usesGroupingSeparator = true
        f.locale = Locale.current
        f.numberStyle = .decimal
        return f
    }()

    static func isAddressValid(address: String?) -> Bool {
        guard let address, !address.isBlank else {
            return false
        }
        // TODO: Figure out why regex is broken
        /*
         if LbryUri.regexAddress.firstMatch(in: address, options: [], range: NSRange(address.startIndex..., in:address)) == nil {
             return false
         }*/
        if !address.starts(with: "b") {
            return false
        }
        if Base58.base58CheckDecode(address) == nil {
            return false
        }

        return true
    }

    static func releaseTime6Months() -> String {
        var time = Int64(Date().timeIntervalSince1970)
        time = time - (60 * 60 * 24 * 180)
        return ">\(time)"
    }

    static var releaseTimeBeforeFuture: String {
        "<\(Int64(Date().timeIntervalSince1970))"
    }

    static func buildReleaseTime(contentFrom: String?) -> String? {
        if contentFrom == contentFromItemNames[4] {
            return nil
        }

        var time = Int64(Date().timeIntervalSince1970)
        if contentFrom == contentFromItemNames[0] {
            time = time - (60 * 60 * 24)
        } else if contentFrom == contentFromItemNames[1] {
            time = time - (60 * 60 * 24 * 7)
        } else if contentFrom == contentFromItemNames[2] {
            time = time - (60 * 60 * 24 * 30) // conservative month estimate?
        } else if contentFrom == contentFromItemNames[3] {
            time = time - (60 * 60 * 24 * 365)
        }

        return ">\(time)"
    }

    @discardableResult
    static func showPickerActionSheet(
        title: String,
        origin: UIView,
        rows: [String],
        initialSelection: Int,
        handler: @escaping (ActionSheetStringPicker?, Int, Any?) -> Void
    ) -> ActionSheetStringPicker {
        Crashlytics.crashlytics().setCustomKeysAndValues([
            "showPickerActionSheet_title": title,
            "showPickerActionSheet_origin": origin,
            "showPickerActionSheet_rows": rows,
            "showPickerActionSheet_initialSelection": initialSelection,
        ])
        // swift-format-ignore
        // Init never returns nil, is only due to objc
        let picker = ActionSheetStringPicker(
            title: title,
            rows: rows,
            initialSelection: initialSelection,
            doneBlock: handler,
            cancel: nil,
            origin: origin
        )!
        picker.hideCancel = true
        picker.show()
        return picker
    }

    static func shortCurrencyFormat(value: Decimal?) -> String {
        guard let value else {
            return ""
        }

        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.roundingMode = .down
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2

        if value > 1_000_000_000 {
            return "\(formatter.string(for: (value / 1_000_000_000) as NSDecimalNumber) ?? "")B"
        }
        if value > 1_000_000 {
            return "\(formatter.string(for: (value / 1_000_000) as NSDecimalNumber) ?? "")M"
        }
        if value > 1000 {
            return "\(formatter.string(for: (value / 1000) as NSDecimalNumber) ?? "")K"
        }

        return formatter.string(for: value as NSDecimalNumber) ?? ""
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
        if let window = UIApplication.shared.windows.filter(\.isKeyWindow).first {
            let safeAreaFrame = window.safeAreaLayoutGuide.layoutFrame
            return CGFloat(window.frame.maxY - safeAreaFrame.maxY + 2)
        }
        return 0
    }

    static func miniPlayerBottomWithTabBar(appDelegate: AppDelegate) -> CGFloat {
        return (AppDelegate.shared.mainTabViewController?.tabBar.frame.size.height ?? 0) + 2
    }

    static func makeid() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        // swift-format-ignore
        // randomElement from a static collection which is never empty
        return String((0 ..< 24).map { _ in chars.randomElement()! })
    }

    static func uploadImage(image: UIImage, completion: @escaping (String?, Error?) -> Void) {
        var mimeType: String?
        var imageData: Data?
        var filename: String?
        if let jpegData = image.jpegData(compressionQuality: 0.9) {
            mimeType = "image/jpeg"
            imageData = jpegData
            filename = "image.jpg"
        } else if let pngData = image.pngData() {
            mimeType = "image/png"
            imageData = pngData
            filename = "image.png"
        }
        guard let mimeType, let imageData, let filename else {
            completion(nil, GenericError("The selcted image could not be uploaded"))
            return
        }

        let name = makeid()
        let boundary = "Boundary-\(UUID().uuidString)"
        var fieldData = "--\(boundary)\r\n"
        fieldData.append("Content-Disposition: form-data; name=\"upload\"\r\n\r\n\(name)\r\n")

        let data = NSMutableData()
        data.append("--\(boundary)\r\n".data)
        data
            .append(
                "Content-Disposition: form-data; name=\"file-input\"; filename=\"\(filename)\"\r\n"
                    .data
            )
        data.append("Content-Type: \(mimeType)\r\n\r\n".data)
        data.append(imageData)
        data.append("\r\n".data)

        let reqBody = NSMutableData()
        reqBody.append(fieldData.data)
        reqBody.append(data as Data)
        reqBody.append("--\(boundary)--\r\n".data)

        var req = URLRequest(url: thumbUploadURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(String(reqBody.count), forHTTPHeaderField: "Content-Length")
        req.httpBody = reqBody as Data

        let task = URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }

            do {
                let respData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let respType = respData?["type"] as? String {
                    if respType == "success", let serveUrl = respData?["url"] as? String {
                        completion(serveUrl, nil)
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

    static func claimContainsTag(claim: Claim, tag: String) -> Bool {
        return claim.value?.tags?.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } ?? false
    }

    static func strToHex(_ str: String) -> String {
        let data = Data(str.utf8)
        return data.map { String(format: "%02x", $0) }.joined()
    }

    static func addThumbURLs(claims: [String: Claim], thumbURLs: inout [String: URL]) {
        thumbURLs.reserveCapacity(thumbURLs.count + claims.count)
        for (url, claim) in claims {
            if let thumbUrl = claim.value?.thumbnail?.url.flatMap(URL.init) {
                thumbURLs[url] = thumbUrl
            }
        }
    }

    static func isCustomBlocked(claimId: String, appDelegate: AppDelegate) -> Bool {
        var isBlocked = false
        if let rules = AppDelegate.shared.mainController.customBlockRulesMap[claimId],
           let locale = AppDelegate.shared.mainController.currentLocale
        {
            for rule in rules {
                if rule.scope == CustomBlockScope.special, rule.id?.lowercased() == "eu-only",
                   locale.isEUMember ?? false
                {
                    isBlocked = true
                    break
                }

                if rule.scope == CustomBlockScope.continent, rule.id?.lowercased() == locale.continent?.lowercased() {
                    isBlocked = true
                    break
                }

                if rule.scope == CustomBlockScope.country, rule.id?.lowercased() == locale.country?.lowercased() {
                    isBlocked = true
                    break
                }
            }
        }

        return isBlocked
    }

    static func getCustomBlockedMessage(claimId: String, appDelegate: AppDelegate) -> String? {
        var message: String?
        if let rules = AppDelegate.shared.mainController.customBlockRulesMap[claimId],
           let locale = AppDelegate.shared.mainController.currentLocale
        {
            for rule in rules {
                if rule.scope == CustomBlockScope.special, rule.id?.lowercased() == "eu-only",
                   locale.isEUMember ?? false
                {
                    message = rule.message
                    break
                }

                if rule.scope == CustomBlockScope.continent, rule.id?.lowercased() == locale.continent?.lowercased() {
                    message = rule.message
                    break
                }

                if rule.scope == CustomBlockScope.country, rule.id?.lowercased() == locale.country?.lowercased() {
                    message = rule.message
                    break
                }
            }
        }

        return message
    }

    static func isChannelBlocked(claimId: String?) -> Bool {
        guard claimId != nil else {
            return false
        }
        return Lbry.blockedChannels.map(\.claimId).contains(claimId)
    }

    @MainActor
    static func showMessage(message: String?) {
        (AppDelegate.shared.mainViewController as? MainViewController)?.showMessage(message: message)
    }

    @MainActor
    static func showError(message: String?) {
        (AppDelegate.shared.mainViewController as? MainViewController)?.showError(message: message)
    }

    @MainActor
    static func showError(error: Error) {
        (AppDelegate.shared.mainViewController as? MainViewController)?.showError(error: error)
    }
}

struct GenericError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var localizedDescription: String {
        return message
    }
}
