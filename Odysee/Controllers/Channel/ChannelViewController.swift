//
//  ChannelViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/12/2020.
//

import CoreData
import Firebase
import OrderedCollections
import SafariServices
import UIKit

class ChannelViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, UITextViewDelegate {
    
    var channelClaim: Claim?
    var claimUrl: LbryUri?
    var subscribeUnsubscribeInProgress = false
    var livestreamTimer: Timer = Timer()
    let livestreamTimerInterval: Double = 60 // 1 minute
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var coverImageView: UIImageView!
    
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var pageScrollView: UIScrollView!
    @IBOutlet weak var channelCommunityView: UIView!
    
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
    
    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!

    var commentsViewPresented = false
    var claimSearchOptions = Dictionary<String, Any>()
    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loadingContent: Bool = false
    var claims = OrderedSet<Claim>()
    var channels: [Claim] = []
    
    var commentsDisabledChecked = false
    var commentsDisabled = false
    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var comments: [Comment] = []
    var authorThumbnailMap = [String: URL]()
    
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
        
        contentListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
        contentLoadingContainer.layer.cornerRadius = 20
        titleLabel.layer.cornerRadius = 8
        titleLabel.textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

        followerCountLabel.layer.cornerRadius = 8
        followerCountLabel.textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        
        // Do any additional setup after loading the view
        thumbnailImageView.rounded()
        
        // TODO: If channelClaim is not set, resolve the claim url before displaying
        if channelClaim == nil && claimUrl != nil {
            resolveAndDisplayClaim()
        } else if channelClaim != nil {
            displayClaim()
            loadAndDisplayFollowerCount()
            loadContent()
            displayCommentsView()
        } else {
            displayNothingAtLocation()
        }
    }
    
    func displayCommentsView() {
        if commentsViewPresented || !commentsDisabledChecked {
            return
        }
        
        let vc = storyboard?.instantiateViewController(identifier: "comments_vc") as! CommentsViewController
        vc.claimId = channelClaim?.claimId!
        vc.commentsDisabled = commentsDisabled
        vc.isChannelComments = true
        
        vc.willMove(toParent: self)
        channelCommunityView.addSubview(vc.view)
        vc.view.frame = CGRect(x: 0, y: 0, width: channelCommunityView.bounds.width, height: channelCommunityView.bounds.height)
        self.addChild(vc)
        vc.didMove(toParent: self)
    
        commentsViewPresented = true
    }
    
    func showClaimAndCheckFollowing() {
        displayClaim()
        loadAndDisplayFollowerCount()
        loadContent()
        displayCommentsView()
        
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
        })
    }
    
    func resolveAndDisplayClaim() {
        displayResolving()
        
        let url = claimUrl!.description

        channelClaim = Lbry.cachedClaim(url: url)
        if channelClaim != nil {
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
    
    func checkCommentsDisabled(_ commentsDisabled: Bool) {
        DispatchQueue.main.async {
            self.commentsDisabled = !commentsDisabled
            self.displayCommentsView()
        }
    }
    
    func displayClaim() {
        resolvingView.isHidden = true
        
        if channelClaim?.value != nil {
            Lbryio.areCommentsEnabled(channelId: channelClaim!.claimId!, channelName: channelClaim!.name!, completion: { enabled in
                self.commentsDisabledChecked = true
                self.checkCommentsDisabled(!enabled)
            })
            
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
        
        // schedule livestream timer
        livestreamTimer = Timer.scheduledTimer(timeInterval: livestreamTimerInterval, target: self, selector: #selector(self.checkLivestream), userInfo: nil, repeats: true)
    }
    
    func loadAndDisplayFollowerCount() {
        var options = Dictionary<String, String>()
        options["claim_id"] = channelClaim?.claimId
        try! Lbryio.call(resource: "subscription", action: "sub_count", options: options, method: Lbryio.methodGet, completion: { data, error in
            guard let data = data, error == nil else {
                return
            }
            DispatchQueue.main.async {
                let formatter = Helper.interactionCountFormatter
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
        Lbry.apiCall(method: Lbry.Methods.claimSearch,
                     params: claimSearchOptions as NSDictionary,
                     completion: didLoadContent)
    }
    
    func didLoadContent(_ result: Result<Page<Claim>, Error>) {
        loadingContent = false
        contentLoadingContainer.isHidden = true
        guard case let .success(page) = result else {
            result.showErrorIfPresent()
            return
        }
        lastPageReached = page.isLastPage
        claims.append(contentsOf: page.items)
        contentListView.reloadData()
        checkNoContent()
        checkLivestream()
    }
    
    @objc func checkLivestream() {
        if (loadingContent) {
            return
        }
        
        loadingContent = true
        
        let channelIds: [String] = [channelClaim?.claimId ?? ""]
        let hasNoSourceOptions = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: channelIds, notChannelIds: nil, claimIds: nil, orderBy: Helper.sortByItemValues[1], releaseTime: nil, maxDuration: nil, limitClaimsPerChannel: 0, hasNoSource: true, page: 1, pageSize: pageSize)
        Lbry.apiCall(method: Lbry.Methods.claimSearch,
                     params: hasNoSourceOptions as NSDictionary,
                     completion: didCheckLivestream)
    }
    
    func didCheckLivestream(_ result: Result<Page<Claim>, Error>) {
        loadingContent = false
        guard case let .success(page) = result,
              let claim = page.items.first else {
            result.showErrorIfPresent()
            return
        }
        let url = URL(string: String(format: "https://api.bitwave.tv/v1/odysee/live/%@", channelClaim!.claimId!))
        let session = URLSession.shared
        var req = URLRequest(url: url!)
        req.httpMethod = "GET"
        
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
            guard let data = data, error == nil else {
                // handle error
                return
            }
            do {
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let livestreamData = response?["data"] as? [String: Any] {
                    let isLive = livestreamData["live"] as? Bool ?? false
                    if isLive {
                        // only show the livestream claim at the top if the channel is actually live
                        DispatchQueue.main.async {
                            self.claims.insert(claim, at: 0)
                            self.contentListView.reloadData()
                        }
                        
                        return
                    }
                }
            } catch {
                // pass
            }
        });
        task.resume();
    }
    
    func checkNoContent() {
        noChannelContentView.isHidden = claims.count > 0
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
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == contentListView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
            
            let claim: Claim = claims[indexPath.row]
            cell.setClaim(claim: claim)
                
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
        }
        
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == sortByPicker {
            return Helper.sortByItemNames[row]
        } else if pickerView == contentFromPicker {
            return Helper.contentFromItemNames[row]
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
        self.view.endEditing(true)
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
              
                Lbryio.subscriptionsDirty = true
                Lbry.saveSharedUserState(completion: { success, err in
                    guard err == nil else {
                        // pass
                        return
                    }
                    if (success) {
                        // run wallet sync
                        Lbry.pushSyncWallet()
                    }
                })
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
            let fetchRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "url == %@", url)
            let subs = try! context.fetch(fetchRequest)
            for sub in subs {
                context.delete(sub)
            }
            
            do {
                try context.save()
            } catch {
                // pass
            }
        }
    }
    
    func showError(error: Error?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
        }
    }
    
    func showError(message: String?) {
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
