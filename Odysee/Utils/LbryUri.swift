//
//  LbryUri.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Foundation

struct LbryUri: CustomStringConvertible {
    static let protoDefault = "lbry://"
    static let lbryTvBaseUrl = "https://lbry.tv/"
    static let odyseeBaseUrl = "https://odysee.com/"
    static let highSurrogate: [unichar] = [0xD800]
    static let lowSurrogate: [unichar] = [0xDFFF]
    static let regexInvalidUri = try! NSRegularExpression(
        pattern: NSString(
            format: "[ =&#:$@%?;/\\\\\"<>%\\{\\}|^~\\[\\]`\u{0000}-\u{0008}\u{000b}-\u{000c}\u{000e}-\u{001F}%@-%@\u{FFFE}-\u{FFFF}]",
            NSString(
                characters: highSurrogate,
                length: highSurrogate.count
            ),
            NSString(characters: lowSurrogate, length: lowSurrogate.count)
        ) as String,
        options: .caseInsensitive
    )
    static let regexAddress = try! NSRegularExpression(
        pattern: "^(b)(?=[^0OIl]{32,33})[0-9A-Za-z]{32,33}$",
        options: .caseInsensitive
    )
    static let channelNameMinLength = 1
    static let claimIdMaxLength = 40

    static let rePartProtocol = "^((?:lbry://|https://)?)"
    static let rePartHost = "((?:open.lbry.com/|odysee.com/|lbry.tv/)?)"
    static let rePartStreamOrChannelName = "([^:$#/]*)"
    static let rePartModifierSeparator = "([:$#]?)([^/]*)"
    static let queryStringBreaker = "^([\\S]+)([?][\\S]*)"
    static let regexSeparateQueryString = try! NSRegularExpression(
        pattern: queryStringBreaker,
        options: .caseInsensitive
    )

    var path: String?
    var isChannel: Bool = false
    var streamName: String?
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

    var description: String {
        return build(includeProto: true, protoDefault: LbryUri.protoDefault, vanity: false)
    }

    var odyseeString: String {
        return build(includeProto: true, protoDefault: LbryUri.odyseeBaseUrl, vanity: false)
    }

    var tvString: String {
        return build(includeProto: true, protoDefault: LbryUri.lbryTvBaseUrl, vanity: false)
    }

    var vanityString: String {
        return build(includeProto: true, protoDefault: LbryUri.protoDefault, vanity: true)
    }

    func isChannelUrl() -> Bool {
        return (!(channelName ?? "").isBlank && (streamName ?? "").isBlank) || (claimName ?? "").starts(with: "@")
    }

    static func isNameValid(_ name: String?) -> Bool {
        return !(name ?? "").isBlank && regexInvalidUri
            .firstMatch(in: name!, options: [], range: NSRange(name!.startIndex..., in: name!)) == nil
    }

    static func parse(url: String, requireProto: Bool) throws -> LbryUri {
        let regexComponents = try! NSRegularExpression(
            pattern: String(
                format: "%@%@%@%@(/?)%@%@",
                rePartProtocol,
                rePartHost,
                rePartStreamOrChannelName,
                rePartModifierSeparator,
                rePartStreamOrChannelName,
                rePartModifierSeparator
            ),
            options: [.caseInsensitive]
        )

        var cleanUrl = url, queryString: String?
        let qsMatches = regexSeparateQueryString.matches(
            in: cleanUrl,
            options: [],
            range: NSRange(url.startIndex..., in: url)
        )
        if qsMatches.count > 0 {
            let qsRange = Range(qsMatches[0].range(at: 2))
            queryString = String(cleanUrl[qsRange!])
            let qsLen = (queryString ?? "").count
            if qsLen > 0 {
                cleanUrl = String(url[0 ..< qsRange!.lowerBound])
                queryString = String(queryString![1 ..< (queryString?.endIndex.utf16Offset(in: queryString!))!])
            }
        }

        var components: [String] = []
        let results = regexComponents.matches(
            in: cleanUrl,
            options: [],
            range: NSRange(cleanUrl.startIndex..., in: cleanUrl)
        )
        if results.count > 0 {
            for index in 1 ..< results[0].numberOfRanges {
                components.append(String(cleanUrl[Range(results[0].range(at: index), in: cleanUrl)!]))
            }
        }

        if components.count == 0 {
            throw LbryUriError.runtimeError("Regular expression error occurred while trying to parse the value")
        }
        if requireProto, components[0].isBlank {
            throw LbryUriError.runtimeError("LBRY URLs must include a protocol prefix (lbry://).")
        }
        for component in components[2 ..< components.count] {
            if component.contains(" ") {
                throw LbryUriError.runtimeError("URL cannot include a space")
            }
        }

        let streamOrChannelName = components[2]
        let primaryModSeparator = components[3]
        let primaryModValue = components[4]
        let possibleStreamName = components[6]
        let secondaryModSeparator = components[7]
        let secondaryModValue = components[8]

        let includesChannel = streamOrChannelName.starts(with: "@")
        let isChannel = includesChannel && possibleStreamName.isEmpty
        let channelName: String? = includesChannel && streamOrChannelName
            .count > 1 ?
            String(
                streamOrChannelName
                    .suffix(from: streamOrChannelName.index(after: streamOrChannelName.firstIndex(of: "@")!))
            ) : nil

        if includesChannel {
            if (channelName ?? "").isBlank {
                throw LbryUriError.runtimeError("No channel name after @")
            }
            if (channelName ?? "").count < channelNameMinLength {
                throw LbryUriError
                    .runtimeError(String(
                        format: "Channel names must be at least %d character long.",
                        channelNameMinLength
                    ))
            }
        }

        var primaryMod: UriModifier?, secondaryMod: UriModifier?
        if !primaryModSeparator.isBlank, !primaryModValue.isBlank {
            primaryMod = try UriModifier.parse(modSeparator: primaryModSeparator, modValue: primaryModValue)
        }
        if !secondaryModSeparator.isBlank, !secondaryModValue.isBlank {
            secondaryMod = try UriModifier.parse(modSeparator: secondaryModSeparator, modValue: secondaryModValue)
        }

        let streamName: String? = includesChannel ? possibleStreamName : streamOrChannelName
        let streamClaimId: String? = includesChannel && secondaryMod != nil ? secondaryMod?
            .claimId : primaryMod != nil ? primaryMod?.claimId : nil
        let channelClaimId: String? = includesChannel && primaryMod != nil ? primaryMod?.claimId : nil

        return LbryUri(
            path: components[2 ..< components.count].joined(),
            isChannel: isChannel,
            streamName: streamName,
            streamClaimId: streamClaimId,
            channelName: channelName,
            channelClaimId: channelClaimId,
            primaryClaimSequence: primaryMod?.claimSequence ?? -1,
            secondaryClaimSequence: secondaryMod?.claimSequence ?? -1,
            primaryBidPosition: primaryMod?.bidPosition ?? -1,
            secondaryBidPosition: secondaryMod?.bidPosition ?? -1,
            claimName: streamOrChannelName,
            claimId: primaryMod?.claimId,
            contentName: streamName,
            queryString: queryString
        )
    }

