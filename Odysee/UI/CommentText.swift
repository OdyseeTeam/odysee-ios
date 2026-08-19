//
//  CommentText.swift
//  Odysee
//
//  Created by Keith on 19/08/2026.
//

import RegexBuilder
import SwiftUI

enum EmoteAttribute: AttributedStringKey {
    typealias Value = String

    static let name = "emote"
}

extension AttributeScopes {
    struct OdyseeAppAttributes: AttributeScope {
        let emote: EmoteAttribute
    }

    var odyseeApp: OdyseeAppAttributes.Type { OdyseeAppAttributes.self }
}

/// Renders `:emotes:`, Markdown, and clickable Timestamps
@available(iOS 16.0, *)
struct CommentText: View {
    var comment: String

    init(_ comment: String) {
        self.comment = comment
    }

    private var tryMarkdown: AttributedString {
        (try? AttributedString(markdown: comment)) ?? AttributedString(comment)
    }

    private var timestamped: AttributedString {
        String(tryMarkdown.characters) // https://stackoverflow.com/a/79944058
            .matches {
                Regex {
                    OneOrMore {
                        ChoiceOf {
                            CharacterClass.digit

                            ":"
                        }
                    }

                    // Don't end with :
                    CharacterClass.digit
                }
            }
            /// <https://github.com/OdyseeTeam/odysee-frontend/blob/ffb6c71312d33abbdc6cd5e3aad4e589ba657960/ui/util/remark-timestamp.js#L43-L61>
            .filter { match in
                do {
                    let s = String(match.0)
                    switch s.count {
                    case 4: // "9:59"
                        return try /^[0-9]:[0-5][0-9]$/.wholeMatch(in: s) != nil
                    case 5: // "59:59"
                        return try /^[0-5][0-9]:[0-5][0-9]$/.wholeMatch(in: s) != nil
                    case 7: // "9:59:59"
                        return try /^[0-9]:[0-5][0-9]:[0-5][0-9]$/.wholeMatch(in: s) != nil
                    case 8: // "99:59:59"
                        return try /^[0-9][0-9]:[0-5][0-9]:[0-5][0-9]$/.wholeMatch(in: s) != nil
                    default:
                        return false
                    }
                } catch {
                    return false
                }
            }
            /// <https://github.com/OdyseeTeam/odysee-frontend/blob/ffb6c71312d33abbdc6cd5e3aad4e589ba657960/ui/util/remark-timestamp.js#L131-L134>
            .map { match in
                let timestampStrings = match.0.split(separator: ":").reversed().map(String.init)
                let components = timestampStrings.compactMap(Int.init)

                return (components, match)
            }
            .reduce(into: tryMarkdown) { attr, timestamp in
                let (components, match) = timestamp

                let seconds = (components.count >= 3 ? components[2] : 0) * 60 * 60
                    + (components.count >= 2 ? components[1] : 0) * 60
                    + (components.count >= 1 ? components[0] : 0)

                if let range = Range(match.range, in: tryMarkdown),
                   /// <https://github.com/OdyseeTeam/odysee-frontend/blob/ffb6c71312d33abbdc6cd5e3aad4e589ba657960/ui/util/remark-timestamp.js#L142>
                   let url = URL(string: "?t=\(seconds)")
                {
                    attr[range].link = url
                }
            }
    }

    private var emoted: AttributedString {
        String(timestamped.characters) // https://stackoverflow.com/a/79944058
            .matches {
                Regex {
                    NegativeLookahead {
                        "<stkr>"
                    }

                    ":"

                    Capture {
                        ChoiceOf {
                            "+1"

                            "-1"

                            OneOrMore {
                                ChoiceOf {
                                    CharacterClass.word

                                    "-"
                                }
                            }
                        }
                    }

                    ":"

                    NegativeLookahead {
                        "<stkr>"
                    }
                }
            }
            .reduce(into: timestamped) { attr, match in
                let emote = String(match.1)

                if let range = Range(match.range, in: timestamped) {
                    attr[range].odyseeApp.emote = emote
                }
            }
    }

    @FontScaled(relativeTo: .body) private var bodySize

    /// https://stackoverflow.com/a/79494720
    private var renderedText: Text {
        var output = Text("")

        for run in emoted.runs {
            if let emote = run.odyseeApp.emote,
               let emoteResource = emoteResource(for: emote)
            {
                // FIXME: Accessibility
                output = output + Text(Image(emoteResource, size: bodySize)).baselineOffset(bodySize * -0.2)
            } else {
                output = output + Text(AttributedString(emoted[run.range]))
            }
        }

        return output
    }

    private func emoteResource(for name: String) -> ImageResource? {
        if let odyseeEmote = Constants.OdyseeEmote(name: name) {
            odyseeEmote
        } else if let smilesTwemote = Constants.SmilesTwemote(name: name) {
            smilesTwemote
        } else if let handsignalsTwemote = Constants.HandsignalsTwemote(name: name) {
            handsignalsTwemote
        } else if let activitiesTwemote = Constants.ActivitiesTwemote(name: name) {
            activitiesTwemote
        } else if let symbolsTwemote = Constants.SymbolsTwemote(name: name) {
            symbolsTwemote
        } else if let natureTwemote = Constants.NatureTwemote(name: name) {
            natureTwemote
        } else if let foodTwemote = Constants.FoodTwemote(name: name) {
            foodTwemote
        } else if let flagsTwemote = Constants.FlagsTwemote(name: name) {
            flagsTwemote
        } else if name == "+1" {
            .thumbsUp
        } else if name == "-1" {
            .thumbsDown
        } else {
            nil
        }
    }

    var body: some View {
        renderedText
    }
}

@available(iOS 17, *)
#Preview(traits: .sizeThatFitsLayout) {
    CommentText("Hello :+1: hang :unknown:")
}
