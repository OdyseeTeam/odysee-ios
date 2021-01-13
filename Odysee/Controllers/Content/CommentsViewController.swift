//
//  CommentsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/01/2021.
//

import UIKit

class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPickerViewDataSource, UIPickerViewDelegate, UITextViewDelegate {

    @IBOutlet weak var noCommentsLabel: UILabel!
    @IBOutlet weak var postCommentAreaView: UIView!
    @IBOutlet weak var commentAsThumbnailView: UIImageView!
    @IBOutlet weak var commentAsChannelLabel: UILabel!
    @IBOutlet weak var commentLimitLabel: UILabel!
    @IBOutlet weak var commentInput: UITextView!
    @IBOutlet weak var commentList: UITableView!
    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var commentListHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    
    var commentAsPicker: UIPickerView!
    var claimId: String?
    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var postingComment: Bool = false
    var channels: [Claim] = []
    var comments: [Comment] = []
    var authorThumbnailMap: Dictionary<String, String> = [:]
    
    var currentCommentAsIndex = -1
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        postCommentAreaView.isHidden = !Lbryio.isSignedIn()
        if Lbryio.isSignedIn() {
            loadChannels()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let window = UIApplication.shared.windows.filter{ $0.isKeyWindow }.first!
        let safeAreaFrame = window.safeAreaLayoutGuide.layoutFrame
        scrollViewBottomConstraint.constant = 240 + (window.frame.maxY - safeAreaFrame.maxY) + 48 // Media View Height + Safe Area + Title Area Height
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        commentAsThumbnailView.rounded()
        commentList.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        
        commentInput.layer.borderColor = UIColor.systemGray5.cgColor
        commentInput.layer.borderWidth = 1
        commentInput.layer.cornerRadius = 1
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "comment_cell", for: indexPath) as! CommentTableViewCell
        
        let comment: Comment = comments[indexPath.row]
        cell.setComment(comment: comment)
        cell.setAuthorImageMap(map: authorThumbnailMap)
            
        return cell
    }
    
    func loadComments() {
        if commentsLoading {
            return
        }
        
        commentsLoading = true
        loadingContainer.isHidden = false
        let params: Dictionary<String, Any> = [
            "claim_id": claimId!,
            "page": commentsCurrentPage,
            "page_size": commentsPageSize,
            "skip_validation": true,
            "include_replies": false
        ]
        Lbry.apiCall(method: Lbry.methodCommentList, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
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
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let comment: Comment? = try JSONDecoder().decode(Comment.self, from: data)
                        if (comment != nil && !self.comments.contains(where: { $0.commentId == comment?.commentId })) {
                            loadedComments.append(comment!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.comments.append(contentsOf: loadedComments)
                // resolve author map
                if self.comments.count > 0 {
                    self.resolveCommentAuthors(urls: loadedComments.map { $0.channelUrl! })
                }
                
            }
            
            self.commentsLoading = false
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
                self.commentList.reloadData()
                self.checkNoComments()
            }
        })
    }

    func resolveCommentAuthors(urls: [String]) {
        let params = ["urls": urls]
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { [self] data, error in
            guard let data = data, error == nil else {
                return
            }
            
            let result = data["result"] as! NSDictionary
            for (url, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if claim != nil && !(claim!.claimId ?? "").isBlank {
                        if claim!.value != nil && claim!.value!.thumbnail != nil && !(claim!.value!.thumbnail!.url ?? "").isBlank {
                            self.authorThumbnailMap[url as! String] = claim!.value!.thumbnail!.url!
                        }
                    }
                } catch {
                    // pass
                }
            }
            
            DispatchQueue.main.async {
                commentList.reloadData()
            }
        })
    }
    
    func loadChannels() {
        if channels.count > 0 {
            return
        }
        
        let options: Dictionary<String, Any> = ["claim_type": "channel", "page": 1, "page_size": 999, "resolve": true]
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                return
            }
            
            self.channels.removeAll()
            let result = data["result"] as? [String: Any]
            if let items = result?["items"] as? [[String: Any]] {
                items.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claim != nil) {
                            self.channels.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if self.currentCommentAsIndex == -1 && self.channels.count > 0 {
                    self.currentCommentAsIndex = 0
                    self.updateCommentAsChannel(0)
                }
                if self.commentAsPicker != nil {
                    self.commentAsPicker.reloadAllComponents()
                }
            }
        })
    }
    
    func checkNoComments() {
        DispatchQueue.main.async {
            self.noCommentsLabel.isHidden = self.comments.count > 0
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentSize" {
            let contentHeight: CGFloat = commentList.contentSize.height
            commentListHeightConstraint.constant = contentHeight
        }
    }
    
    @IBAction func commentAsTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Comment as"), dataSource: self, delegate: self, parent: self, handler: { _ in
             let selectedIndex = self.commentAsPicker.selectedRow(inComponent: 0)
             let prevIndex = self.currentCommentAsIndex
             self.currentCommentAsIndex = selectedIndex
             if (prevIndex != self.currentCommentAsIndex) {
                self.updateCommentAsChannel(self.currentCommentAsIndex)
             }
         })
         
         commentAsPicker = picker
         present(alert, animated: true, completion: nil)
    }
    
    @IBAction func postCommentTapped(_ sender: UIButton) {
        if self.postingComment {
            return
        }
        
        if currentCommentAsIndex == -1 || channels.count == 0 {
            self.showError(message: String.localized("You need to select a channel to post your comment as"))
            return
        }
        if commentInput.text.count < Helper.commentMinLength {
            self.showError(message: String.localized("Please post a meaningful comment"))
            return
        }
        if commentInput.text.count > Helper.commentMaxLength {
            self.showError(message: String.localized("Your comment is too long"))
            return
        }
        
        postingComment = true
        loadingContainer.isHidden = false
        let params: Dictionary<String, Any> = ["claim_id": claimId!, "channel_id": channels[currentCommentAsIndex].claimId!, "comment": commentInput.text!]
        Lbry.apiCall(method: Lbry.methodCommentCreate, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                self.showError(error: error)
                return
            }
            
            // comment post successful
            self.postingComment = false
            DispatchQueue.main.async {
                self.commentInput.text = ""
                self.loadingContainer.isHidden = true
                self.textViewDidChange(self.commentInput)
            }
            self.loadComments()
        })
    }
    
    @IBAction func closeTapped(_ sender: UIButton) {
        if let parentvc = self.parent as? FileViewController {
            parentvc.closeCommentsView()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (commentList.contentOffset.y >= (commentList.contentSize.height - commentList.bounds.size.height)) {
            if (!commentsLoading && !commentsLastPageReached) {
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
    
    func updateCommentAsChannel(_ index: Int) {
        let channel = channels[index]
        commentAsChannelLabel.text = String(format: String.localized("Comment as %@"), channel.name!)
        
        var thumbnailUrl: URL? = nil
        if (channel.value != nil && channel.value?.thumbnail != nil) {
            thumbnailUrl = URL(string: (channel.value!.thumbnail!.url!))!
        }
        
        if thumbnailUrl != nil {
            commentAsThumbnailView.load(url: thumbnailUrl!)
            commentAsThumbnailView.backgroundColor = UIColor.clear
        } else {
            commentAsThumbnailView.image = UIImage.init(named: "spaceman")
            commentAsThumbnailView.backgroundColor = Helper.lightPrimaryColor
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.channels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.channels.map{ $0.name }[row]
    }
    
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    func showError(message: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    
    func showMessage(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showMessage(message: message)
    }
}
