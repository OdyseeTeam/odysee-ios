//
//  CommentsList.swift
//  Odysee
//
//  Created by Keith on 01/08/2026.
//

import SwiftUI

extension EnvironmentValues {
    // MARK: Comments Replies Disclosure Group Style

    @Entry var replyCount: Int = 0
    @Entry var repliesExpanded: Bool = false

    /// When `nil`, means there's no replies (list item isn't in a DisclosureGroup
    ///
    /// Must be set to `nil` to clear, otherwise it's inherited from parent items
    @Entry var toggleReplies: (() -> Void)?

    // MARK: Comments List (Recursive)

    @Entry var parentId: Comment.ID?
}

@available(iOS 16, *)
struct CommentsList: View {
    @Binding var expanded: Set<Comment.ID>
    var comments: [Comment]

    var body: some View {
        CommentListItems(expanded: $expanded, comments: comments)
            .padding(.leading)
            .listRowSeparator(.hidden)
            .listRowInsets(.init())
    }
}

@available(iOS 16, *)
struct CommentsListRecursive: View {
    @Binding var expanded: Set<Comment.ID>

    @EnvironmentObject private var commentsModel: Comments.ViewModel
    @Environment(\.parentId) private var parentId

    @StateObject private var model: ViewModel = .init()

    var body: some View {
        Group {
            CommentListItems(expanded: $expanded, comments: model.replies)

            if !model.isLastPage, let parentId {
                Button("Show more") {
                    Task {
                        await model.loadPage(parentId: parentId, commentsModel: commentsModel)
                    }
                }
                .buttonStyle(.borderless)
                .padding(.top, 16)
                .disabled(commentsModel.inProgress)
                .task {
                    if model.replies.count == 0 {
                        await model.loadPage(parentId: parentId, commentsModel: commentsModel)
                    }
                }
            }
        }
        .padding(.leading)
        .listRowSeparator(.hidden)
        .listRowInsets(.init())
    }
}

@available(iOS 16, *)
private struct CommentListItems: View {
    @Binding var expanded: Set<Comment.ID>

    var comments: [Comment]

    @EnvironmentObject private var commentsModel: Comments.ViewModel

    func binding(for comment: Comment) -> Binding<Bool> {
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

    func collapse(comment: Comment) {
        expanded.remove(comment.id)
    }

    var body: some View {
        ForEach(comments) { comment in
            if comment.replyCount ?? 0 > 0 {
                DisclosureGroup(isExpanded: binding(for: comment)) {
                    CommentsListRecursive(expanded: $expanded)
                        .environment(\.parentId, comment.id)
                        .overlay(alignment: .leading) {
                            Color.accentColor
                                .frame(width: 2)
                                .offset(x: -1)
                                .onTapGesture {
                                    withAnimation {
                                        collapse(comment: comment)
                                    }
                                }
                        }
                } label: {
                    CommentListItem(
                        comment: comment,
                        author: commentsModel.author(for: comment)
                    )
                }
                .disclosureGroupStyle(CommentDisclosureGroupStyle())
                .environment(
                    \.replyCount,
                    comment.replyCount ?? 0,
                )
            } else {
                CommentListItem(
                    comment: comment,
                    author: commentsModel.author(for: comment)
                )
                .environment(\.toggleReplies, nil)
            }
        }
    }
}

/// Places label and content as direct children, to preserve being List items
@available(iOS 16, *)
private struct CommentDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.repliesExpanded, configuration.isExpanded)
            .environment(\.toggleReplies) {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            }

        if configuration.isExpanded {
            configuration.content
        }
    }
}
