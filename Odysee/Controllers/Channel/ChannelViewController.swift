//
//  ChannelViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/12/2020.
//

import CoreData
import Firebase
import SafariServices
import UIKit

class ChannelViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, UITextViewDelegate {
    
    var channelClaim: Claim?
    var claimUrl: LbryUri?
    var subscribeUnsubscribeInProgress = false
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var coverImageView: UIImageView!
    
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var pageScrollView: UIScrollView!
    
    @IBOutlet weak var contentListView: UITableView!
    @IBOutlet weak var contentLoadingContainer: UIView!
    @IBOutlet weak var sortByLabel: UILabel!
    @IBOutlet weak var contentFromLabel: UILabel!
    
    @IBOutlet weak var titleLabel: UIPaddedLabel!
    @IBOutlet weak var followerCountLabel: UIPaddedLabel!
    
    @IBOutlet weak var noChannelContentView: UIView!
    @IBOutlet weak var noAboutContentView: UIView!
    
    @IBOutlet weak var websiteStackView: UIView!
    @IBOutlet weak var emailStackView: UIView!
    @IBOutlet weak var websiteLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var followLabel: UILabel!
    @IBOutlet weak var followUnfollowIconView: UIImageView!
    @IBOutlet weak var bellView: UIView!
    @IBOutlet weak var bellIconView: UIImageView!
    
    @IBOutlet weak var resolvingView: UIView!
    @IBOutlet weak var resolvingImageView: UIImageView!
    @IBOutlet weak var resolvingLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var resolvingLabel: UILabel!
    @IBOutlet weak var resolvingCloseButton: UIButton!
    
    @IBOutlet weak var noCommentsLabel: UILabel!
    @IBOutlet weak var postCommentAreaView: UIView!
    @IBOutlet weak var commentAsThumbnailView: UIImageView!
    @IBOutlet weak var commentAsChannelLabel: UILabel!
    @IBOutlet weak var commentLimitLabel: UILabel!
    @IBOutlet weak var commentInput: UITextView!
    @IBOutlet weak var commentList: UITableView!
    @IBOutlet weak var commentListHeightConstraint: NSLayoutConstraint!
    
    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!
    var commentAsPicker: UIPickerView!
    
    var claimSearchOptions = Dictionary<String, Any>()
    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loadingContent: Bool = false
    var claims: [Claim] = []
    var channels: [Claim] = []
    
    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var comments: [Comment] = []
    var authorThumbnailMap: Dictionary<String, String> = [:]
    
    var currentCommentAsIndex = -1
    var currentSortByIndex = 1 // default to New content
    var currentContentFromIndex = 1 // default to Past week`
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
        
        if channelClaim != nil {
            checkFollowing()
            checkNotificationsDisabled()
        }
        
        postCommentAreaView.isHidden = !Lbryio.isSignedIn()
        
        if !Lbryio.isSignedIn() && pageControl.currentPage == 2 {
            pageControl.currentPage = 1
            updateScrollViewForPage(page: pageControl.currentPage)
        }
        
        if Lbryio.isSignedIn() {
            loadChannels()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Channel", AnalyticsParameterScreenClass: "ChannelViewController"])
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentLoadingContainer.layer.cornerRadius = 20
        titleLabel.layer.cornerRadius = 8
        titleLabel.textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

        followerCountLabel.layer.cornerRadius = 8
        followerCountLabel.textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        
        // Do any additional setup after loading the view
        commentAsThumbnailView.rounded()
        thumbnailImageView.rounded()
        
        commentInput.layer.borderColor = UIColor.systemGray5.cgColor
        commentInput.layer.borderWidth = 1
        commentInput.layer.cornerRadius = 4
        
        commentList.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        
        // TODO: If channelClaim is not set, resolve the claim url before displaying
        if channelClaim == nil && claimUrl != nil {
            resolveAndDisplayClaim()
        } else if channelClaim != nil {
            displayClaim()
            loadAndDisplayFollowerCount()
            loadContent()
            loadComments()
        } else {
            displayNothingAtLocation()
        }
    }
    
