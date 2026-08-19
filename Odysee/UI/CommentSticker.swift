//
//  CommentSticker.swift
//  Odysee
//
//  Created by Keith on 19/08/2026.
//

import RegexBuilder
import SwiftUI

@available(iOS 16, *)
struct CommentSticker: View {
    /// Returns the sticker's name if the *entire* comment matches the sticker format
    static func parse(_ comment: String) -> ImageResource? {
        let regex = Regex {
            "<stkr>:"

            Capture {
                OneOrMore {
                    /[A-Z0-9_]/
                }
            }

            ":<stkr>"
        }

        guard let match = comment.wholeMatch(of: regex) else {
            return nil
        }

        let name = String(match.1)

        if let freeSticker = Constants.FreeSticker(name: name) {
            return freeSticker
        } else if let paidSticker = Constants.PaidSticker(name: name) {
            return paidSticker
        } else {
            return nil
        }
    }

    var sticker: ImageResource

    @FontScaled(relativeTo: .body) private var size: CGFloat = 4

    var body: some View {
        Image(sticker)
            .resizable()
            .frame(width: size, height: size)
    }
}

@available(iOS 16, *)
#Preview {
    if let sticker = CommentSticker.parse("<stkr>:FIRE:<stkr>") {
        CommentSticker(sticker: sticker)
    }

    Text(CommentSticker.parse("<stkr>:UNKNOWN:<stkr>").debugDescription)
    Text(CommentSticker.parse("<stkr>:invalid:<stkr>").debugDescription)
    Text(CommentSticker.parse("Other").debugDescription)
}
