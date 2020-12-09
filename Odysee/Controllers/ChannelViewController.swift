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

class ChannelViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource {
    
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
    
    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!
    
    var claimSearchOptions = Dictionary<String, Any>()
    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loadingContent: Bool = false
    var claims: [Claim] = []
    
    var currentSortByIndex = 1 // default to New content
    var currentContentFromIndex = 1 // default to Past week
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        
        let window = UIApplication.shared.windows.filter{ $0.isKeyWindow }.first!
        let safeAreaFrame = window.safeAreaLayoutGuide.layoutFrame
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: window.frame.maxY - safeAreaFrame.maxY + 2)
        
        if channelClaim != nil {
            checkFollowing()
            checkNotificationsDisabled()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Channel"])
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        } else {
            displayNothingAtLocation()
        }
    }
    
    func showClaimAndCheckFollowing() {
        displayClaim()
        loadAndDisplayFollowerCount()
        loadContent()
        
        checkFollowing()
        checkNotificationsDisabled()
    }
    
    func resolveAndDisplayClaim() {
        displayResolving()
        
        let url = claimUrl!.description
        if Lbry.claimCacheByUrl[url] != nil {
            channelClaim = Lbry.claimCacheByUrl[url]
            showClaimAndCheckFollowing()
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
    
    func checkUpdatedSortBy() {
        let itemName = Helper.sortByItemNames[currentSortByIndex]
        sortByLabel.text = String(format: "%@ ▾", String(itemName.prefix(upTo: itemName.firstIndex(of: " ")!)))
        contentFromLabel.isHidden = currentSortByIndex != 2
    }
    
    func checkUpdatedContentFrom() {
        contentFromLabel.text = String(format: "%@ ▾", String(Helper.contentFromItemNames[currentContentFromIndex]))
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tableView == contentListView) {
            return claims.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
        
        let claim: Claim = claims[indexPath.row]
        cell.setClaim(claim: claim)
            
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = claims[indexPath.row]
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = claim
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = .fromTop
        appDelegate.mainNavigationController?.view.layer.add(transition, forKey: kCATransition)
        appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (pickerView == sortByPicker) {
            return Helper.sortByItemNames.count
        } else {
            return Helper.contentFromItemNames.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if (pickerView == sortByPicker) {
            return Helper.sortByItemNames[row]
        } else {
            return Helper.contentFromItemNames[row]
        }
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
        let vc = storyboard?.instantiateViewController(identifier: "support_vc") as! SupportViewController
        vc.claim = channelClaim!
        vc.modalPresentationStyle = .overCurrentContext
        present(vc, animated: true)
    }
    
    @IBAction func followUnfollowActionTapped(_ sender: Any) {
        subscribeOrUnsubscribe(claim: channelClaim!, notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: channelClaim!), unsubscribing: Lbryio.isFollowing(claim: channelClaim!))
    }
    
    @IBAction func bellActionTapped(_ sender: Any) {
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
    
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
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
