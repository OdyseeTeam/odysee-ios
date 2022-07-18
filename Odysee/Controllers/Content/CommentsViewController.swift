//
//  CommentsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/01/2021.
//

import UIKit

class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPickerViewDataSource,
    UIPickerViewDelegate, UITextViewDelegate, BlockChannelStatusObserver
{
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var noCommentsLabel: UILabel!
    @IBOutlet var postCommentAreaView: UIView!
    @IBOutlet var commentAsThumbnailView: UIImageView!
    @IBOutlet var commentAsChannelLabel: UILabel!
    @IBOutlet var commentLimitLabel: UILabel!
    @IBOutlet var commentInput: UITextView!
    @IBOutlet var commentList: UITableView!
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var channelDriverView: UIView!
    @IBOutlet var channelDriverHeightConstraint: NSLayoutConstraint!
    @IBOutlet var commentListHeightConstraint: NSLayoutConstraint!
    @IBOutlet var contentScrollView: UIScrollView!
    @IBOutlet var scrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var guidelinesTextView: UITextView!

    @IBOutlet var replyToContainerView: UIView!
    @IBOutlet var replyToCommentLabel: UILabel!

    var commentsDisabled: Bool = false
    var commentAsPicker: UIPickerView!
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        postCommentAreaView.isHidden = !Lbryio.isSignedIn() || commentsDisabled
        if Lbryio.isSignedIn() {
            loadChannels()
        }
        if comments.count == 0, !commentsDisabled {
            loadComments()
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
        commentList.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)

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
            "By continuing, you accept the Odysee Terms of Service and community guidelines.")
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

        if comments.count > 0 {
            // comments already preloaded
            loadCommentReactions(commentIds: comments.map { $0.commentId! })
        }

        if channels.count > 0, currentCommentAsIndex == -1 {
            currentCommentAsIndex = 0
            updateCommentAsChannel(0)
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
        contentScrollView.contentInset = contentInsets
        contentScrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        contentScrollView.contentInset = contentInsets
        contentScrollView.scrollIndicatorInsets = contentInsets
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

    func loadComments() {
        if commentsLoading {
            return
        }

        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }
        commentsLoading = true
        let params: [String: Any] = [
            "claim_id": claimId!,
            "page": commentsCurrentPage,
            "page_size": commentsPageSize,
            "skip_validation": true,
            "include_replies": false,
        ]
        Lbry.apiCall(
            method: Lbry.Methods.commentList.name,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }

                let result = data["result"] as? [String: Any]
                if let items = result?["items"] as? [[String: Any]] {
                    if items.count < self.commentsPageSize {
                        self.commentsLastPageReached = true
                    }
                    var loadedComments: [Comment] = []
                    items.forEach { item in
                        let data = try! JSONSerialization.data(
                            withJSONObject: item,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        do {
                            let comment: Comment? = try JSONDecoder().decode(Comment.self, from: data)
                            if comment != nil, !self.comments.contains(where: { $0.commentId == comment?.commentId }) {
                                loadedComments.append(comment!)
                            }
                        } catch {
                            print(error)
                        }
                    }
                    self.comments.append(contentsOf: loadedComments)

                    if loadedComments.count > 0 {
                        self.loadCommentReactions(commentIds: loadedComments.map { $0.commentId! })
                    }

                    // resolve author map
                    if self.comments.count > 0 {
                        self.resolveCommentAuthors(urls: loadedComments.map { $0.channelUrl! })
                    }
                }

                self.commentsLoading = false
                DispatchQueue.main.async {
                    self.filterBlockedChannels(false)
                    self.loadingContainer.isHidden = true
                    self.commentList.reloadData()
                    self.checkNoComments()
                }
            }
        )
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
            picker.reloadAllComponents()
        }
    }

    func checkNoComments() {
        DispatchQueue.main.async {
            self.noCommentsLabel.isHidden = self.comments.count > 0
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "contentSize" {
            let contentHeight: CGFloat = commentList.contentSize.height
            commentListHeightConstraint.constant = contentHeight
        }
    }

    @IBAction func commentAsTapped(_ sender: Any) {
        commentInput.resignFirstResponder()

        let (picker, alert) = Helper.buildPickerActionSheet(
            title: String.localized("Comment as"),
            dataSource: self,
            delegate: self,
            parent: self,
            handler: { _ in
                let selectedIndex = self.commentAsPicker.selectedRow(inComponent: 0)
                let prevIndex = self.currentCommentAsIndex
                self.currentCommentAsIndex = selectedIndex
                if prevIndex != self.currentCommentAsIndex {
                    self.updateCommentAsChannel(self.currentCommentAsIndex)
                }
            }
        )

        commentAsPicker = picker
        alert.popoverPresentationController?.sourceView = commentAsChannelLabel
        present(alert, animated: true, completion: nil)
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

        if currentCommentAsIndex == -1 || channels.count == 0 {
            showError(message: String.localized("You need to select a channel to post your comment as"))
            return
        }

        if commentInput.text.count > Helper.commentMaxLength {
            showError(message: String.localized("Your comment is too long"))
            return
        }

        postingComment = true
        loadingContainer.isHidden = false
        var params: [String: Any] = [
            "claim_id": claimId!,
            "channel_id": channels[currentCommentAsIndex].claimId!,
            "comment": commentInput.text!,
        ]
        if currentReplyToComment != nil {
            params["parent_id"] = currentReplyToComment?.commentId!
        }
        Lbry.apiCall(
            method: Lbry.methodCommentCreate,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data,
                      let result = data["result"] as? [String: Any],
                      result["error"] == nil, error == nil
                else {
                    self.showError(error: error)
                    return
                }

                if let result = data["result"] as? [String: Any],
                   let error = result["error"] as? [String: Any],
                   let message = error["message"] as? String
                {
                    self.showError(message: String(
                        format: String.localized("Your comment could not be posted: %@"),
                        message
                    ))
                }

                do {
                    let commentData = try JSONSerialization.data(
                        withJSONObject: result,
                        options: [.prettyPrinted, .sortedKeys]
                    )
                    let comment = try JSONDecoder().decode(Comment.self, from: commentData)
                    if let currentReplyToComment = self.currentReplyToComment {
                        if currentReplyToComment.repliesLoaded ?? false {
                            let parentIndex = self.indexForComment(currentReplyToComment)
                            if parentIndex > -1 {
                                self.comments.insert(comment, at: parentIndex + 1)
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.loadReplies(currentReplyToComment)
                            }
                        }
                    } else {
                        self.comments.insert(comment, at: 0)
                    }
                    self.loadCommentReactions(commentIds: [comment.claimId!])
                    self.resolveCommentAuthors(urls: [comment.channelUrl!])
                } catch {
                    self.showError(error: error)
                }

                // comment post successful
                self.postingComment = false
                DispatchQueue.main.async {
                    self.commentInput.text = ""
                    self.replyToCommentLabel.text = ""
                    self.replyToContainerView.isHidden = true
                    self.loadingContainer.isHidden = true
                    self.textViewDidChange(self.commentInput)
                    self.commentList.reloadData()
                    self.checkNoComments()
                }

                self.currentReplyToComment = nil
            }
        )
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
        if contentScrollView.contentOffset
            .y >= (contentScrollView.contentSize.height - contentScrollView.bounds.size.height)
        {
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
        var params: [String: Any] = ["comment_ids": commentIds.joined(separator: ",")]
        if channels.count > 0 {
            // for now, always pick the first channel
            // TODO: allow the user to set a default channel
            params["channel_id"] = channels[0].claimId!
        }

        Lbry.apiCall(
            method: Lbry.methodCommentReactList,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }

                let result = data["result"] as? [String: Any]
                var combined: [String: CombinedReactionData] = [:]
                if let othersReactions = result!["others_reactions"] as? [String: Any] {
                    for (commentId, reactionData) in othersReactions {
                        if combined[commentId] == nil {
                            combined[commentId] = CombinedReactionData()
                        }
                        combined[commentId]?.othersReactions = reactionData as? [String: Any]
                    }
                }
                if let myReactions = result!["my_reactions"] as? [String: Any] {
                    for (commentId, reactionData) in myReactions {
                        if combined[commentId] == nil {
                            combined[commentId] = CombinedReactionData()
                            combined[commentId]?.othersReactions = [:]
                        }
                        combined[commentId]?.myReactions = reactionData as? [String: Any]
                    }
                }
                for (commentId, combined) in combined {
                    self.updateCommentReactions(
                        commentId: commentId,
                        otherReactionData: combined.othersReactions!,
                        myReactionData: combined.myReactions
                    )
                }

                DispatchQueue.main.async {
                    self.commentList.reloadData()
                }
            }
        )
    }

    func updateCommentReactions(commentId: String, otherReactionData: [String: Any], myReactionData: [String: Any]?) {
        for i in comments.indices {
            if comments[i].commentId == commentId {
                comments[i].numLikes = otherReactionData["like"] as? Int ?? 0
                comments[i].numDislikes = otherReactionData["dislike"] as? Int ?? 0
                if myReactionData != nil {
                    comments[i].numLikes! += myReactionData!["like"] as! Int > 0 ? 1 : 0
                    comments[i].numDislikes! += myReactionData!["dislike"] as! Int > 0 ? 1 : 0
                    comments[i].isLiked = myReactionData!["like"] as! Int > 0
                    comments[i].isDisliked = myReactionData!["dislike"] as! Int > 0
                }
                break
            }
        }
    }

    func react(_ comment: Comment, type: String) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }

        if channels.count == 0 {
            showMessage(message: String.localized("You need to create a channel before you can react to comments"))
            return
        }

        if reacting {
            return
        }

        reacting = true
        var remove = false
        var params: [String: Any] = [
            "comment_ids": comment.commentId!,
            "react_type": type,
            "clear_types": type == Helper.reactionTypeLike ? Helper.reactionTypeDislike : Helper.reactionTypeLike,
        ]
        if (type == Helper.reactionTypeLike && (comment.isLiked ?? false)) ||
            (type == Helper.reactionTypeDislike && (comment.isDisliked ?? false))
        {
            remove = true
            params["remove"] = "true"
        }
        if channels.count > 0 {
            // TODO: Default channel
            params["channel_id"] = channels[0].claimId!
        }
        Lbry.apiCall(
            method: Lbry.methodCommentReact,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }

                _ = data["result"] as? [String: Any]
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

                self.reacting = false
                self.updateSingleCommentReactions(updatedComment)
            }
        )
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
        let params: [String: Any] = [
            "claim_id": claimId!,
            "parent_id": parent.commentId!,
            "page": 1,
            "page_size": 999,
            "skip_validation": true,
            "include_replies": true,
        ]
        Lbry.apiCall(
            method: Lbry.Methods.commentList.name,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }

                let result = data["result"] as? [String: Any]
                if let items = result?["items"] as? [[String: Any]] {
                    var loadedComments: [Comment] = []
                    items.forEach { item in
                        let data = try! JSONSerialization.data(
                            withJSONObject: item,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        do {
                            let comment: Comment? = try JSONDecoder().decode(Comment.self, from: data)
                            if comment != nil, !self.comments.contains(where: { $0.commentId == comment?.commentId }) {
                                loadedComments.append(comment!)
                            }
                        } catch {
                            print(error)
                        }
                    }

                    let parentIndex = self.indexForComment(parent)
                    if parentIndex > -1 {
                        self.comments.insert(contentsOf: loadedComments, at: parentIndex + 1)

                        if loadedComments.count > 0 {
                            self.loadCommentReactions(commentIds: loadedComments.map { $0.commentId! })
                            self.resolveCommentAuthors(urls: loadedComments.map { $0.channelUrl! })
                        }
                    }
                }

                self.commentsLoading = false
                self.setCommentRepliesLoaded(parent)
                DispatchQueue.main.async {
                    self.loadingContainer.isHidden = true
                    self.commentList.reloadData()
                }
            }
        )
    }

    func setCommentRepliesLoaded(_ comment: Comment) {
        for i in comments.indices {
            if comments[i].commentId == comment.commentId {
                comments[i].repliesLoaded = true
                break
            }
        }
    }

    func indexForComment(_ comment: Comment) -> Int {
        for i in comments.indices {
            if comments[i].commentId == comment.commentId {
                return i
            }
        }
        return -1
    }

    func setReplyToComment(_ comment: Comment) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }

        currentReplyToComment = comment
        if let origin = postCommentAreaView.superview {
            let startPoint = origin.convert(postCommentAreaView.frame.origin, to: contentScrollView)
            contentScrollView.scrollRectToVisible(
                CGRect(x: 0, y: startPoint.y, width: 1, height: contentScrollView.frame.height),
                animated: true
            )
        }

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

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return channels.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return channels.map(\.name)[row]
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
        comments = comments.filter { Helper.isChannelBlocked(claimId: $0.channelId!) }
        if reload {
            commentList.reloadData()
        }
    }

    func blockChannelStatusChanged(claimId: String, isBlocked: Bool) {
        // simply use the mainViewController's blockedChannels list to filter
        filterBlockedChannels(true)
    }

    struct CombinedReactionData {
        var othersReactions: [String: Any]?
        var myReactions: [String: Any]?
    }
}
