//
//  FollowingViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 28/11/2020.
//

import Firebase
import CoreData
import UIKit

class FollowingViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, WalletSyncObserver {
    
    static let suggestedFollowCount = 5
    let keySyncObserver = "following_vc"
    
    @IBOutlet weak var suggestedView: UIView!
    @IBOutlet weak var mainView: UIView! // the view to display when the user is following at least one person
    
    @IBOutlet weak var suggestedFollowsView: UICollectionView!
    @IBOutlet weak var suggestedFollowsButton: UIButton!
    
    @IBOutlet weak var channelListView: UICollectionView!
    @IBOutlet weak var contentListView: UITableView!
    
    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var sortByLabel: UILabel!
    @IBOutlet weak var contentFromLabel: UILabel!
    
    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!
    
    var selectedChannelClaim: Claim? = nil
    var suggestedFollows: [Claim] = []
    var following: [Claim] = []
    var subscriptions: [Subscription] = []
    var selectedChannelIds: [String] = []
    var selectedSuggestedFollows: Dictionary<String, Claim> = Dictionary<String, Claim>()
    
    let suggestedPageSize: Int = 42
    var currentSuggestedPage: Int = 1
    var lastSuggestedPageReached: Bool = false
    var loadingSuggested: Bool = false
    var showingSuggested: Bool = false
    var suggestedClaimSearchOptions = Dictionary<String, Any>()
    
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
        appDelegate.mainController.addWalletSyncObserver(key: keySyncObserver, observer: self)
        self.view.isHidden = !Lbryio.isSignedIn()
        
        // check if current user is signed in
        if (!Lbryio.isSignedIn()) {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.removeWalletSyncObserver(key: keySyncObserver)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Subscriptions", AnalyticsParameterScreenClass: "FollowingViewController"])
        
        if (Lbryio.isSignedIn()) {
            if Lbryio.subscriptionsDirty {
                loadLocalSubscriptions(true)
            } else {
                loadRemoteSubscriptions()
            }
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.toggleHeaderVisibility(hidden: false)
            let bottom = (appDelegate.mainTabViewController?.tabBar.frame.size.height)! + 2
            appDelegate.mainController.adjustMiniPlayerBottom(bottom: bottom)
        }
    }
    
    func checkSelectedChannel() {
        DispatchQueue.main.async {
            if self.selectedChannelClaim != nil {
                for i in self.following.indices {
                    if self.following[i].claimId == self.selectedChannelClaim?.claimId {
                        self.following[i].selected = true
                        self.channelListView.reloadItems(at: [IndexPath(item: i, section: 0)])
                        break
                    }
                }
            }
        }
    }
    
    func indexForSelectedChannelClaim() -> Int {
        if selectedChannelClaim != nil {
            for i in self.following.indices {
                if self.following[i].claimId == selectedChannelClaim?.claimId {
                    return i
                }
            }
        }
        
        return -1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadingContainer.layer.cornerRadius = 20
        suggestedFollowsView.allowsMultipleSelection = true
        channelListView.allowsMultipleSelection = false
    }
    