    func showClaimAndCheckFollowing() {
        displayClaim()
        loadAndDisplayFollowerCount()
        loadContent()
        loadComments()
        
        checkFollowing()
        checkNotificationsDisabled()
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
                self.postCommentAreaView.isHidden = self.channels.count == 0
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
    
    func resolveAndDisplayClaim() {
        displayResolving()
        
        let url = claimUrl!.description
        if Lbry.claimCacheByUrl[url] != nil {
            channelClaim = Lbry.claimCacheByUrl[url]
            DispatchQueue.main.async {
                self.showClaimAndCheckFollowing()
            }
            return
        }
        
        var params: Dictionary<String, Any> = Dictionary<String, Any>()
        params["urls"] = [url]
        
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                self.displayNothingAtLocation()
                return
            }
            
            let result = data["result"] as! NSDictionary
            for (_, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if claim != nil && !(claim!.claimId ?? "").isBlank {
                        Lbry.addClaimToCache(claim: claim)
                        self.channelClaim = claim
                        DispatchQueue.main.async {
                            self.showClaimAndCheckFollowing()
                        }
                    } else {
                        self.displayNothingAtLocation()
                    }
                } catch let error {
                    print(error)
                }
                
                break
            }
        })
    }
    
    func displayResolving() {
        DispatchQueue.main.async {
            self.resolvingView.isHidden = false
            self.resolvingLoadingIndicator.isHidden = false
            self.resolvingImageView.image = UIImage.init(named: "spaceman_happy")
            self.resolvingLabel.text = String.localized("Resolving content...")
            self.resolvingCloseButton.isHidden = true
        }
    }
    
    func displayNothingAtLocation() {
        DispatchQueue.main.async {
            self.resolvingView.isHidden = false
            self.resolvingLoadingIndicator.isHidden = true
            self.resolvingImageView.image = UIImage.init(named: "spaceman_sad")
            self.resolvingLabel.text = String.localized("There's nothing at this location.")
            self.resolvingCloseButton.isHidden = false
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == commentInput {
            let length = commentInput.text.count
            commentLimitLabel.text = String(format: "%d / %d", length, Helper.commentMaxLength)
        }
    }
    
    func displayClaim() {
        resolvingView.isHidden = true
        
        if channelClaim?.value != nil {
            if channelClaim?.value?.thumbnail != nil {
                thumbnailImageView.load(url: URL(string: (channelClaim?.value?.thumbnail?.url)!)!)
            } else {
                thumbnailImageView.image = UIImage.init(named: "spaceman")
                thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
            }
            
            if channelClaim?.value?.cover != nil {
                coverImageView.load(url: URL(string: (channelClaim?.value?.cover?.url)!)!)
            } else {
                coverImageView.image = UIImage.init(named: "spaceman_cover")
            }
            
            titleLabel.text = channelClaim?.value?.title
            
            // about page
            let website = channelClaim?.value?.websiteUrl
            let email = channelClaim?.value?.email
            let description = channelClaim?.value?.description
            
            if (website ?? "").isBlank && (email ?? "").isBlank && (description ?? "").isBlank {
                websiteStackView.isHidden = true
                emailStackView.isHidden = true
                descriptionLabel.isHidden = true
                noAboutContentView.isHidden = false
            } else {
                websiteStackView.isHidden = (website ?? "").isBlank
                websiteLabel.text = website ?? ""
                emailStackView.isHidden = (email ?? "").isBlank
                emailLabel.text = email ?? ""
                descriptionLabel.isHidden = (description ?? "").isBlank
                descriptionLabel.text = description
                noAboutContentView.isHidden = true
            }
        }
        
    }
    
    func loadAndDisplayFollowerCount() {
        var options = Dictionary<String, String>()
        options["claim_id"] = channelClaim?.claimId
        try! Lbryio.call(resource: "subscription", action: "sub_count", options: options, method: Lbryio.methodGet, completion: { data, error in
            guard let data = data, error == nil else {
                return
            }
            DispatchQueue.main.async {
                let formatter = NumberFormatter()
                formatter.usesGroupingSeparator = true
                formatter.locale = Locale.current
                formatter.numberStyle = .decimal
                
                let followerCount = (data as! NSArray)[0] as! Int
                self.followerCountLabel.isHidden = false
                self.followerCountLabel.text = String(format: followerCount == 1 ? String.localized("%@ follower") : String.localized("%@ followers"), formatter.string(for: followerCount)!)
            }
        })
    }
    
    func updateClaimSearchOptions() {
        let channelIds: [String] = [channelClaim?.claimId ?? ""]
        let orderByValue = Helper.sortByItemValues[currentSortByIndex]
        let releaseTimeValue = currentSortByIndex == 2 ? Helper.buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : nil
        self.claimSearchOptions = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: channelIds, notChannelIds: nil, claimIds: nil, orderBy: orderByValue, releaseTime: releaseTimeValue, maxDuration: nil, limitClaimsPerChannel: 0, page: currentPage, pageSize: pageSize)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView == pageScrollView) {
            let pageIndex = Int(round(scrollView.contentOffset.x / view.frame.width))
            pageControl.currentPage = pageIndex
        } else if (scrollView == contentListView) {
            if (contentListView.contentOffset.y >= (contentListView.contentSize.height - contentListView.bounds.size.height)) {
                if (!loadingContent && !lastPageReached) {
                    currentPage += 1
                    loadContent()
                }
            }
        } else if (scrollView == commentList) {
            if (commentList.contentOffset.y >= (commentList.contentSize.height - commentList.bounds.size.height)) {
                if (!commentsLoading && !commentsLastPageReached) {
                    commentsCurrentPage += 1
                    loadComments()
                }
            }
        }
    }
    
    func resetContent() {
        currentPage = 1
        lastPageReached = false
        claims.removeAll()
        contentListView.reloadData()
    }
    func loadContent() {
        if (loadingContent) {
            return
        }
        
        DispatchQueue.main.async {
            self.contentLoadingContainer.isHidden = false
        }
        
        loadingContent = true
        noChannelContentView.isHidden = true
        updateClaimSearchOptions()
        Lbry.apiCall(method: Lbry.methodClaimSearch, params: claimSearchOptions, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                print(error!)
                return
            }
            
            let result = data["result"] as? [String: Any]
            let items = result?["items"] as? [[String: Any]]
            if (items != nil) {
                if (items!.count < self.pageSize) {
                    self.lastPageReached = true
                }
                var loadedClaims: [Claim] = []
                items?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claim != nil && !self.claims.contains(where: { $0.claimId == claim?.claimId })) {
                            loadedClaims.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.claims.append(contentsOf: loadedClaims)
                //self.claims.sort(by: { Int64($0.value?.releaseTime ?? "0")! > Int64($1.value?.releaseTime ?? "0")! })
            }
            
            self.loadingContent = false
            DispatchQueue.main.async {
                self.contentLoadingContainer.isHidden = true
                self.checkNoContent()
                self.contentListView.reloadData()
                //self.refreshControl.endRefreshing()
            }
        })
    }
    
    func checkNoContent() {
        noChannelContentView.isHidden = claims.count > 0
    }
    
    func checkNoComments() {
        DispatchQueue.main.async {
            self.noCommentsLabel.isHidden = self.comments.count > 0
        }
    }
    
    func checkUpdatedSortBy() {
        let itemName = Helper.sortByItemNames[currentSortByIndex]
        sortByLabel.text = String(format: "%@ ▾", String(itemName.prefix(upTo: itemName.firstIndex(of: " ")!)))
        contentFromLabel.isHidden = currentSortByIndex != 2
    }
    
    func checkUpdatedContentFrom() {
        contentFromLabel.text = String(format: "%@ ▾", String(Helper.contentFromItemNames[currentContentFromIndex]))
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == contentListView {
            return claims.count
        } else if tableView == commentList {
            return comments.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == contentListView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
            
            let claim: Claim = claims[indexPath.row]
            cell.setClaim(claim: claim)
                
            return cell
        } else if tableView == commentList {
            let cell = tableView.dequeueReusableCell(withIdentifier: "comment_cell", for: indexPath) as! CommentTableViewCell
            
            let comment: Comment = comments[indexPath.row]
            cell.setComment(comment: comment)
            cell.setAuthorImageMap(map: authorThumbnailMap)
                
            return cell
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView == contentListView {
            let claim: Claim = claims[indexPath.row]
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = claim
            
            appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == sortByPicker {
            return Helper.sortByItemNames.count
        } else if pickerView == contentFromPicker {
            return Helper.contentFromItemNames.count
        } else if pickerView == commentAsPicker {
            return self.channels.count
        }
        
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == sortByPicker {
            return Helper.sortByItemNames[row]
        } else if pickerView == contentFromPicker {
            return Helper.contentFromItemNames[row]
        } else if pickerView == commentAsPicker {
            return self.channels.map{ $0.name }[row]
        }
        
        return nil
    }
    
    @IBAction func sortByLabelTapped(_ sender: Any) {
       let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Sort content by"), dataSource: self, delegate: self, parent: self, handler: { _ in
            let selectedIndex = self.sortByPicker.selectedRow(inComponent: 0)
            let prevIndex = self.currentSortByIndex
            self.currentSortByIndex = selectedIndex
            if (prevIndex != self.currentSortByIndex) {
                self.checkUpdatedSortBy()
                self.resetContent()
                self.loadContent()
            }
        })
        
        sortByPicker = picker
        present(alert, animated: true, completion: {
            self.sortByPicker.selectRow(self.currentSortByIndex, inComponent: 0, animated: true)
        })
    }
    
    @IBAction func postCommentTapped(_ sender: UIButton) {
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
        
        let params: Dictionary<String, Any> = ["claim_id": channelClaim!.claimId!, "channel_id": channels[currentCommentAsIndex].claimId!, "comment": commentInput.text!]
        Lbry.apiCall(method: Lbry.methodCommentCreate, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                self.showError(error: error)
                return
            }
            
            // comment post successful
            DispatchQueue.main.async {
                self.commentInput.text = ""
                self.textViewDidChange(self.commentInput)
            }
            self.loadComments()
        })
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
    
    @IBAction func closeTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func contentFromLabelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Content from"), dataSource: self, delegate: self, parent: self, handler: { _ in
            let selectedIndex = self.contentFromPicker.selectedRow(inComponent: 0)
            let prevIndex = self.currentContentFromIndex
            self.currentContentFromIndex = selectedIndex
            if (prevIndex != self.currentContentFromIndex) {
                self.checkUpdatedContentFrom()
                self.resetContent()
                self.loadContent()
            }
        })
        
        contentFromPicker = picker
        present(alert, animated: true, completion: {
            self.contentFromPicker.selectRow(self.currentContentFromIndex, inComponent: 0, animated: true)
        })
    }
    
    @IBAction func backTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func pageChanged(_ sender: UIPageControl) {
        let page = sender.currentPage
        updateScrollViewForPage(page: page)
    }
    
    func updateScrollViewForPage(page: Int) {
        var frame: CGRect = pageScrollView.frame
        frame.origin.x = frame.size.width * CGFloat(page)
        frame.origin.y = 0
        pageScrollView.scrollRectToVisible(frame, animated: true)
    }

    @IBAction func websiteTapped(_ sender: Any) {
        var websiteUrl = websiteLabel.text ?? ""
        if !websiteUrl.isBlank {
            if !websiteUrl.starts(with: "http://") && !websiteUrl.starts(with: "https://") {
                websiteUrl = String(format: "http://%@", websiteUrl)
            }
            if let url = URL(string: websiteUrl) {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func checkFollowing() {
        DispatchQueue.main.async {
            if (Lbryio.isFollowing(claim: self.channelClaim!)) {
                // show unfollow and bell icons
                self.followLabel.isHidden = true
                self.bellView.isHidden = false
                self.followUnfollowIconView.image = UIImage.init(systemName: "heart.slash.fill")
                self.followUnfollowIconView.tintColor = UIColor.label
            } else {
                self.followLabel.isHidden = false
                self.bellView.isHidden = true
                self.followUnfollowIconView.image = UIImage.init(systemName: "heart")
                self.followUnfollowIconView.tintColor = UIColor.systemRed
            }
        }
    }
    
    func checkNotificationsDisabled() {
        if (!Lbryio.isFollowing(claim: channelClaim!)) {
            return
        }
        
        DispatchQueue.main.async {
            if (Lbryio.isNotificationsDisabledForSub(claim: self.channelClaim!)) {
                self.bellIconView.image = UIImage.init(systemName: "bell.fill")
            } else {
                self.bellIconView.image = UIImage.init(systemName: "bell.slash.fill")
            }
        }
    }
    
    @IBAction func shareActionTapped(_ sender: Any) {
        let url = LbryUri.tryParse(url: channelClaim!.shortUrl!, requireProto: false)
        if (url != nil) {
            let items = [url!.odyseeString]
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            present(vc, animated: true)
        }
    }
    
    @IBAction func tipActionTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }
        
        let vc = storyboard?.instantiateViewController(identifier: "support_vc") as! SupportViewController
        vc.claim = channelClaim!
        vc.modalPresentationStyle = .overCurrentContext
        present(vc, animated: true)
    }
    
    func showUAView() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func followUnfollowActionTapped(_ sender: Any) {
        if (!Lbryio.isSignedIn()) {
            showUAView()
            return
        }
        subscribeOrUnsubscribe(claim: channelClaim!, notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: channelClaim!), unsubscribing: Lbryio.isFollowing(claim: channelClaim!))
    }
    
    @IBAction func bellActionTapped(_ sender: Any) {
        if (!Lbryio.isSignedIn()) {
            showUAView()
            return
        }
        subscribeOrUnsubscribe(claim: channelClaim!, notificationsDisabled: !Lbryio.isNotificationsDisabledForSub(claim: channelClaim!), unsubscribing: false)
    }
    
    func subscribeOrUnsubscribe(claim: Claim?, notificationsDisabled: Bool, unsubscribing: Bool) {
        if (subscribeUnsubscribeInProgress) {
            return
        }
        
        subscribeUnsubscribeInProgress = true
        do {
            var options = Dictionary<String, String>()
            options["claim_id"] = claim?.claimId!
            if (!unsubscribing) {
                options["channel_name"] = claim?.name
                options["notifications_disabled"] = String(notificationsDisabled)
            }
            
            let subUrl: LbryUri = try LbryUri.parse(url: (claim?.permanentUrl!)!, requireProto: false)
            try Lbryio.call(resource: "subscription", action: unsubscribing ? "delete" : "new", options: options, method: Lbryio.methodGet, completion: { data, error in
                self.subscribeUnsubscribeInProgress = false
                guard let _ = data, error == nil else {
                    //print(error)
                    self.showError(error: error)
                    self.checkFollowing()
                    self.checkNotificationsDisabled()
                    return
                }

                if (!unsubscribing) {
                    Lbryio.addSubscription(sub: LbrySubscription.fromClaim(claim: claim!, notificationsDisabled: notificationsDisabled), url: subUrl.description)
                    self.addSubscription(url: subUrl.description, channelName: subUrl.channelName!, isNotificationsDisabled: notificationsDisabled, reloadAfter: true)
                } else {
                    Lbryio.removeSubscription(subUrl: subUrl.description)
                    self.removeSubscription(url: subUrl.description, channelName: subUrl.channelName!)
                }
                
                self.checkFollowing()
                self.checkNotificationsDisabled()
                
                if (Lbryio.isSignedIn()) {
                    Lbry.saveSharedUserState(completion: { success, error in
                        guard error == nil else {
                            // pass
                            return
                        }
                        if (success) {
                            // run wallet sync
                            Lbry.pushSyncWallet()
                        }
                    })
                }
            })
        } catch let error {
            showError(error: error)
        }
    }
    
    func addSubscription(url: String, channelName: String, isNotificationsDisabled: Bool, reloadAfter: Bool) {
        // persist the subscription to CoreData
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context: NSManagedObjectContext! = appDelegate.persistentContainer.viewContext
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            let subToSave = Subscription(context: context)
            subToSave.url = url
            subToSave.channelName = channelName
            subToSave.isNotificationsDisabled = isNotificationsDisabled
            
            appDelegate.saveContext()
        }
    }
    
    func removeSubscription(url: String, channelName: String) {
        // remove the subscription from CoreData
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context: NSManagedObjectContext! = appDelegate.persistentContainer.viewContext
            let subToDelete = Subscription(context: context)
            subToDelete.url = url
            subToDelete.channelName = channelName
            
            context.delete(subToDelete)
        }
    }
    
    func loadComments() {
        if commentsLoading {
            return
        }
        
        commentsLoading = true
        let params: Dictionary<String, Any> = [
            "claim_id": channelClaim!.claimId!,
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
    
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    func showError(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    
    func showMessage(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showMessage(message: message)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentSize" {
            if (change?[.newKey]) != nil {
                let contentHeight: CGFloat = commentList.contentSize.height
                commentListHeightConstraint.constant = contentHeight
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
