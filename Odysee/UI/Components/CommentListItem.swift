//
//  CommentListItem.swift
//  Odysee
//
//  Created by Keith on 05/08/2026.
//

import SwiftUI
import WrappingHStack

// FIXME: Accessibility
@available(iOS 16, *)
struct CommentListItem: View {
    var comment: Comment
    var author: Claim

    @ScaledMetric private var secondarySize: CGFloat = 14
    @ScaledMetric private var secondaryInlineSize: CGFloat = 18

    @State private var unlimitedLines: Bool = false

    @Environment(\.replyCount) var replyCount
    @Environment(\.repliesExpanded) var repliesExpanded
    @Environment(\.toggleReplies) var toggleReplies

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ChannelThumbnail(claim: author)

            VStack(alignment: .leading) {
                WrappingHStack(lineSpacing: 8) {
                    if let authorTitle = author.titleOrName {
                        Button {
                            Helper.openChannelVc(author)
                        } label: {
                            Text(authorTitle)
                                .lineLimit(1)
                                .apply {
                                    if #available(iOS 16, *) {
                                        $0.fontWeight(.semibold)
                                    } else {
                                        $0
                                    }
                                }
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(Helper.formatTimestamp(comment.timestamp))
                }
                .font(.system(size: secondarySize))

                if let sticker = CommentSticker.parse(comment.comment) {
                    CommentSticker(sticker: sticker)
                } else {
                    // FIXME: Accessibility
                    Button {
                        unlimitedLines.toggle()
                    } label: {
                        // FIXME: Timestamp click
                        CommentText(comment.comment)
                            .lineLimit(unlimitedLines ? nil : 2)
                    }
                }

                WrappingHStack(spacing: .constant(32), lineSpacing: 8) {
                    Button("Reply") {}
                        .buttonStyle(.borderless)

                    HStack(spacing: 32) {
                        Button {} label: {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(comment.isLiked ? Color(Helper.fireActiveColor) : .primary)
                            Text(String(comment.numLikes))
                        }

                        Button {} label: {
                            Image("slime")
                                .resizable()
                                .scaledToFit()
                                .frame(width: secondaryInlineSize, height: secondaryInlineSize)
                                .foregroundStyle(comment.isDisliked ? Color(Helper.slimeActiveColor) : .primary)
                            Text(String(comment.numDislikes))
                        }
                    }
                }
                .font(.system(size: secondarySize))

                if let toggleReplies {
                    Button {
                        toggleReplies()
                    } label: {
                        HStack {
                            Text(repliesExpanded ? "Hide replies" : "Show ^[\(replyCount) reply](inflect: true)")
                                .font(.system(size: secondarySize))

                            Image(systemName: repliesExpanded ? "chevron.up" : "chevron.down")
                        }
                    }
                    .foregroundStyle(.accentColor)
                }
            }

            Spacer()
        }
        .padding(.top, 16)
        .buttonStyle(.plain)
        .contextMenu {
            // FIXME: Items
        }
    }
}

@available(iOS 17, *)
#Preview {
    let author = Claim(
        claimId: "comment-author",
        value: .init(
            title: "the author",
            thumbnail: .init(url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp")
        )
    )

    List {
        CommentListItem(
            comment: Comment(
                comment: "A comment",
                id: "1",
                claimId: "",
                timestamp: Date().timeIntervalSince1970
            ),
            author: author
        )

        CommentListItem(
            comment: Comment(
                comment: "A comment",
                id: "2",
                claimId: "",
                timestamp: Date().timeIntervalSince1970
            ),
            author: Claim()
        )

        CommentListItem(
            comment: Comment(
                comment: "A comment with :+1:",
                id: "3",
                claimId: "",
                timestamp: Date().timeIntervalSince1970
            ),
            author: author
        )
    }
}
