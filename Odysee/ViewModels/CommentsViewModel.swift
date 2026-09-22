//
//  CommentsViewModel.swift
//  Odysee
//
//  Created by Keith on 18/08/2026.
//

import Foundation
import TaskGate

@available(iOS 16, *)
extension Comments {
    @MainActor
    class ViewModel: ObservableObject {
        var claimId: String

        init(claimId: String) {
            self.claimId = claimId
        }

        @Published var replyTo: Comment?
        @Published var channel: Claim? {
            didSet {
                Task {
                    do {
                        try await reloadCommentReactions()
                    } catch {
                        Helper.showError(error: error)
                    }
                }
            }
        }

        @Published var postText: String = ""

        static let pageSize = 10
        private var page = 1
        @Published private(set) var isLastPage = false
        @Published private(set) var inProgress = false
        @Published private(set) var comments: [Comment] = []
        @Published private(set) var totalComments: Int?

        private var authors: [String: Claim] = [:]

        // FIXME: (iOS 18): replace with Mutex
        /// Protected by `gate`
        @Published private var allReactions: [Comment.ID: CommentReactions] = [:]
        private let gate = AsyncGate()

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

        func author(for comment: Comment) -> Claim {
            guard let authorUrl = comment.channelUrl,
                  let author = authors[authorUrl]
            else {
                return Claim()
            }

            return author
        }

        func reactions(for comment: Comment) -> CommentReactions {
            guard let reactions = allReactions[comment.id] else {
                return .init(numLikes: 0, numDislikes: 0)
            }

            return reactions
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
                //                claimId: "80d2590ad04e36fb1d077a9b9e3a8bba76defdf8",
                claimId: "989f7977d0394ec45389ba05c50109dd958b655e",
                parentId: parentId,
                page: page,
                pageSize: Self.pageSize,
                topLevel: parentId == nil,
                sortBy: sortBy
            ))

            async let a = resolveNewAuthors(newComments: list.items)
            // FIXME: Force channel before load (meaning before load comments)
            // If have channels/is signed in
            // Main thing is stopping this race condition where comments aren't done loading before channel updates the first time
            // It probably isn't an issue with comments not the first screen loaded (before prefs init)
            // FIXME: (CommentListItem): load reactions for that comment before updating reactions, in case "my" reaction isn't loaded
            async let r = loadCommentReactions(commentIds: list.items.map(\.id))

            let _ = try await (a, r)

            let comments = list.items
                .filter {
                    if let authorUrl = $0.channelUrl, authors[authorUrl] != nil {
                        return true
                    }

                    return false
                }
            // FIXME: Maybe filter duplicates

            return Page(items: comments, isLastPage: list.isLastPage)
        }

        private func resolveNewAuthors(newComments: [Comment]) async throws {
            let newAuthors = Array(Set(newComments.compactMap(\.channelUrl)).subtracting(Set(authors.keys)))

            let resolve = try await BackendMethods.resolve.call(params: .init(
                urls: newAuthors
            ))

            authors.merge(resolve.claims, uniquingKeysWith: { _, last in last })
        }

        private func loadCommentReactions(commentIds: [Comment.ID]) async throws {
            var params: CommentReactListParams = .init(
                commentIds: commentIds.joined(separator: ",")
            )

            if let claimId = channel?.claimId, let name = channel?.name {
                do {
                    let channelSign = try await BackendMethods.channelSign.call(params: .init(
                        channelId: claimId,
                        hexdata: Helper.strToHex(name)
                    ))

                    params.channelName = name
                    params.channelId = claimId
                    params.signature = channelSign.signature
                    params.signingTs = channelSign.signingTs
                } catch {
                    Helper.showError(message: "couldn't get channel signature for loading reactions")
                }
            }

            let reactList = try await CommentsMethods.v2_reactList.call(params: params)

            await gate.withGate {
                allReactions.merge(reactList.reactions, uniquingKeysWith: { _, last in last })
            }
        }

        /// Reloads reactions for all current comments, including child threads, using the current channel for "my" reactions
        private func reloadCommentReactions() async throws {
            let commentIds = Array(allReactions.keys)
            guard commentIds.count > 0 else {
                return
            }

            try await loadCommentReactions(commentIds: commentIds)
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
