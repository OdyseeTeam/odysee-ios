//
//  CommentsViewModel.swift
//  Odysee
//
//  Created by Keith on 18/08/2026.
//

import Foundation

@available(iOS 16, *)
extension Comments {
    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var inProgress = false

        private var authors: [String: Claim] = [:]

        func author(for comment: Comment) -> Claim {
            guard let authorUrl = comment.channelUrl,
                  let author = authors[authorUrl]
            else {
                return Claim()
            }

            return author
        }

        func listComments(params: CommentListParams) async throws -> Page<Comment> {
            inProgress = true
            defer {
                inProgress = false
            }

            let list = try await CommentsMethods.list.call(params: params)

            try await resolveNewAuthors(newComments: list.items)

            return list
        }

        private func resolveNewAuthors(newComments: [Comment]) async throws {
            let newAuthors = Array(Set(newComments.compactMap(\.channelUrl)).subtracting(Set(authors.keys)))

            let resolve = try await BackendMethods.resolve.call(params: .init(
                urls: newAuthors
            ))

            authors.merge(resolve.claims, uniquingKeysWith: { _, last in last })
        }
    }
}
