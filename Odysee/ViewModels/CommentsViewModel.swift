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
        // FIXME: Unacceptable
        // Gets updated with default channel
        @Published var channel: Claim = .anonymous
        @Published var postText: String = ""

        static let pageSize = 10
        private var page = 1
        @Published private(set) var isLastPage = false
        @Published private(set) var comments: [Comment] = []
        @Published private(set) var totalComments: Int?

        private var authors: [String: Claim] = [:]

        var sortBy: SortBy = .best {
            didSet {
                Task {
                    comments.removeAll(keepingCapacity: true)
                    page = 1
                    isLastPage = false
                    totalComments = nil

                    await loadPage()
                }
            }
        }

        @Published private(set) var inProgress = false

        func author(for comment: Comment) -> Claim {
            guard let authorUrl = comment.channelUrl,
                  let author = authors[authorUrl]
            else {
                return Claim()
            }

            return author
        }

        func loadPage() async {
            do {
                let list = try await listComments(page: page, sortBy: sortBy.param)

                comments.append(contentsOf: list.items)
                isLastPage = list.isLastPage

                totalComments = list.totalItems

                page += 1
            } catch {
                Helper.showError(error: error)
            }
        }

        /// List either toplevel comments or replies
        ///
        /// Top level: `parentId = nil, sortBy = <choice>`
        /// Replies: `parentId = <id>, sortBy = .oldest`
        func listComments(
            parentId: Comment.ID? = nil,
            page: Int,
            sortBy: CommentListParams.Sort = .oldest
        ) async throws -> Page<Comment> {
            inProgress = true
            defer {
                inProgress = false
            }

            let list = try await CommentsMethods.list.call(params: .init(
                claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8",
//                claimId: "989f7977d0394ec45389ba05c50109dd958b655e",
                parentId: parentId,
                page: page,
                pageSize: Self.pageSize,
                topLevel: parentId == nil,
                sortBy: sortBy
            ))

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

            // FIXME: with ChannelPicker async
//            if let claimId = channel.claimId, let name = channel.name {
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