    func build(includeProto: Bool, protoDefault: String, vanity: Bool) -> String {
        var formattedChannelName: String?
        if channelName != nil {
            formattedChannelName = channelName!.starts(with: "@") ? channelName : String(format: "@%@", channelName!)
        }
        var primaryClaimName: String? = claimName
        if (primaryClaimName ?? "").isBlank {
            primaryClaimName = contentName
        }
        if (primaryClaimName ?? "").isBlank {
            primaryClaimName = formattedChannelName
        }
        if (primaryClaimName ?? "").isBlank {
            primaryClaimName = streamName
        }

        var primaryClaimId: String? = claimId
        if (primaryClaimId ?? "").isBlank {
            primaryClaimId = (formattedChannelName ?? "").isBlank ? channelClaimId : streamClaimId
        }

        var url = ""
        if includeProto {
            url.append(protoDefault)
        }
        url.append(primaryClaimName ?? "")
        if vanity {
            return url
        }

        var secondaryClaimName: String?
        if (claimName ?? "").isBlank, !(contentName ?? "").isBlank {
            secondaryClaimName = contentName
        }
        if (secondaryClaimName ?? "").isBlank {
            secondaryClaimName = !(formattedChannelName ?? "").isBlank ? streamName : nil
        }
        let secondaryClaimId: String? = !(secondaryClaimName ?? "").isBlank ? streamClaimId : nil

        if !(primaryClaimId ?? "").isBlank {
            url.append(":")
            url.append(primaryClaimId ?? "")
        } else if primaryClaimSequence > 0 {
            url.append("*")
            url.append(String(primaryClaimSequence))
        } else if primaryBidPosition > 0 {
            url.append("$")
            url.append(String(primaryBidPosition))
        }

        if !(secondaryClaimName ?? "").isBlank {
            url.append("/")
            url.append(secondaryClaimName ?? "")
        }
        if !(secondaryClaimId ?? "").isBlank {
            url.append(":")
            url.append(secondaryClaimId ?? "")
        } else if secondaryClaimSequence > 0 {
            url.append("*")
            url.append(String(secondaryClaimSequence))
        } else if secondaryBidPosition > 0 {
            url.append("$")
            url.append(String(secondaryBidPosition))
        }

        return url
    }

    static func tryParse(url: String, requireProto: Bool) -> LbryUri? {
        do {
            return try LbryUri.parse(url: url, requireProto: requireProto)
        } catch {
            print(error)
            return nil
        }
    }

    static func normalize(url: String) throws -> String {
        return try parse(url: url, requireProto: false).description
    }

    struct UriModifier {
        static let regexClaimId = try! NSRegularExpression(pattern: "^[0-9a-f]+$", options: .caseInsensitive)
        let claimId: String?
        let claimSequence: Int
        let bidPosition: Int

        static func parse(modSeparator: String, modValue: String) throws -> UriModifier {
            var claimId: String?
            var claimSequence = 0, bidPosition = 0
            if !modSeparator.isBlank {
                if modValue.isBlank {
                    throw LbryUriError
                        .runtimeError(String(format: "No modifier provided after separator %@", modSeparator))
                }

                if modSeparator == "#" || modSeparator == ":" {
                    claimId = modValue
                } else if modSeparator == "*" {
                    claimSequence = Int(modValue) ?? -1
                } else if modSeparator == "$" {
                    bidPosition = Int(modValue) ?? -1
                }
            }

            if claimId != nil, !(claimId ?? "").isBlank,

               claimId!.count > LbryUri.claimIdMaxLength ||
               regexClaimId.firstMatch(
                   in: claimId!,
                   options: [],
                   range: NSRange(claimId!.startIndex..., in: claimId!)
               ) == nil

            {
                throw LbryUriError.runtimeError(String(format: "Invalid claim ID %@", claimId!))
            }
            if claimSequence == -1 {
                throw LbryUriError.runtimeError("Claim sequence must be a number")
            }
            if bidPosition == -1 {
                throw LbryUriError.runtimeError("Bid position must be a number")
            }

            return UriModifier(claimId: claimId, claimSequence: claimSequence, bidPosition: bidPosition)
        }
    }
}

enum LbryUriError: Error {
    case runtimeError(String)
}
