//
//  FollowingViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 28/11/2020.´
//

import CoreData
import Firebase
import OrderedCollections
import UIKit

class FollowingViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
    UITableViewDelegate, UITableViewDataSource, WalletSyncObserver
{
    static let suggestedFollowCount = 5
    let keySyncObserver = "following_vc"

    @IBOutlet var suggestedView: UIView!
    @IBOutlet var mainView: UIView! // the view to display when the user is following at least one person

    @IBOutlet var suggestedFollowsView: UICollectionView!
    @IBOutlet var suggestedFollowsButton: UIButton!

    @IBOutlet var channelListView: UICollectionView!
    @IBOutlet var contentListView: UITableView!

    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var sortByLabel: UILabel!
    @IBOutlet var contentFromLabel: UILabel!

    var selectedChannelClaim: Claim?
    var suggestedFollows = OrderedSet<Claim>()
    var following = OrderedSet<Claim>()
    var subscriptions: [Subscription] = []
    var selectedChannelIds: [String] = []
    var selectedSuggestedFollows = [String: Claim]()

    let suggestedPageSize: Int = 42
    let refreshControl = UIRefreshControl()
    var currentSuggestedPage: Int = 1
    var lastSuggestedPageReached: Bool = false
    var loadingSuggested: Bool = false
    var showingSuggested: Bool = false

    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loadingContent: Bool = false
    var claims = OrderedSet<Claim>()

    var currentSortByIndex = 1 // default to New content
    var currentContentFromIndex = 1 // default to Past week

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.addWalletSyncObserver(key: keySyncObserver, observer: self)
        view.isHidden = !Lbryio.isSignedIn()

        // check if current user is signed in
        if !Lbryio.isSignedIn() {
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
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Subscriptions",
                AnalyticsParameterScreenClass: "FollowingViewController",
            ]
        )

        if Lbryio.isSignedIn() {
            if Lbryio.subscriptionsDirty {
                loadLocalSubscriptions(true)
            } else {
                loadRemoteSubscriptions()
            }
        }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        appDelegate.mainController.adjustMiniPlayerBottom(
            bottom: Helper.miniPlayerBottomWithTabBar(appDelegate: appDelegate))
    }

    func removeFollowing(claim: Claim) {
        DispatchQueue.main.async {
            self.following.remove(claim)
            self.claims.removeAll()
            self.channelListView.reloadData()
            self.contentListView.reloadData()
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
            for i in following.indices {
                if following[i].claimId == selectedChannelClaim?.claimId {
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
        contentListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")

        refreshControl.attributedTitle = NSAttributedString(string: String.localized("Pull down to refresh"))
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        refreshControl.tintColor = Helper.primaryColor
        contentListView.addSubview(refreshControl)
    }

    @objc func refresh(_ sender: AnyObject) {
        if loadingContent {
            return
        }

        resetSubscriptionContent()
        loadSubscriptionContent()
    }

    func loadLocalSubscriptions(_ refresh: Bool = false) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Subscription")
        fetchRequest.returnsObjectsAsFaults = false
        let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { asyncFetchResult in
            guard let subscriptions = asyncFetchResult.finalResult as? [Subscription] else { return }
            self.subscriptions = subscriptions
            if self.subscriptions.count == 0 {
                // load remote
                self.loadRemoteSubscriptions()
            } else {
                self.resolveChannelList(refresh)
                if !self.showingSuggested {
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
            } catch {
                print("NSAsynchronousFetchRequest error: \(error)")
            }
        }
    }

    func loadRemoteSubscriptions() {
        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }

        do {
            try Lbryio.get(resource: "subscription", action: "list", completion: { data, error in
                guard let data = data, error == nil else {
                    print(error!)
                    return
                }

                if (data as? NSNull) != nil {
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
                        let subUrl = LbryUri.tryParse(
                            url: String(format: "%@#%@", channelName, sub["claim_id"] as! String),
                            requireProto: false
                        )
                        if subUrl != nil {
                            let urlString = subUrl?.description
                            do {
                                let jsonData = try JSONSerialization.data(
                                    withJSONObject: sub,
                                    options: [.prettyPrinted, .sortedKeys]
                                )
                                let subscription: LbrySubscription? = try JSONDecoder()
                                    .decode(LbrySubscription.self, from: jsonData)
                                Lbryio.addSubscription(sub: subscription!, url: urlString)
                            } catch {
                                // skip if an error occurred
                            }

                            self.addSubscription(
                                url: urlString!,
                                channelName: channelName,
                                isNotificationsDisabled: sub["is_notifications_disabled"] as! Bool,
                                reloadAfter: false
                            )
                        }
                    }
                    if subs.count > 0 {
                        hasSubs = true
                        self.loadLocalSubscriptions()
                    }
                }

                if !hasSubs {
                    DispatchQueue.main.async {
                        self.loadingContainer.isHidden = true
                        self.showingSuggested = true
                        self.loadSuggestedFollows()
                    }
                }
            })
        } catch {
            print(error)
        }
    }

    func loadSuggestedFollows() {
        DispatchQueue.main.async {
            self.suggestedView.isHidden = false
            self.mainView.isHidden = true

            self.loadingContainer.isHidden = false
        }

        Lbry.apiCall(
            method: Lbry.Methods.claimSearch,
            params: .init(
                claimType: [.channel],
                page: currentSuggestedPage,
                pageSize: suggestedPageSize,
                notTags: Constants.NotTags,
                notChannelIds: following.map { $0.claimId! },
                claimIds: ContentSources.DynamicContentCategories
                    .filter { $0.name == HomeViewController.categoryKeyPrimaryContent }.first?.channelIds,
                orderBy: ["effective_amount"]
            )
        )
        .subscribeResult(didLoadSuggestedFollows)
    }

    func didLoadSuggestedFollows(_ result: Result<Page<Claim>, Error>) {
        loadingSuggested = false
        loadingContainer.isHidden = true
        guard case let .success(page) = result else {
            return
        }
        suggestedFollows.append(contentsOf: page.items)
        suggestedFollowsView.reloadData()
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
        if loadingContent {
            return
        }

        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }

        loadingContent = true

        let channelIds = !selectedChannelIds.isEmpty ?
            selectedChannelIds :
            following.compactMap(\.claimId)

        if channelIds.count > 0 {
            let releaseTimeValue = currentSortByIndex == 2 ? Helper
                .buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : nil
            Lbry.apiCall(
                method: Lbry.Methods.claimSearch,
                params: .init(
                    claimType: [.stream],
                    page: currentPage,
                    pageSize: pageSize,
                    releaseTime: [releaseTimeValue].compactMap { $0 } + [Helper.releaseTimeBeforeFuture],
                    notTags: Constants.NotTags,
                    channelIds: channelIds,
                    orderBy: Helper.sortByItemValues[currentSortByIndex]
                )
            )
            .subscribeResult(didLoadSubscriptionContent)
        }
    }

    func didLoadSubscriptionContent(_ result: Result<Page<Claim>, Error>) {
        loadingContent = false
        loadingContainer.isHidden = true

        guard case let .success(page) = result else {
            result.showErrorIfPresent()
            return
        }

        lastPageReached = page.isLastPage
        claims.append(contentsOf: page.items)
        claims.sort(by: { $0.value?.releaseTime ?? "0" > $1.value?.releaseTime ?? "0" })
        contentListView.reloadData()
        refreshControl.endRefreshing()
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showMessage(message: message)
        }
    }

    @IBAction func doneTapped(_ sender: UIButton) {
        if following.count == 0 {
            showMessage(message: String.localized("Please select one or more creators to follow"))
            return
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

        if claims.count > indexPath.row {
            let claim: Claim = claims[indexPath.row]
            cell.setClaim(claim: claim)
        } else {
            cell.setClaim(claim: Claim())
        }

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
        if collectionView == suggestedFollowsView {
            return suggestedFollows.count
        } else {
            return following.count
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if collectionView == suggestedFollowsView {
            let claim: Claim = suggestedFollows[indexPath.row]
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "suggested_channel_cell",
                for: indexPath
            ) as! SuggestedChannelCollectionViewCell
            cell.setClaim(claim: claim)
            return cell
        } else {
            let claim = following[indexPath.row]
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "followed_channel_cell",
                for: indexPath
            ) as! ChannelCollectionViewCell
            cell.setClaim(claim: claim)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == suggestedFollowsView {
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
            if claim.selected {
                claim.selected = false
                selectedChannelClaim = nil
            } else {
                claim.selected = true
                if !selectedChannelIds.contains(claim.claimId!) {
                    selectedChannelIds.append(claim.claimId!)
                }
                selectedChannelClaim = claim
            }

            if prevSelectedChannelIds != selectedChannelIds {
                resetSubscriptionContent()
                loadSubscriptionContent()
            }

            collectionView.reloadItems(at: [indexPath])
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if collectionView == suggestedFollowsView {
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

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if collectionView == suggestedFollowsView {
            return CGSize(width: view.frame.width / 3.0 - 4, height: 150)
        } else {
            return CGSize(width: 96, height: 120)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 6
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 4
    }

    func subscribeOrUnsubscribe(claim: Claim?, notificationsDisabled: Bool, unsubscribing: Bool) {
        do {
            var options = [String: String]()
            options["claim_id"] = claim?.claimId!
            if !unsubscribing {
                options["channel_name"] = claim?.name
                options["notifications_disabled"] = String(notificationsDisabled)
            }

            let subUrl: LbryUri = try LbryUri.parse(url: (claim?.permanentUrl!)!, requireProto: false)
            try Lbryio.get(
                resource: "subscription",
                action: unsubscribing ? "delete" : "new",
                options: options,
                completion: { data, error in
                    guard let _ = data, error == nil else {
                        print(error!)
                        return
                    }

                    if !unsubscribing {
                        Lbryio.addSubscription(
                            sub: LbrySubscription.fromClaim(
                                claim: claim!,
                                notificationsDisabled: notificationsDisabled
                            ),
                            url: subUrl.description
                        )
                        self.addSubscription(
                            url: subUrl.description,
                            channelName: subUrl.channelName!,
                            isNotificationsDisabled: notificationsDisabled,
                            reloadAfter: true
                        )
                    } else {
                        Lbryio.removeSubscription(subUrl: subUrl.description)
                        self.removeSubscription(url: subUrl.description, channelName: subUrl.channelName!)
                    }
                }
            )
        } catch {
            print(error)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == contentListView {
            if contentListView.contentOffset
                .y >= (contentListView.contentSize.height - contentListView.bounds.size.height)
            {
                if !loadingContent, !lastPageReached {
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

            if !self.subscriptions.contains(subToSave) {
                self.subscriptions.append(subToSave)
            }

            appDelegate.saveContext()
        }

        // TODO: wallet sync
        if reloadAfter {
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
        Lbry.apiCall(
            method: Lbry.Methods.resolve,
            params: .init(
                urls: subscriptions.compactMap(\.url)
            )
        )
        .subscribeResult { result in
            self.didResolveChannelList(result, refresh: refresh)
        }
    }

    func didResolveChannelList(_ result: Result<ResolveResult, Error>, refresh: Bool) {
        guard case let .success(resolve) = result else {
            result.showErrorIfPresent()
            return
        }

        if refresh {
            following.removeAll(keepingCapacity: true)
        }
        following.append(contentsOf: resolve.claims.values)

        checkSelectedChannel()
        channelListView.reloadData()
        contentListView.reloadData()

        if Lbryio.subscriptionsDirty {
            loadingContent = false
            resetSubscriptionContent()
            let index = indexForSelectedChannelClaim()
            if index == -1 {
                selectedChannelIds = []
            }
            Lbryio.subscriptionsDirty = false
        }

        loadSubscriptionContent()
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
        _ = Helper.showPickerActionSheet(
            title: String.localized("Sort content by"),
            origin: sortByLabel,
            rows: Helper.sortByItemNames,
            initialSelection: currentSortByIndex
        ) { _, selectedIndex, _ in
            let prevIndex = self.currentSortByIndex
            self.currentSortByIndex = selectedIndex
            if prevIndex != self.currentSortByIndex {
                self.checkUpdatedSortBy()
                self.resetSubscriptionContent()
                self.loadSubscriptionContent()
            }
        }
    }

    @IBAction func contentFromLabelTapped(_ sender: Any) {
        _ = Helper.showPickerActionSheet(
            title: String.localized("Content from"),
            origin: contentFromLabel,
            rows: Helper.contentFromItemNames,
            initialSelection: currentContentFromIndex
        ) { _, selectedIndex, _ in
            let prevIndex = self.currentContentFromIndex
            self.currentContentFromIndex = selectedIndex
            if prevIndex != self.currentContentFromIndex {
                self.checkUpdatedContentFrom()
                self.resetSubscriptionContent()
                self.loadSubscriptionContent()
            }
        }
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
                addSubscription(
                    url: uri!.description,
                    channelName: uri!.channelName!,
                    isNotificationsDisabled: sub.notificationsDisabled ?? true,
                    reloadAfter: false
                )
            }
        }

        loadLocalSubscriptions(true)
    }
}
