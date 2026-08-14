//
//  CommentListItem.swift
//  Odysee
//
//  Created by Keith on 05/08/2026.
//

import SwiftUI

// FIXME: Accessibility
struct CommentListItem: View {
    var comment: Comment
    var author: Claim

    @ScaledMetric private var scale: CGFloat = 1
    @ScaledMetric private var contentSize: CGFloat = 14
    @ScaledMetric private var secondarySize: CGFloat = 12

    @State private var unlimitedLines: Bool = false

    @Environment(\.replyCount) var replyCount
    @Environment(\.repliesExpanded) var repliesExpanded
    @Environment(\.toggleReplies) var toggleReplies

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ChannelThumbnail(claim: author)

            VStack(alignment: .leading) {
                HStack {
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

                // FIXME: Accessibility
                Button {
                    unlimitedLines.toggle()
                } label: {
                    Text(.init(comment.comment))
                        .lineLimit(unlimitedLines ? nil : 2)
                        .font(.system(size: contentSize))
                }

                HStack(spacing: 32) {
                    Button("Reply") {}
                        .buttonStyle(.borderless)

                    Button {} label: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(comment.isLiked ? Color(Helper.fireActiveColor) : .primary)
                        Text(String(comment.numLikes))
                    }

                    Button {} label: {
                        Image("slime")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18 * scale, height: 18 * scale)
                            .foregroundStyle(comment.isDisliked ? Color(Helper.slimeActiveColor) : .primary)
                        Text(String(comment.numDislikes))
                    }
                }

                if let toggleReplies {
                    Button {
                        toggleReplies()
                    } label: {
                        HStack {
                            Text(repliesExpanded ? "Hide replies" : "Show ^[\(replyCount) reply](inflect: true)")

                            Image(systemName: repliesExpanded ? "chevron.up" : "chevron.down")
                        }
                    }
                    .foregroundStyle(.accentColor)
                }
            }

            Spacer()
        }
        .buttonStyle(.plain)
        .contextMenu {
            // FIXME: Items
        }
    }
}

@available(iOS 17, *)
#Preview {
    let comment = Comment(
        comment: "A comment",
        id: "identifier",
        claimId: "",
        timestamp: Date().timeIntervalSince1970
    )

    let author = Claim(
        claimId: "comment-author",
        value: .init(
            title: "the author",
            thumbnail: .init(url: "https://thumbs.odycdn.com/5a920753363de87d6f1f4b0d90b44706.webp")
        )
    )

    CommentListItem(comment: comment, author: author)
}
