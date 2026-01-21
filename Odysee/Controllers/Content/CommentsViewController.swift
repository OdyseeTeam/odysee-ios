//
//  CommentsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/01/2021.
//

import CoreActionSheetPicker
import UIKit

class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var noCommentsLabel: UILabel!
    @IBOutlet var postCommentAreaView: UIView!
    @IBOutlet var postCommentAreaHeightConstraint: NSLayoutConstraint!
    @IBOutlet var commentAsThumbnailView: UIImageView!
    @IBOutlet var commentAsChannelLabel: UILabel!
    @IBOutlet var commentLimitLabel: UILabel!
    @IBOutlet var commentInput: UITextView!
    @IBOutlet var commentList: UITableView!
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var channelDriverView: UIView!
    @IBOutlet var channelDriverHeightConstraint: NSLayoutConstraint!
    @IBOutlet var guidelinesTextView: UITextView!

    @IBOutlet var replyToContainerView: UIView!
    @IBOutlet var replyToCommentLabel: UILabel!

    var commentsDisabled: Bool = false
    var commentAsPicker: ActionSheetStringPicker?
    var claimId: String?
    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var currentReplyToComment: Comment?
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var postingComment: Bool = false
    var channels: [Claim] = Lbry.ownChannels
    var comments: [Comment] = []
    var authorThumbnailMap = [String: URL]()
    var isChannelComments = false
    var reacting = false

    var currentCommentAsIndex = -1

    // From notification
    var currentCommentIsReply: Bool = false
    var currentCommentId: String?
    var hasScrolledToCurrentComment: Bool = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !Lbryio.isSignedIn() || commentsDisabled {
            postCommentAreaView.isHidden = true
            postCommentAreaHeightConstraint.constant = 0
        }

        if Lbryio.isSignedIn() {
            loadChannels()
        }
        if comments.count == 0, !commentsDisabled {
            loadComments()
        }
        if currentCommentIsReply, currentCommentId != nil {
            Task { await loadCurrentCommentThread() }
        }
    }

    func resetCommentList() {
        commentList.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view
        commentAsThumbnailView.rounded()

        commentInput.layer.borderColor = UIColor.systemGray5.cgColor
        commentInput.layer.borderWidth = 1
        commentInput.layer.cornerRadius = 1

        loadingContainer.layer.cornerRadius = 20

        titleLabel.text = isChannelComments ? String.localized("Community") : String.localized("Comments")
        closeButton.isHidden = isChannelComments

        if commentsDisabled {
            noCommentsLabel.text = String.localized("Comments are disabled.")
            noCommentsLabel.isHidden = false
            commentList.isHidden = true
        }

        let guidelinesString = String.localized(
            "By continuing, you accept the Odysee Terms of Service and community guidelines."
        )
        let attributed = try? NSMutableAttributedString(
            data: guidelinesString.data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        guidelinesTextView.attributedText = attributed
        guidelinesTextView.textColor = .label
        guidelinesTextView.font = .systemFont(ofSize: 12)
        if UserDefaults.standard.integer(forKey: Helper.keyPostedCommentHideTos) != 0 {
            guidelinesTextView.heightAnchor.constraint(equalToConstant: 0).isActive = true
        }

        Task {
            let defaultChannelId = await Wallet.shared.defaultChannelId
            let index = channels.firstIndex { $0.claimId == defaultChannelId } ?? 0
            if channels.count > index, currentCommentAsIndex == -1 {
                currentCommentAsIndex = index
                updateCommentAsChannel(index)
            }

            for await blocked in await Wallet.shared.sBlocked {
                guard let blocked = blocked?.map(\.claimId) else {
                    continue
                }

                comments.removeAll { blocked.contains($0.channelId) }
                commentList.reloadData()
            }
        }

        if comments.count > 0 {
            // comments already preloaded
            loadCommentReactions(commentIds: comments.compactMap(\.commentId))
        }

        channelDriverView.isHidden = channels.count > 0
        channelDriverHeightConstraint.constant = channels.count > 0 ? 0 : 68
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
     }
     */

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "comment_cell",
            for: indexPath
        ) as! CommentTableViewCell

        if comments.count > indexPath.row {
            let comment = comments[indexPath.row]
            cell.setComment(comment: comment)
            cell.setAuthorImageMap(map: authorThumbnailMap)
            cell.viewController = self
        }

        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? CommentTableViewCell else {
            return
        }
        if cell.currentComment?.commentId == currentCommentId {
            cell.contentView.backgroundColor = UIColor(named: "commentHighlight")
        } else {
            cell.contentView.backgroundColor = nil
        }
    }

    func loadComments() {
        if commentsLoading {
            return
        }

        guard let claimId else {
            showError(message: "couldn't get claimId")
            return
        }

        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }
        commentsLoading = true
        Lbry.commentApiCall(
            method: CommentsMethods.list,
            params: .init(
                claimId: claimId,
                page: commentsCurrentPage,
                pageSize: commentsPageSize,
                skipValidation: true
            )
        )
        .subscribeResult { result in
            Task {
                self.loadingContainer.isHidden = true
                switch result {
                case let .failure(error):
                    self.showError(error: error)
                case let .success(page):
                    self.commentsLastPageReached = page.isLastPage
                    var loadedComments = page.items.filter {
                        comment in !self.comments.contains(where: { $0.commentId == comment.commentId })
                    }
                    if let blocked = (await Wallet.shared.blocked)?.map(\.claimId) {
                        loadedComments.removeAll { blocked.contains($0.channelId) }
                    }
                    self.comments.append(contentsOf: loadedComments)

                    if loadedComments.count > 0 {
                        self.loadCommentReactions(commentIds: loadedComments.compactMap(\.commentId))
                    }
                    // resolve author map
                    if self.comments.count > 0 {
                        self.resolveCommentAuthors(urls: loadedComments.compactMap(\.channelUrl))
                    }

                    self.commentsLoading = false
                    self.commentList.reloadData()
                    self.checkNoComments()

                    if self.currentCommentId != nil && !self.currentCommentIsReply {
                        if !self.commentsLastPageReached && !self.comments.contains(where: {
                            $0.commentId == self.currentCommentId
                        }) {
                            self.commentsCurrentPage += 1
                            self.loadComments()
                        } else if !self.hasScrolledToCurrentComment {
                            self.scrollToCurrentComment()
                        }
                    }
                }
            }
        }
    }

    func scrollToCurrentComment() {
        if let currentCommentIndex = comments.firstIndex(where: { $0.commentId == currentCommentId }) {
            let indexPath = IndexPath(row: currentCommentIndex, section: 0)
            commentList.scrollToRow(at: indexPath, at: .top, animated: true)
            hasScrolledToCurrentComment = true
        } else {
            showError(message: String.localized("Comment could not be found"))
        }
    }

    func resolveCommentAuthors(urls: [String]) {
        Lbry.apiCall(
            method: BackendMethods.resolve,
            params: .init(urls: urls)
        )
        .subscribeResult(didResolveCommentAuthors)
    }

    func didResolveCommentAuthors(_ result: Result<ResolveResult, Error>) {
        guard case let .success(resolve) = result else {
            return
        }
        Helper.addThumbURLs(claims: resolve.claims, thumbURLs: &authorThumbnailMap)
        commentList.reloadData()
    }

    func loadChannels() {
        if channels.count > 0 {
            return
        }

        Lbry.apiCall(
            method: BackendMethods.claimList,
            params: .init(
                claimType: [.channel],
                page: 1,
                pageSize: 999,
                resolve: true
            )
        )
        .subscribeResult(didLoadChannels)
    }

    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        guard case let .success(page) = result else {
            return
        }
        channels.removeAll(keepingCapacity: true)
        channels.append(contentsOf: page.items)
        Lbry.ownChannels = channels
        if currentCommentAsIndex != -1, !channels.isEmpty {
            currentCommentAsIndex = 0
            updateCommentAsChannel(0)
        }
        channelDriverView.isHidden = channels.count > 0
        channelDriverHeightConstraint.constant = channels.count > 0 ? 0 : 68
        if let picker = commentAsPicker {
            // Hacky, but this path (empty picker -> load channels) should be very rare
            // TODO: Reload picker action sheet
            picker.hideWithCancelAction()
            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(1))) {
                self.commentAsTapped(self)
            }
        }
    }

    func checkNoComments() {
        DispatchQueue.main.async {
            self.noCommentsLabel.isHidden = self.comments.count > 0
        }
    }

    @IBAction func commentAsTapped(_ sender: Any) {
        commentInput.resignFirstResponder()

        commentAsPicker = Helper.showPickerActionSheet(
            title: String.localized("Comment as"),
            origin: commentAsChannelLabel,
            rows: channels.map { $0.name ?? "" },
            initialSelection: max(0, min(currentCommentAsIndex, channels.count - 1))
        ) { _, selectedIndex, _ in
            let prevIndex = self.currentCommentAsIndex
            self.currentCommentAsIndex = selectedIndex
            if prevIndex != self.currentCommentAsIndex {
                self.updateCommentAsChannel(self.currentCommentAsIndex)
            }
        }
    }

    @IBAction func anywhereTapped(_ sender: Any) {
        commentInput.resignFirstResponder()
    }

    @IBAction func postCommentTapped(_ sender: UIButton) {
        commentInput.resignFirstResponder()
        UserDefaults.standard.set(1, forKey: Helper.keyPostedCommentHideTos)

        guard !postingComment else {
            return
        }

        guard channels.count > 0 else {
            showError(message: String.localized("You need to create a channel before you can post comments"))
            return
        }
        guard channels.count > currentCommentAsIndex else {
            showError(message: String.localized("Invalid selected channel index. Try selecting the channel again."))
            return
        }
        guard currentCommentAsIndex > -1 else {
            showError(message: String.localized("No channel selected. This is probably a bug."))
            return
        }

        guard let commentText = commentInput.text else {
            showError(message: String.localized("Please enter a comment"))
            return
        }

        guard commentText.count <= Helper.commentMaxLength else {
            showError(message: String.localized("Your comment is too long"))
            return
        }

        postingComment = true
        loadingContainer.isHidden = false
        let channel = channels[currentCommentAsIndex]
        guard let channelId = channel.claimId, let claimId = claimId else {
            showError(message: "couldn't get channelId and/or claimId")
            return
        }
        Lbry.apiCall(
            method: BackendMethods.channelSign,
            params: .init(
                channelId: channelId,
                hexdata: Helper.strToHex(commentText)
            )
        )
        .flatMap { channelSignResult in
            Lbry.commentApiCall(
                method: CommentsMethods.create,
                params: .init(
                    claimId: claimId,
                    channelId: channelId,
                    signature: channelSignResult.signature,
                    signingTs: channelSignResult.signingTs,
                    comment: commentText,
                    parentId: self.currentReplyToComment?.commentId
                )
            )
        }
        .subscribeResult { result in
            self.postingComment = false
            self.loadingContainer.isHidden = true
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case var .success(comment):
                if let currentReplyToComment = self.currentReplyToComment {
                    if currentReplyToComment.repliesLoaded ?? false {
                        if let parentIndex = self.comments.firstIndex(where: {
                            $0.commentId == currentReplyToComment.commentId
                        }) {
                            var currentComment: Comment? = comment
                            while let currentComment_ = currentComment {
                                comment.replyDepth += 1
                                currentComment = self.comments.first(where: {
                                    $0.commentId == currentComment_.parentId
                                })
                            }
                            self.comments.insert(comment, at: parentIndex + 1)
                            self.commentList.insertRows(
                                at: [IndexPath(row: parentIndex + 1, section: 0)],
                                with: .automatic
                            )
                        }
                    } else {
                        self.loadReplies(currentReplyToComment)
                    }
                } else {
                    self.comments.insert(comment, at: 0)
                    self.commentList.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                }

                if let channelUrl = comment.channelUrl {
                    // TODO: Reactions not loaded here as comment might not be available?
                    self.resolveCommentAuthors(urls: [channelUrl])
                }

                self.commentInput.text = ""
                self.replyToCommentLabel.text = ""
                self.replyToContainerView.isHidden = true
                self.textViewDidChange(self.commentInput)
                self.checkNoComments()

                self.currentReplyToComment = nil
            }
        }
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        if let parentvc = parent as? FileViewController {
            parentvc.closeCommentsView()
        }
    }

    @IBAction func channelDriverTapped(_ sender: Any) {
        if UIApplication.currentViewController() is FileViewController {
            AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
        }
        let vc = storyboard?.instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
        vc.commentsVc = self
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if commentList.contentOffset.y >= (commentList.contentSize.height - commentList.bounds.size.height) {
            if !commentsLoading, !commentsLastPageReached {
                commentsCurrentPage += 1
                loadComments()
            }
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView == commentInput {
            let length = commentInput.text.count
            commentLimitLabel.text = "\(length) / \(Helper.commentMaxLength)"
        }
    }

    func loadCommentReactions(commentIds: [String]) {
        let handler: (Result<ReactListResult, Error>) -> Void = { result in
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case let .success(reactions):
                var combined = [String: CombinedReactionData]()
                if let othersReactions = reactions.othersReactions {
                    for (commentId, reactionData) in othersReactions {
                        combined[commentId] = CombinedReactionData(
                            othersLike: reactionData.like, othersDislike: reactionData.dislike
                        )
                    }
                }
                if let myReactions = reactions.myReactions {
                    for (commentId, reactionData) in myReactions {
                        if combined[commentId] != nil {
                            combined[commentId]?.myLike = reactionData.like
                            combined[commentId]?.myDislike = reactionData.dislike
                        } else {
                            combined[commentId] = CombinedReactionData(
                                myLike: reactionData.like, myDislike: reactionData.dislike
                            )
                        }
                    }
                }
                for (commentId, combinedReactionData) in combined {
                    self.updateCommentReactions(commentId: commentId, combined: combinedReactionData)
                }
                self.commentList.reloadData()
            }
        }

        if currentCommentAsIndex == -1 || channels.count == 0 || channels.count <= currentCommentAsIndex {
            Lbry.commentApiCall(
                method: CommentsMethods.reactList,
                params: .init(commentIds: commentIds.joined(separator: ","))
            )
            .subscribeResult(handler)
        } else {
            let channel = channels[currentCommentAsIndex]
            guard let claimId = channel.claimId, let name = channel.name else {
                showError(message: "couldn't get channel claimId and/or name")
                return
            }
            Lbry.apiCall(
                method: BackendMethods.channelSign,
                params: .init(
                    channelId: claimId,
                    hexdata: Helper.strToHex(name)
                )
            )
            .flatMap { channelSignResult in
                Lbry.commentApiCall(
                    method: CommentsMethods.reactList,
                    params: .init(
                        commentIds: commentIds.joined(separator: ","),
                        channelName: name,
                        channelId: claimId,
                        signature: channelSignResult.signature,
                        signingTs: channelSignResult.signingTs
                    )
                )
            }
            .subscribeResult(handler)
        }
    }

    func updateCommentReactions(commentId: String, combined: CombinedReactionData) {
        for i in comments.indices {
            if comments[i].commentId == commentId {
                comments[i].numLikes = (combined.othersLike ?? 0) + ((combined.myLike ?? 0) > 0 ? 1 : 0)
                comments[i].numDislikes = (combined.othersDislike ?? 0) + ((combined.myDislike ?? 0) > 0 ? 1 : 0)
                comments[i].isLiked = combined.myLike ?? 0 > 0
                comments[i].isDisliked = combined.myDislike ?? 0 > 0
            }
        }
    }

    func react(_ comment: Comment, type: String) {
        guard Lbryio.isSignedIn() else {
            showUAView()
            return
        }

        guard channels.count > 0 else {
            showError(message: String.localized("You need to create a channel before you can react to comments"))
            return
        }
        guard channels.count > currentCommentAsIndex else {
            showError(message: String.localized("Invalid selected channel index. Try selecting the channel again."))
            return
        }
        guard currentCommentAsIndex > -1 else {
            showError(message: String.localized("No channel selected. This is probably a bug."))
            return
        }

        guard !reacting else {
            return
        }

        reacting = true
        let remove = (type == Helper.reactionTypeLike && (comment.isLiked ?? false)) ||
            (type == Helper.reactionTypeDislike && (comment.isDisliked ?? false)) ? true : false
        let channel = channels[currentCommentAsIndex]

        guard let claimId = channel.claimId, let name = channel.name else {
            showError(message: "couldn't get channel claimId and/or name")
            return
        }
        guard let commentId = comment.commentId else {
            showError(message: "couldn't get commentId")
            return
        }

        var updatedComment = comment
        if type == Helper.reactionTypeLike {
            updatedComment.isLiked = !remove
            updatedComment.numLikes = (updatedComment.numLikes ?? 0) + (remove ? -1 : 1)
            if !remove, updatedComment.isDisliked ?? false {
                updatedComment.numDislikes = (updatedComment.numDislikes ?? 1) - 1
                updatedComment.isDisliked = false
            }
        }
        if type == Helper.reactionTypeDislike {
            updatedComment.isDisliked = !remove
            updatedComment.numDislikes = (updatedComment.numDislikes ?? 0) + (remove ? -1 : 1)
            if !remove, updatedComment.isLiked ?? false {
                updatedComment.numLikes = (updatedComment.numLikes ?? 1) - 1
                updatedComment.isLiked = false
            }
        }
        updateSingleCommentReactions(updatedComment)

        Lbry.apiCall(
            method: BackendMethods.channelSign,
            params: .init(channelId: claimId, hexdata: Helper.strToHex(name))
        )
        .flatMap { channelSignResult in
            Lbry.commentApiCall(
                method: CommentsMethods.react,
                params: .init(
                    commentIds: commentId,
                    signature: channelSignResult.signature,
                    signingTs: channelSignResult.signingTs,
                    remove: remove,
                    clearTypes: type == Helper.reactionTypeLike ? Helper.reactionTypeDislike : Helper.reactionTypeLike,
                    type: type,
                    channelId: claimId,
                    channelName: name
                )
            )
        }
        .subscribeResult { result in
            if case let .failure(error) = result {
                self.showError(error: error)
                // Set reactions back to original value
                self.updateSingleCommentReactions(comment)
            }
            self.reacting = false
        }
    }

    func updateSingleCommentReactions(_ comment: Comment) {
        var commentUpdated = false
        for i in comments.indices {
            if comments[i].commentId == comment.commentId {
                comments[i].numLikes = comment.numLikes
                comments[i].numDislikes = comment.numDislikes
                comments[i].isLiked = comment.isLiked
                comments[i].isDisliked = comment.isDisliked
                commentUpdated = true
                break
            }
        }

        if commentUpdated {
            DispatchQueue.main.async {
                self.commentList.reloadData()
            }
        }
    }

    func loadReplies(_ parent: Comment) {
        if commentsLoading {
            return
        }

        guard let claimId, let parentId = parent.commentId else {
            showError(message: "couldn't get claimId and/or parent commentId")
            return
        }

        commentsLoading = true
        loadingContainer.isHidden = false
        Lbry.commentApiCall(
            method: CommentsMethods.list,
            params: .init(
                claimId: claimId,
                parentId: parentId,
                page: 1,
                pageSize: 999,
                skipValidation: true,
                topLevel: false
            )
        )
        .subscribeResult { result in
            self.loadingContainer.isHidden = true
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case let .success(page):
                let loadedComments = page.items.filter {
                    comment in !self.comments.contains(where: { $0.commentId == comment.commentId })
                }.map { comment in
                    var comment = comment
                    var currentComment: Comment? = comment
                    while let currentComment_ = currentComment {
                        comment.replyDepth += 1
                        currentComment = self.comments.first(where: { $0.commentId == currentComment_.parentId })
                    }
                    return comment
                }

                if let parentIndex = self.comments.firstIndex(where: {
                    $0.commentId == parent.commentId
                }), loadedComments.count > 0 {
                    self.comments.insert(contentsOf: loadedComments, at: parentIndex + 1)
                    self.commentList.insertRows(
                        at: Array(parentIndex + 1 ... parentIndex + loadedComments.count).map {
                            IndexPath(row: $0, section: 0)
                        },
                        with: .automatic
                    )
                    self.loadCommentReactions(commentIds: loadedComments.compactMap(\.commentId))
                    self.resolveCommentAuthors(urls: loadedComments.compactMap(\.channelUrl))
                }

                self.commentsLoading = false
                self.setCommentRepliesLoaded(parent)
            }
        }
    }

    func loadCurrentCommentThread() async {
        guard let currentCommentId else {
            Helper.showError(message: "couldn't get current commentId")
            return
        }
        guard let claimId else {
            Helper.showError(message: "couldn't get claimId")
            return
        }

        loadingContainer.isHidden = false

        do {
            let byId = try await CommentsMethods.byId.call(params: .init(
                commentId: currentCommentId, withAncestors: true
            ))

            guard let ancestors = byId.ancestors else {
                throw GenericError(String.localized("Comment could not be found"))
            }

            if let parent = ancestors.last, !comments.contains(where: { $0.commentId == parent.commentId }) {
                comments.insert(parent, at: 0)
                commentList.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            }

            for comment in ancestors.reversed() {
                guard let parentId = comment.commentId else {
                    throw GenericError("couldn't get parent commentId")
                }

                let page = try await CommentsMethods.list.call(params: .init(
                    claimId: claimId,
                    parentId: parentId,
                    page: 1,
                    pageSize: 999,
                    skipValidation: true,
                    topLevel: false
                ))

                let loadedComments = page.items.filter {
                    comment in !comments.contains(where: { $0.commentId == comment.commentId })
                }.map { comment in
                    var comment = comment
                    var currentComment: Comment? = comment
                    while let currentComment_ = currentComment {
                        comment.replyDepth += 1
                        currentComment = comments.first(where: { $0.commentId == currentComment_.parentId })
                    }
                    return comment
                }

                if let parentIndex = comments.firstIndex(where: { $0.commentId == parentId }),
                   loadedComments.count > 0
                {
                    comments.insert(contentsOf: loadedComments, at: parentIndex + 1)
                    commentList.insertRows(
                        at: Array(parentIndex + 1 ... parentIndex + loadedComments.count).map {
                            IndexPath(row: $0, section: 0)
                        },
                        with: .automatic
                    )
                    loadCommentReactions(commentIds: loadedComments.compactMap(\.commentId))
                    resolveCommentAuthors(urls: loadedComments.compactMap(\.channelUrl))
                }

                setCommentRepliesLoaded(comment)
            }

            scrollToCurrentComment()
        } catch {
            Helper.showError(error: error)
        }
    }

    func setCommentRepliesLoaded(_ comment: Comment) {
        for i in comments.indices {
            if comments[i].commentId == comment.commentId {
                comments[i].repliesLoaded = true
                break
            }
        }
    }

    func setReplyToComment(_ comment: Comment) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }

        currentReplyToComment = comment

        commentList.setContentOffset(.zero, animated: true)
        replyToCommentLabel.text = comment.comment
        replyToContainerView.isHidden = false
    }

    @IBAction func clearReplyToComment() {
        currentReplyToComment = nil

        replyToContainerView.isHidden = true
        replyToCommentLabel.text = ""
    }

    func updateCommentAsChannel(_ index: Int) {
        guard index > -1, channels.count > index else {
            return
        }

        let channel = channels[index]
        if let name = channel.name {
            commentAsChannelLabel.text = String(format: String.localized("Comment as %@"), name)
        }

        if let thumbnailUrlValue = channel.value?.thumbnail?.url,
           let thumbnailUrl = URL(string: thumbnailUrlValue)?.makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
        {
            commentAsThumbnailView.load(url: thumbnailUrl)
            commentAsThumbnailView.backgroundColor = UIColor.clear
        } else {
            commentAsThumbnailView.image = UIImage(named: "spaceman")
            commentAsThumbnailView.backgroundColor = Helper.lightPrimaryColor
        }
    }

    func showError(error: Error?) {
        AppDelegate.shared.mainController.showError(error: error)
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }

    func showUAView() {
        if UIApplication.currentViewController() is FileViewController {
            AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
        }
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    struct CombinedReactionData {
        var othersLike: Int?
        var othersDislike: Int?
        var myLike: Int?
        var myDislike: Int?
    }
}
