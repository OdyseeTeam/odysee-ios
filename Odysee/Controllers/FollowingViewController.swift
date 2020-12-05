//
//  FollowingViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 28/11/2020.
//

import CoreData
import UIKit

class FollowingViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource {
    
    static let suggestedFollowCount = 5
    
    @IBOutlet weak var suggestedView: UIView!
    @IBOutlet weak var mainView: UIView! // the view to display when the user is following at least one person
    
    @IBOutlet weak var suggestedFollowsView: UICollectionView!
    @IBOutlet weak var suggestedFollowsButton: UIButton!
    
    @IBOutlet weak var channelListView: UICollectionView!
    @IBOutlet weak var contentListView: UITableView!
    
    @IBOutlet weak var loadingContainer: UIView!
    
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // check if current user is signed in
        if (!Lbryio.isSignedIn()) {
            // show the sign in view
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (Lbryio.isSignedIn()) {
            loadRemoteSubscriptions()
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.toggleHeaderVisibility(hidden: false)
            let bottom = (appDelegate.mainTabViewController?.tabBar.frame.size.height)! + 2
            appDelegate.mainController.adjustMiniPlayerBottom(bottom: bottom)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadingContainer.layer.cornerRadius = 20
        suggestedFollowsView.allowsMultipleSelection = true
    }
    
    func updateClaimSearchOptions() {
        let allChannelIds = following.map { $0.claimId } as! [String]
        var channelIdFilter: [String]? = allChannelIds
        if (selectedChannelIds.count > 0) {
            channelIdFilter = selectedChannelIds
        }
        self.claimSearchOptions = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: channelIdFilter, notChannelIds: nil, claimIds: nil, orderBy: ["release_time"], releaseTime: nil, maxDuration: nil, limitClaimsPerChannel: 0, page: currentPage, pageSize: pageSize)
    }
    
    func loadLocalSubscriptions() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Subscription")
        fetchRequest.returnsObjectsAsFaults = false
        let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { asyncFetchResult in
            guard let subscriptions = asyncFetchResult.finalResult as? [Subscription] else { return }
            self.subscriptions = subscriptions
            
            if (self.subscriptions.count == 0) {
                // load remote
                self.loadRemoteSubscriptions()
            } else {
                self.resolveChannelList()
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
                    print(error)
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
                    print(error)
                    return
                }
                if (data != nil) {
                    let result = data["result"] as? [String: Any]
                    let items = result?["items"] as? [[String: Any]]
                    if (items != nil) {
                        var loadedClaims: [Claim] = []
                        items?.forEach{ item in
                            let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                            do {
                                let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                                if (claim != nil && !self.suggestedFollows.contains(where: { $0.claimId == claim?.claimId })) {
                                    Lbry.addClaimToCache(claim: claim)
                                    loadedClaims.append(claim!)
                                }
                            } catch let error {
                                print(error)
                            }
                        }
                        print(loadedClaims.count)
                        self.suggestedFollows.append(contentsOf: loadedClaims)
                    }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! FileTableViewCell
        
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
            let cell = collectionView.cellForItem(at: indexPath) as? ChannelCollectionViewCell
            if (cell?.backgroundColor == Helper.lightPrimaryColor) {
                cell?.backgroundColor = UIColor.clear
                cell?.titleLabel.textColor = UIColor.label
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                cell?.backgroundColor = Helper.lightPrimaryColor
                cell?.titleLabel.textColor = UIColor.white
                if (!selectedChannelIds.contains(claim.claimId!)) {
                    selectedChannelIds.append(claim.claimId!)
                }
            }
            
            if (prevSelectedChannelIds != selectedChannelIds) {
                currentPage = 1
                claims.removeAll()
                contentListView.reloadData()
                loadSubscriptionContent()
            }
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
                    print(error)
                    return
                }

                if (!unsubscribing) {
                    self.addSubscription(url: subUrl.description, channelName: subUrl.channelName!, isNotificationsDisabled: notificationsDisabled, reloadAfter: true)
                } else {
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
                if (!loadingContent) {
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
            let subToDelete = Subscription(context: context)
            subToDelete.url = url
            subToDelete.channelName = channelName
            
            self.subscriptions = self.subscriptions.filter { $0 != subToDelete }
            context.delete(subToDelete)
        }
        
        // TODO: wallet sync
        loadLocalSubscriptions()
    }
    
    func resolveChannelList() {
        let urls = subscriptions.map{ $0.url }
        var params: Dictionary<String, Any> = Dictionary<String, Any>()
        params["urls"] = urls
        
        let prevFollowing = self.following
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                // display no results
                // channels could not be resolved
                return
            }
            
            var claimResults: [Claim] = []
            let result = data["result"] as! NSDictionary
            for (_, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if (claim != nil && !(claim?.claimId ?? "").isBlank && !self.following.contains(where: { $0.claimId == claim?.claimId })) {
                        claimResults.append(claim!)
                    }
                } catch let error {
                    print(error)
                }
            }
            self.following.append(contentsOf: claimResults)
            
            DispatchQueue.main.async {
                if (prevFollowing != self.following) {
                    self.channelListView.reloadData()
                }
                self.contentListView.reloadData()
            }
            
            self.loadSubscriptionContent()
        })
    }
}
