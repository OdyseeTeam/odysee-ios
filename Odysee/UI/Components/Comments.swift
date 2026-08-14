//
//  Comments.swift
//  Odysee
//
//  Created by Keith on 31/07/2026.
//

import SwiftUI

@available(iOS 16, *)
struct Comments: View {
    @StateObject private var model: ViewModel = .init()
    @State var expanded: Set<Comment.ID> = .init()

    var body: some View {
        CommentsList(
            commentsByParent: model.commentsByParent,
            authors: model.authors,
            expanded: $expanded,
            model: model
        )
    }
}

@available(iOS 16, *)
extension Comments {
    // FIXME: Loading etc
    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var commentsByParent: [String?: [Comment]] = [:]
        @Published private(set) var authors: [String: Claim] = [:]

        /// <https://github.com/OdyseeTeam/commentron/blob/e8381c3b1f482c83922f4051dc01848afacce499/commentapi/comment.go#L151>
        static let pageSize = 200

        init() {
            Task<Void, Never> {
                do {
                    let page = try await CommentsMethods.list.call(params: .init(
                        claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8",
//                        claimId: "989f7977d0394ec45389ba05c50109dd958b655e",
                        page: 1,
                        pageSize: 50
                    ))

                    try await addCommentsToParent(parentId: nil, comments: page.items)
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

        func loadReplies(comment: Comment) async throws {
            var replies = [Comment]()

            for page in 1 ... 999 {
                let list = try await CommentsMethods.list.call(params: .init(
                    claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8",
//                    claimId: "989f7977d0394ec45389ba05c50109dd958b655e",
                    parentId: comment.id,
                    page: page,
                    pageSize: Self.pageSize,
                    topLevel: false,
                    sortBy: 1
                ))

                replies.append(contentsOf: list.items)

                if list.isLastPage {
                    break
                }
            }

            try await addCommentsToParent(parentId: comment.id, comments: replies)
        }
    }
}

@available(iOS 16, *)
#Preview {
    Comments()
}
