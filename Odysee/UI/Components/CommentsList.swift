//
//  CommentsList.swift
//  Odysee
//
//  Created by Keith on 01/08/2026.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var replyCount: Int = 0
    @Entry var repliesExpanded: Bool = false

    /// When `nil`, means there's no replies (list item isn't in a DisclosureGroup
    ///
    /// Must be set to `nil` to clear, otherwise it's inherited from parent items
    @Entry var toggleReplies: (() -> Void)?
}

@available(iOS 16, *)
struct CommentsList: View {
    let commentsByParent: [String?: [Comment]]
    let authors: [String: Claim]
    @Binding var expanded: Set<Comment.ID>

    @ObservedObject var model: Comments.ViewModel

    var body: some View {
        List {
            Recursive(
                comments: commentsByParent[nil] ?? [],
                commentsByParent: commentsByParent,
                authors: authors,
                expanded: $expanded,
                model: model
            )

            MiniPlayerAvoiding()
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private struct Recursive: View {
        let comments: [Comment]
        let commentsByParent: [String?: [Comment]]
        let authors: [String: Claim]
        @Binding var expanded: Set<Comment.ID>

        @ObservedObject var model: Comments.ViewModel

        @State private var maxShown: Int = 10
        private var shownComments: [Comment] {
            if maxShown < comments.count {
                return Array(comments[..<maxShown])
            } else {
                return comments
            }
        }

        func author(_ comment: Comment) -> Claim {
            guard let authorUrl = comment.channelUrl,
                  let author = authors[authorUrl]
            else {
                return Claim()
            }

            return author
        }

        func makeBinding(_ comment: Comment) -> Binding<Bool> {
            .init {
                expanded.contains(comment.id)
            } set: { newValue in
                if newValue {
                    expanded.insert(comment.id)
                } else {
                    expanded.remove(comment.id)
                }
            }
        }

        var body: some View {
            ForEach(shownComments) { comment in
                if comment.replyCount ?? (commentsByParent[comment.id] ?? []).count > 0 {
                    DisclosureGroup(isExpanded: makeBinding(comment)) {
                        Recursive(
                            comments: commentsByParent[comment.id] ?? [],
                            commentsByParent: commentsByParent,
                            authors: authors,
                            expanded: $expanded,
                            model: model
                        )
                    } label: {
                        CommentListItem(comment: comment, author: author(comment))
                    }
                    .environment(
                        \.replyCount,
                        comment.replyCount ?? (commentsByParent[comment.id] ?? []).count
                    )
                    .task {
                        if (commentsByParent[comment.id] ?? []).isEmpty {
                            do {
                                try await model.loadReplies(comment: comment)
                            } catch {
                                Helper.showError(error: error)
                            }
                        }
                    }
                } else {
                    CommentListItem(comment: comment, author: author(comment))
                        .environment(\.toggleReplies, nil)
                }
            }
            .padding(.leading)
            .disclosureGroupStyle(CommentDisclosureGroupStyle())
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))

            if maxShown < comments.count {
                if shownComments.first?.parentId != nil {
                    Button("Show more") {
                        maxShown += 10
                    }
                    .buttonStyle(.borderless)
                } else {
                    Color.clear
                        .onAppear {
                            maxShown += 10
                        }
                }
            }
        }
    }
}

/// Places label and content as direct children, to preserve being List items
@available(iOS 16, *)
private struct CommentDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.label
                .environment(\.repliesExpanded, configuration.isExpanded)
                .environment(\.toggleReplies) {
                    withAnimation {
                        configuration.isExpanded.toggle()
                    }
                }
        }

        if configuration.isExpanded {
            configuration.content
        }
    }
}

@available(iOS 17, *)
#Preview {
    @Previewable @State var expanded: Set<Comment.ID> = .init(["3", "1"])

    let time = { Double.random(in: 0 ..< Date().timeIntervalSince1970) }
    let commentsByParent: [String?: [Comment]] = [
        nil: [
            .init(comment: "A\na\na\na", id: "1", claimId: "", timestamp: time()),
            .init(comment: "Z", id: "5", claimId: "", timestamp: time()),
            .init(comment: "!", id: "6", claimId: "", timestamp: time())
        ],
        "1": [
            .init(comment: "B", id: "2", claimId: "", timestamp: time(), parentId: "1"),
            .init(comment: "C", id: "3", claimId: "", timestamp: time(), parentId: "1"),
        ],
        "3": [
            .init(comment: "D", id: "4", claimId: "", timestamp: time(), parentId: "3")
        ],
        "6": [
            .init(comment: "@", id: "7", claimId: "", timestamp: time(), parentId: "6")
        ]
    ]

    CommentsList(
        commentsByParent: commentsByParent,
        authors: [:],
        expanded: $expanded,
        model: .init()
    )
}