    func updateClaimSearchOptions() {
        let allChannelIds = following.map { $0.claimId } as! [String]
        var channelIdFilter: [String]? = allChannelIds
        if (selectedChannelIds.count > 0) {
            channelIdFilter = selectedChannelIds
        }
        
        let orderByValue = Helper.sortByItemValues[currentSortByIndex]
        let releaseTimeValue = currentSortByIndex == 2 ? Helper.buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : nil
        self.claimSearchOptions = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: channelIdFilter, notChannelIds: nil, claimIds: nil, orderBy: orderByValue, releaseTime: releaseTimeValue, maxDuration: nil, limitClaimsPerChannel: 0, page: currentPage, pageSize: pageSize)
    }
    
    func loadLocalSubscriptions(_ refresh: Bool = false) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Subscription")
        fetchRequest.returnsObjectsAsFaults = false
        let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { asyncFetchResult in
            guard let subscriptions = asyncFetchResult.finalResult as? [Subscription] else { return }
            self.subscriptions = subscriptions
            if (self.subscriptions.count == 0) {
                // load remote
                self.loadRemoteSubscriptions()
            } else {
                self.resolveChannelList(refresh)
                if (!self.showingSuggested) {
                    DispatchQueue.main.async {
                        self.suggestedView.isHidden = true
                        self.mainView.isHidden = false
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.newBackgroundContext()
            do {
                try context.execute(asyncFetchRequest)
            } catch let error {
                print("NSAsynchronousFetchRequest error: \(error)")
            }
        }
    }
    
    func loadRemoteSubscriptions() {
        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }
        
        do {
            try Lbryio.call(resource: "subscription", action: "list", options: nil, method: Lbryio.methodGet, completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }
                
                if ((data as? NSNull) != nil) {
                    DispatchQueue.main.async {
                        self.showingSuggested = true
                        self.loadSuggestedFollows()
                        return
                    }
                }
                
                var hasSubs = false
                if let subs = data as? [[String: Any]] {
                    for sub in subs {
                        let channelName = sub["channel_name"] as! String
                        let subUrl = LbryUri.tryParse(url: String(format: "%@#%@", channelName, sub["claim_id"] as! String), requireProto: false)
                        if (subUrl != nil) {
                            let urlString = subUrl?.description
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: sub, options: [.prettyPrinted, .sortedKeys])
                                let subscription: LbrySubscription? = try JSONDecoder().decode(LbrySubscription.self, from: jsonData)
                                Lbryio.addSubscription(sub: subscription!, url: urlString)
                            } catch {
                                // skip if an error occurred
                            }
                            
                            self.addSubscription(url: urlString!, channelName: channelName, isNotificationsDisabled: sub["is_notifications_disabled"] as! Bool, reloadAfter: false)
                        }
                    }
                    if (subs.count > 0) {
                        hasSubs = true
                        self.loadLocalSubscriptions()
                    }
                }
                
                if (!hasSubs) {
                    DispatchQueue.main.async {
                        self.loadingContainer.isHidden = true
                        self.showingSuggested = true
                        self.loadSuggestedFollows()
                    }
                }
            })
        } catch let error {
            print(error)
        }
    }
    
    func updateSuggestedClaimSearchOptions() {
        let followedChannelIds = following.map { $0.claimId } as! [String]
        suggestedClaimSearchOptions = Lbry.buildClaimSearchOptions(claimType: ["channel"], anyTags: nil, notTags: nil, channelIds: nil, notChannelIds: followedChannelIds, claimIds: ContentSources.PrimaryChannelContentIds, orderBy: ["effective_amount"], releaseTime: nil, maxDuration: nil, limitClaimsPerChannel: 0, page: currentSuggestedPage, pageSize: suggestedPageSize)
    }
    
    func loadSuggestedFollows() {
        DispatchQueue.main.async {
            self.suggestedView.isHidden = false
            self.mainView.isHidden = true
            
            self.loadingContainer.isHidden = false
        }
        
        updateSuggestedClaimSearchOptions()
        Lbry.apiCall(method: Lbry.methodClaimSearch, params: suggestedClaimSearchOptions, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }
                
                let result = data["result"] as? [String: Any]
                let items = result?["items"] as? [[String: Any]]
                if (items != nil) {
                    var loadedClaims: [Claim] = []
                    items?.forEach{ item in
                        let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                        do {
                            let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                            if (claim != nil && !self.suggestedFollows.contains(where: { $0.claimId == claim?.claimId }) && !Lbryio.isClaimFiltered(claim!) && !Lbryio.isClaimBlocked(claim!)) {
                                Lbry.addClaimToCache(claim: claim)
                                loadedClaims.append(claim!)
                            }
                        } catch let error {
                            print(error)
                        }
                    }
                    self.suggestedFollows.append(contentsOf: loadedClaims)
                }
            
                self.loadingSuggested = false
                DispatchQueue.main.async {
                    self.loadingContainer.isHidden = true
                    self.suggestedFollowsView.reloadData()
                }
        })
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func loadSubscriptionContent() {
        if (loadingContent) {
            return
        }
        
        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }
        
        loadingContent = true
        updateClaimSearchOptions()
        Lbry.apiCall(method: Lbry.methodClaimSearch, params: claimSearchOptions, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            if (data != nil) {
                let result = data?["result"] as? [String: Any]
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
                            if (claim != nil && !self.claims.contains(where: { $0.claimId == claim?.claimId }) && !Lbryio.isClaimFiltered(claim!) && !Lbryio.isClaimBlocked(claim!)) {
                                loadedClaims.append(claim!)
                            }
                        } catch let error {
                            print(error)
                        }
                    }
                    self.claims.append(contentsOf: loadedClaims)
                    //self.claims.sort(by: { Int64($0.value?.releaseTime ?? "0")! > Int64($1.value?.releaseTime ?? "0")! })
                }
            }
            
            self.loadingContent = false
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
                //self.checkNoContent()
                self.contentListView.reloadData()
                //self.refreshControl.endRefreshing()
            }
        })
    }
    
    func showMessage(message: String?) {
        let sb = Snackbar()
        sb.sbLength = .long
        sb.createWithText(message ?? "")
        sb.show()
    }
    
    @IBAction func doneTapped(_ sender: UIButton) {
        if (following.count == 0) {
            showMessage(message: String.localized("Please select one or more creators to follow"))
            return;
        }
        
        suggestedView.isHidden = true
        mainView.isHidden = false
        showingSuggested = false
        
        loadSubscriptionContent()
    }

    @IBAction func discoverTapped(_ sender: Any) {
        suggestedView.isHidden = false
        mainView.isHidden = true
        showingSuggested = true
        
        loadSuggestedFollows()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return claims.count
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
        
        appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
        appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if (collectionView == suggestedFollowsView) {
            return suggestedFollows.count
        } else {
            return following.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if (collectionView == suggestedFollowsView) {
            let claim: Claim = suggestedFollows[indexPath.row]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "suggested_channel_cell", for: indexPath) as! SuggestedChannelCollectionViewCell
            cell.setClaim(claim: claim)
            return cell
        } else {
            let claim = following[indexPath.row]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "followed_channel_cell", for: indexPath) as! ChannelCollectionViewCell
            cell.setClaim(claim: claim)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if (collectionView == suggestedFollowsView) {
            let claim = suggestedFollows[indexPath.row]
            selectedSuggestedFollows[claim.claimId!] = claim
            subscribeOrUnsubscribe(claim: claim, notificationsDisabled: true, unsubscribing: false)
            
            let cell = collectionView.cellForItem(at: indexPath) as? SuggestedChannelCollectionViewCell
            cell?.backgroundColor = Helper.lightPrimaryColor
            cell?.tagLabel.textColor = UIColor.white
            cell?.titleLabel.textColor = UIColor.white
        } else {
            // TODO: Refresh claim search with selected channel ids
            let prevSelectedChannelIds = selectedChannelIds
            selectedChannelIds.removeAll()
            
            let claim = following[indexPath.row]
            deselectChannels(except: claim)
            if (claim.selected) {
                claim.selected = false
                selectedChannelClaim = nil
            } else {
                claim.selected = true
                if (!selectedChannelIds.contains(claim.claimId!)) {
                    selectedChannelIds.append(claim.claimId!)
                }
                selectedChannelClaim = claim
            }
            
            if (prevSelectedChannelIds != selectedChannelIds) {
                resetSubscriptionContent()
                loadSubscriptionContent()
            }
            
            collectionView.reloadItems(at: [indexPath])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if (collectionView == suggestedFollowsView) {
            let claim = suggestedFollows[indexPath.row]
            selectedSuggestedFollows.removeValue(forKey: claim.claimId!)
            subscribeOrUnsubscribe(claim: claim, notificationsDisabled: true, unsubscribing: true)
            
            let cell = collectionView.cellForItem(at: indexPath) as? SuggestedChannelCollectionViewCell
            cell?.backgroundColor = UIColor.clear
            cell?.tagLabel.textColor = UIColor.label
            cell?.titleLabel.textColor = UIColor.label
        } else {
            let cell = collectionView.cellForItem(at: indexPath) as? ChannelCollectionViewCell
            cell?.backgroundColor = UIColor.clear
            cell?.titleLabel.textColor = UIColor.label
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if (collectionView == suggestedFollowsView) {
            return CGSize(width: view.frame.width / 3.0 - 4, height: 150)
        } else {
            return CGSize(width: 96, height: 120)
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 6
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func subscribeOrUnsubscribe(claim: Claim?, notificationsDisabled: Bool, unsubscribing: Bool) {
        do {
            var options = Dictionary<String, String>()
            options["claim_id"] = claim?.claimId!
            if (!unsubscribing) {
                options["channel_name"] = claim?.name
                options["notifications_disabled"] = String(notificationsDisabled)
            }
            
            let subUrl: LbryUri = try LbryUri.parse(url: (claim?.permanentUrl!)!, requireProto: false)
            try Lbryio.call(resource: "subscription", action: unsubscribing ? "delete" : "new", options: options, method: Lbryio.methodGet, completion: { data, error in
                guard let _ = data, error == nil else {
                    print(error!)
                    return
                }

                if (!unsubscribing) {
                    Lbryio.addSubscription(sub: LbrySubscription.fromClaim(claim: claim!, notificationsDisabled: notificationsDisabled), url: subUrl.description)
                    self.addSubscription(url: subUrl.description, channelName: subUrl.channelName!, isNotificationsDisabled: notificationsDisabled, reloadAfter: true)
                } else {
                    Lbryio.removeSubscription(subUrl: subUrl.description)
                    self.removeSubscription(url: subUrl.description, channelName: subUrl.channelName!)
                }
            })
        } catch let error {
            print(error)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView == contentListView) {
            if (contentListView.contentOffset.y >= (contentListView.contentSize.height - contentListView.bounds.size.height)) {
                if (!loadingContent && !lastPageReached) {
                    currentPage += 1
                    loadSubscriptionContent()
                }
            }
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
            
            if (!self.subscriptions.contains(subToSave)) {
                self.subscriptions.append(subToSave)
            }
            
            appDelegate.saveContext()
        }
        
        // TODO: wallet sync
        if (reloadAfter) {
            loadLocalSubscriptions()
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
            
            if subs.count > 0 {
                let subToDelete = subs[0]
                context.delete(subToDelete)
                self.subscriptions = self.subscriptions.filter { $0 != subToDelete }
            }
            
            do {
                try context.save()
            } catch {
                // pass
            }
        }
        
        loadLocalSubscriptions()
    }
    
    func resolveChannelList(_ refresh: Bool = false) {
        let urls = subscriptions.map{ $0.url }
        var params: Dictionary<String, Any> = Dictionary<String, Any>()
        params["urls"] = urls
        
        //let prevFollowing = self.following
        var newFollowing: [Claim] = []
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                // display no results
                // channels could not be resolved
                print(error!)
                return
            }
            
            var claimResults: [Claim] = []
            let result = data["result"] as! NSDictionary
            for (_, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if (claim != nil && !(claim?.claimId ?? "").isBlank) {
                        Lbry.addClaimToCache(claim: claim)
                        if (!self.following.contains(where: { $0.claimId == claim?.claimId })) {
                            claimResults.append(claim!)
                        }
                        if (refresh && !newFollowing.contains(where: { $0.claimId == claim?.claimId })) {
                            newFollowing.append(claim!)
                        }
                    }
                } catch let error {
                    print(error)
                }
            }
            
            if refresh {
                self.following = newFollowing
            } else {
                self.following.append(contentsOf: claimResults)
            }
            
            DispatchQueue.main.async {
                self.checkSelectedChannel()
                self.channelListView.reloadData()
                self.contentListView.reloadData()
            }
            
            if Lbryio.subscriptionsDirty {
                self.loadingContent = false
                self.resetSubscriptionContent()
                let index = self.indexForSelectedChannelClaim()
                if index == -1 {
                    self.selectedChannelIds = []
                }
                Lbryio.subscriptionsDirty = false
            }
            self.loadSubscriptionContent()
        })
    }

    func deselectChannels(except: Claim) {
        for i in following.indices {
            if except.claimId == following[i].claimId {
                continue
            }
            following[i].selected = false
            channelListView.reloadItems(at: [IndexPath(item: i, section: 0)])
        }
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
    
    func resetSubscriptionContent() {
        currentPage = 1
        lastPageReached = false
        claims.removeAll()
        DispatchQueue.main.async {
            self.contentListView.reloadData()
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
    
    @IBAction func sortByLabelTapped(_ sender: Any) {
       let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Sort content by"), dataSource: self, delegate: self, parent: self, handler: { _ in
            let selectedIndex = self.sortByPicker.selectedRow(inComponent: 0)
            let prevIndex = self.currentSortByIndex
            self.currentSortByIndex = selectedIndex
            if (prevIndex != self.currentSortByIndex) {
                self.checkUpdatedSortBy()
                self.resetSubscriptionContent()
                self.loadSubscriptionContent()
            }
        })
        
        sortByPicker = picker
        present(alert, animated: true, completion: {
            self.sortByPicker.selectRow(self.currentSortByIndex, inComponent: 0, animated: true)
        })
    }
    
    @IBAction func contentFromLabelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Content from"), dataSource: self, delegate: self, parent: self, handler: { _ in
            let selectedIndex = self.contentFromPicker.selectedRow(inComponent: 0)
            let prevIndex = self.currentContentFromIndex
            self.currentContentFromIndex = selectedIndex
            if (prevIndex != self.currentContentFromIndex) {
                self.checkUpdatedContentFrom()
                self.resetSubscriptionContent()
                self.loadSubscriptionContent()
            }
        })
        
        contentFromPicker = picker
        present(alert, animated: true, completion: {
            self.contentFromPicker.selectRow(self.currentContentFromIndex, inComponent: 0, animated: true)
        })
    }
    
    func syncCompleted() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Subscription")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            let context: NSManagedObjectContext! = appDelegate.persistentContainer.viewContext
            try context.execute(deleteRequest)
        } catch {
            // pass
            return
        }
        
        // save cached subscriptions
        subscriptions.removeAll()
        for (url, sub) in Lbryio.cachedSubscriptions {
            let uri: LbryUri? = LbryUri.tryParse(url: url, requireProto: false)
            if uri != nil {
                self.addSubscription(url: uri!.description, channelName: uri!.channelName!, isNotificationsDisabled: sub.notificationsDisabled ?? true, reloadAfter: false)
            }
        }
        
        loadLocalSubscriptions(true)
    }
}
