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
        @Published var replyTo: Comment?

        @Published private(set) var totalItems: Int?
        private var authors: [String: Claim] = [:]

        @Published var sortBy: SortBy = .best

        @Published private(set) var inProgress = false

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

            totalItems = list.totalItems

            async let a = resolveNewAuthors(newComments: list.items)
            async let r = loadCommentReactions(comments: list.items)

            let (_, reactions) = try await (a, r)

            let comments = updateCommentReactions(comments: list.items, reactions: reactions)
                .filter {
                    if let authorUrl = $0.channelUrl, authors[authorUrl] != nil {
                        return true
                    }

                    return false
                }

            return Page(items: comments, isLastPage: list.isLastPage)
        }

        private func resolveNewAuthors(newComments: [Comment]) async throws {
            let newAuthors = Array(Set(newComments.compactMap(\.channelUrl)).subtracting(Set(authors.keys)))

            let resolve = try await BackendMethods.resolve.call(params: .init(
                urls: newAuthors
            ))

            authors.merge(resolve.claims, uniquingKeysWith: { _, last in last })
        }

        private func loadCommentReactions(comments: [Comment]) async throws -> ReactListResult {
            var params: CommentReactListParams = .init(
                commentIds: comments.map(\.id).joined(separator: ",")
            )

            // FIXME: Current channel
//            if channels.count > currentCommentAsIndex, currentCommentAsIndex > -1 {
//                let channel = channels[currentCommentAsIndex]
//                guard let claimId = channel.claimId, let name = channel.name else {
//                    Helper.showError(message: "couldn't get channel claimId and/or name")
//                    return
//                }
//                do {
//                    let channelSign = try await BackendMethods.channelSign.call(params: .init(
//                        channelId: claimId,
//                        hexdata: Helper.strToHex(name)
//                    ))
//
//                    params.channelName = name
//                    params.channelId = claimId
//                    params.signature = channelSign.signature
//                    params.signingTs = channelSign.signingTs
//                } catch {
//                    Helper.showError(message: "couldn't get channel signature for loading reactions")
//                    return
//                }
//            }

            return try await CommentsMethods.reactList.call(params: params)
        }

        /// Non-async function to update comments after both async network calls finish
        private func updateCommentReactions(comments: [Comment], reactions: ReactListResult) -> [Comment] {
            comments.map { comment in
                var comment = comment

                if let other = reactions.othersReactions[comment.id] {
                    comment.numLikes = other.like
                    comment.numDislikes = other.dislike
                }

                if let mine = reactions.myReactions?[comment.id] {
                    comment.numLikes += mine.like
                    comment.numDislikes += mine.dislike
                    comment.isLiked = mine.like > 0
                    comment.isDisliked = mine.dislike > 0
                }

                return comment
            }
        }

        // FIXME: Localize
        enum SortBy: String, CaseIterable, Identifiable {
            case best
            case controversial
            case new

            var id: String { rawValue }

            var param: CommentListParams.Sort {
                switch self {
                case .best:
                    .popularity
                case .controversial:
                    .controversy
                case .new:
                    .newest
                }
            }
        }
    }
}
