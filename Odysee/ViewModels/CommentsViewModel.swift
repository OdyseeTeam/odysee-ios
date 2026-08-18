//
//  CommentsViewModel.swift
//  Odysee
//
//  Created by Keith on 18/08/2026.
//

import Foundation

@available(iOS 16, *)
extension Comments {
    // FIXME: Loading etc
    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var commentsByParent: [String?: Replies] = [:]
        @Published private(set) var authors: [String: Claim] = [:]

        /// <https://github.com/OdyseeTeam/commentron/blob/e8381c3b1f482c83922f4051dc01848afacce499/commentapi/comment.go#L151>
        static let pageSize = 200

        init() {
            Task<Void, Never> {
                do {
                    try await loadTopLevelComments()
                } catch {
                    Helper.showError(error: error)
                    return
                }
            }
        }

        private func addCommentsToParent(parentId: String?, comments: [Comment]) async throws {
            try await resolveNewAuthors(newComments: comments)

            if commentsByParent[parentId] == nil {
                commentsByParent[parentId] = comments
            } else {
                commentsByParent[parentId]?.append(contentsOf: comments)
            }
        }

        private func resolveNewAuthors(newComments: [Comment]) async throws {
            let newAuthors = Array(Set(newComments.compactMap(\.channelUrl)).subtracting(Set(authors.keys)))

            let resolve = try await BackendMethods.resolve.call(params: .init(
                urls: newAuthors
            ))

            authors.merge(resolve.claims, uniquingKeysWith: { _, last in last })
        }

        func loadTopLevelComments() async throws {
            try await loadReplies(comment: nil)
        }

        func loadReplies(comment: Comment?) async throws {
            let pageNum = commentsByParent[comment?.id]?.pageNum ?? 1

            let page = try await CommentsMethods.list.call(params: .init(
                claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8",
                //                    claimId: "989f7977d0394ec45389ba05c50109dd958b655e",
                parentId: comment?.id,
                page: pageNum,
                pageSize: Self.pageSize,
                topLevel: comment?.id == nil,
                sortBy: comment?.id == nil ? .popularity : .oldest
            ))

//            try await addCommentsToParent(parentId: comment?.id, comments: )
        }

        struct Replies {
            var pageNum: Int
            var page: Page<Comment>
        }
    }
}
