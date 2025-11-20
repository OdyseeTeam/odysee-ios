//
//  CommentsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/01/2021.
//

import Combine
import CoreActionSheetPicker
import UIKit

class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate,
    BlockChannelStatusObserver
{
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
            loadCurrentCommentThread()
        }
    }

    func resetCommentList() {
        commentList.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view
        registerForKeyboardNotifications()

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
            data: guidelinesString.data(using: .utf8)!,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        guidelinesTextView.attributedText = attributed
        guidelinesTextView.textColor = .label
        guidelinesTextView.font = .systemFont(ofSize: 12)
        if UserDefaults.standard.integer(forKey: Helper.keyPostedCommentHideTos) != 0 {
            guidelinesTextView.heightAnchor.constraint(equalToConstant: 0).isActive = true
        }

        let index = channels.firstIndex { $0.claimId == Lbry.defaultChannelId } ?? 0
        if channels.count >= index, currentCommentAsIndex == -1 {
            currentCommentAsIndex = index
            updateCommentAsChannel(index)
        }

        if comments.count > 0 {
            // comments already preloaded
            loadCommentReactions(commentIds: comments.map { $0.commentId! })
        }

        channelDriverView.isHidden = channels.count > 0
        channelDriverHeightConstraint.constant = channels.count > 0 ? 0 : 68

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let mainVc = appDelegate.mainViewController as? MainViewController {
            mainVc.addBlockChannelObserver(name: "comments", observer: self)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let mainVc = appDelegate.mainViewController as? MainViewController {
            mainVc.removeBlockChannelObserver(name: "comments")
        }
    }

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
        commentList.contentInset = contentInsets
        commentList.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        commentList.contentInset = contentInsets
        commentList.scrollIndicatorInsets = contentInsets
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

        let comment: Comment = comments[indexPath.row]
        cell.setComment(comment: comment)
        cell.setAuthorImageMap(map: authorThumbnailMap)
        cell.viewController = self

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

        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }
        commentsLoading = true
        Lbry.commentApiCall(
            method: Lbry.CommentMethods.list,
            params: .init(
                claimId: claimId!,
                page: commentsCurrentPage,
                pageSize: commentsPageSize,
                skipValidation: true
            )
        )
        .subscribeResult { result in
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case let .success(page):
                self.commentsLastPageReached = page.isLastPage
                let loadedComments = page.items.filter {
                    comment in !self.comments.contains(where: { $0.commentId == comment.commentId })
                }
                self.comments.append(contentsOf: loadedComments)

                if loadedComments.count > 0 {
                    self.loadCommentReactions(commentIds: loadedComments.map(\.commentId!))
                }
                // resolve author map
                if self.comments.count > 0 {
                    self.resolveCommentAuthors(urls: loadedComments.map(\.channelUrl!))
                }

                self.commentsLoading = false
                self.filterBlockedChannels(false)
                self.loadingContainer.isHidden = true
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
            method: Lbry.Methods.resolve,
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
            method: Lbry.Methods.claimList,
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
            initialSelection: currentCommentAsIndex,
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

        if postingComment {
            return
        }

        if channels.count == 0 {
            showError(message: String.localized("You need to create a channel before you can post comments"))
            return
        }

        if currentCommentAsIndex == -1 {
            showError(message: String.localized("No channel selected. This is probably a bug."))
        }

        if commentInput.text.count > Helper.commentMaxLength {
            showError(message: String.localized("Your comment is too long"))
            return
        }

        postingComment = true
        loadingContainer.isHidden = false
        let channel = channels[currentCommentAsIndex]
        Lbry.apiCall(
            method: Lbry.Methods.channelSign,
            params: .init(
                channelId: channel.claimId!,
                hexdata: Helper.strToHex(commentInput.text!)
            )
        )
        .flatMap { channelSignResult in
            Lbry.commentApiCall(
                method: Lbry.CommentMethods.create,
                params: .init(
                    claimId: self.claimId!,
                    channelId: channel.claimId!,
                    signature: channelSignResult.signature,
                    signingTs: channelSignResult.signingTs,
                    comment: self.commentInput.text!,
                    parentId: self.currentReplyToComment?.commentId
                )
            )
        }
        .subscribeResult { result in
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
                            while let _currentComment = currentComment {
                                comment.replyDepth += 1
                                currentComment = self.comments.first(where: {
                                    $0.commentId == _currentComment.parentId
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
                // TODO: Reactions not loaded here as comment might not be available?
                self.resolveCommentAuthors(urls: [comment.channelUrl!])

                self.postingComment = false
                self.commentInput.text = ""
                self.replyToCommentLabel.text = ""
                self.replyToContainerView.isHidden = true
                self.loadingContainer.isHidden = true
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
        let vc = storyboard?.instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
        vc.commentsVc = self
        navigationController?.pushViewController(vc, animated: true)
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
            commentLimitLabel.text = String(format: "%d / %d", length, Helper.commentMaxLength)
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

        if currentCommentAsIndex == -1 || channels.count == 0 {
            Lbry.commentApiCall(
                method: Lbry.CommentMethods.reactList,
                params: .init(commentIds: commentIds.joined(separator: ","))
            )
            .subscribeResult(handler)
        } else {
            let channel = channels[currentCommentAsIndex]
            Lbry.apiCall(
                method: Lbry.Methods.channelSign,
                params: .init(
                    channelId: channel.claimId!,
                    hexdata: Helper.strToHex(channel.name!)
                )
            )
            .flatMap { channelSignResult in
                Lbry.commentApiCall(
                    method: Lbry.CommentMethods.reactList,
                    params: .init(
                        commentIds: commentIds.joined(separator: ","),
                        channelName: channel.name!,
                        channelId: channel.claimId!,
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
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }

        if channels.count == 0 {
            showError(message: String.localized("You need to create a channel before you can react to comments"))
            return
        }

        if currentCommentAsIndex == -1 {
            showError(message: String.localized("No channel selected. This is probably a bug."))
        }

        if reacting {
            return
        }

        reacting = true
        let remove = (type == Helper.reactionTypeLike && (comment.isLiked ?? false)) ||
            (type == Helper.reactionTypeDislike && (comment.isDisliked ?? false)) ? true : false
        let channel = channels[currentCommentAsIndex]

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
            method: Lbry.Methods.channelSign,
            params: .init(channelId: channel.claimId!, hexdata: Helper.strToHex(channel.name!))
        )
        .flatMap { channelSignResult in
            Lbry.commentApiCall(
                method: Lbry.CommentMethods.react,
                params: .init(
                    commentIds: comment.commentId!,
                    signature: channelSignResult.signature,
                    signingTs: channelSignResult.signingTs,
                    remove: remove,
                    clearTypes: type == Helper.reactionTypeLike ? Helper.reactionTypeDislike : Helper.reactionTypeLike,
                    type: type,
                    channelId: channel.claimId!,
                    channelName: channel.name!
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

        commentsLoading = true
        loadingContainer.isHidden = false
        Lbry.commentApiCall(
            method: Lbry.CommentMethods.list,
            params: .init(
                claimId: claimId!,
                parentId: parent.commentId!,
                page: 1,
                pageSize: 999,
                skipValidation: true,
                topLevel: false
            )
        )
        .subscribeResult { result in
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case let .success(page):
                let loadedComments = page.items.filter {
                    comment in !self.comments.contains(where: { $0.commentId == comment.commentId })
                }.map { comment in
                    var comment = comment
                    var currentComment: Comment? = comment
                    while let _currentComment = currentComment {
                        comment.replyDepth += 1
                        currentComment = self.comments.first(where: { $0.commentId == _currentComment.parentId })
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
                    self.loadCommentReactions(commentIds: loadedComments.map(\.commentId!))
                    self.resolveCommentAuthors(urls: loadedComments.map(\.channelUrl!))
                }

                self.commentsLoading = false
                self.setCommentRepliesLoaded(parent)
                self.loadingContainer.isHidden = true
            }
        }
    }

    func loadCurrentCommentThread() {
        loadingContainer.isHidden = false
        Lbry.commentApiCall(
            method: Lbry.CommentMethods.byId,
            params: .init(
                commentId: currentCommentId!,
                withAncestors: true
            )
        )
        .subscribeResult { result in
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case let .success(result):
                if let ancestors = result.ancestors {
                    if let parent = ancestors.last {
                        if !self.comments.contains(where: { $0.commentId == parent.commentId }) {
                            self.comments.insert(parent, at: 0)
                            self.commentList.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                        }
                    }
                    self.loadThread(thread: ancestors.reversed())
                }
            }
        }
    }

    func loadThread(thread: [Comment]) {
        thread.publisher.subscribe(on: DispatchQueue.global()).tryMap { comment -> (Comment, URLRequest) in
            try (comment, Lbry.apiRequest(
                method: Lbry.CommentMethods.list.name,
                params: .init(
                    claimId: self.claimId!,
                    parentId: comment.commentId!,
                    page: 1,
                    pageSize: 999,
                    skipValidation: true,
                    topLevel: false
                ) as CommentListParams,
                url: Lbry.commentronURL,
                authToken: Lbryio.authToken
            ))
        }
        .flatMap(maxPublishers: .max(1)) { comment, request in
            // Run data task.
            URLSession.shared.dataTaskPublisher(for: request).mapError { $0 as Error }.map { (comment, $0) }
        }
        .tryMap { comment, dataTaskOutput -> (Comment, Page<Comment>) in
            let (data, _) = dataTaskOutput

            // Decode and validate result.
            let response = try JSONDecoder().decode(Lbry.APIResponse<Page<Comment>>.self, from: data)
            if response.jsonrpc != "2.0" {
                assertionFailure()
                throw LbryApiResponseError("wrong jsonrpc \(response.jsonrpc)")
            }

            guard let result = response.result else {
                throw LbryApiResponseError(response.error?.message ?? "unknown api error")
            }
            return (comment, result)
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
        .subscribeResultFinally { result in
            switch result {
            case let .failure(error):
                self.showError(error: error)
            case let .success(output):
                if let (parent, page) = output {
                    let loadedComments = page.items.filter {
                        comment in !self.comments.contains(where: { $0.commentId == comment.commentId })
                    }.map { comment in
                        var comment = comment
                        var currentComment: Comment? = comment
                        while let _currentComment = currentComment {
                            comment.replyDepth += 1
                            currentComment = self.comments.first(where: { $0.commentId == _currentComment.parentId })
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
                        self.loadCommentReactions(commentIds: loadedComments.map(\.commentId!))
                        self.resolveCommentAuthors(urls: loadedComments.map(\.channelUrl!))
                    }

                    self.setCommentRepliesLoaded(parent)
                    self.loadingContainer.isHidden = true
                } else {
                    self.scrollToCurrentComment()
                }
            }
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
        if index < 0 || channels.count == 0 {
            return
        }

        let channel = channels[index]
        commentAsChannelLabel.text = String(format: String.localized("Comment as %@"), channel.name!)

        var thumbnailUrl: URL?
        if channel.value != nil, channel.value?.thumbnail != nil {
            thumbnailUrl = URL(string: channel.value!.thumbnail!.url!)!
                .makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
        }

        if thumbnailUrl != nil {
            commentAsThumbnailView.load(url: thumbnailUrl!)
            commentAsThumbnailView.backgroundColor = UIColor.clear
        } else {
            commentAsThumbnailView.image = UIImage(named: "spaceman")
            commentAsThumbnailView.backgroundColor = Helper.lightPrimaryColor
        }
    }

    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(message: message)
        }
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showMessage(message: message)
        }
    }

    func showUAView() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }

    func filterBlockedChannels(_ reload: Bool) {
        comments.removeAll { Helper.isChannelBlocked(claimId: $0.channelId) }
        if reload {
            commentList.reloadData()
        }
    }

    func blockChannelStatusChanged(claimId: String, isBlocked: Bool) {
        // simply use the mainViewController's blockedChannels list to filter
        filterBlockedChannels(true)
    }

    struct CombinedReactionData {
        var othersLike: Int?
        var othersDislike: Int?
        var myLike: Int?
        var myDislike: Int?
    }
}
