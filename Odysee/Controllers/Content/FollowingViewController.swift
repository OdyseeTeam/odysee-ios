//
//  FollowingViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 28/11/2020.´
//

import FirebaseAnalytics
import OrderedCollections
import UIKit

class FollowingViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
    UITableViewDelegate, UITableViewDataSource
{
    static let suggestedFollowCount = 5

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
    var selectedSuggestedFollows = Set<Claim>()

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
        view.isHidden = !Lbryio.isSignedIn()

        // check if current user is signed in
        if !Lbryio.isSignedIn() {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
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

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(
            bottom: Helper.miniPlayerBottomWithTabBar(appDelegate: AppDelegate.shared))
    }

    func checkSelectedChannel() {
        if selectedChannelClaim != nil {
            for i in following.indices {
                if following[i].claimId == selectedChannelClaim?.claimId {
                    following[i].selected = true
                    return
                }
            }

            selectedChannelClaim = nil
        }
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

        Task {
            await update(await Wallet.shared.following)

            for await newFollowing in await Wallet.shared.sFollowing {
                await update(newFollowing)
            }
        }
    }

    func update(_ newFollowing: Wallet.Following?) async {
        following.removeAll(keepingCapacity: true)

        guard let newFollowing else {
            loadingContainer.isHidden = false
            suggestedView.isHidden = true
            mainView.isHidden = true
            return
        }

        do {
            guard newFollowing.count > 0 else {
                loadingContainer.isHidden = true
                showingSuggested = true

                loadSuggestedFollows()

                return
            }

            loadingContainer.isHidden = false

            let resolve = try await BackendMethods.resolve.call(params: .init(
                urls: newFollowing.keys.map(\.description)
            ))

            following.append(
                contentsOf: resolve.claims.values
                    .sorted {
                        $0.name ?? "" < $1.name ?? ""
                    }
            )

            checkSelectedChannel()
            channelListView.reloadData()
            contentListView.reloadData()

            resetSubscriptionContent()
            loadSubscriptionContent()

            // If updating following from other vc, allow dismissing suggested
            if !(UIApplication.currentViewController() == self && showingSuggested) {
                suggestedView.isHidden = true
                mainView.isHidden = false
            }
        } catch {
            loadingContainer.isHidden = true
            Helper.showError(error: error)
        }
    }

    @objc func refresh(_ sender: AnyObject) {
        if loadingContent {
            return
        }

        resetSubscriptionContent()
        loadSubscriptionContent()
    }

    func loadSuggestedFollows() {
        DispatchQueue.main.async {
            self.suggestedView.isHidden = false
            self.mainView.isHidden = true

            self.loadingContainer.isHidden = false
        }

        Lbry.apiCall(
            method: BackendMethods.claimSearch,
            params: .init(
                claimType: [.channel],
                page: currentSuggestedPage,
                pageSize: suggestedPageSize,
                notTags: Constants.NotTags,
                notChannelIds: following.compactMap(\.claimId),
                claimIds: ContentSources.DynamicContentCategories.first {
                    $0.key == HomeViewController.categoryKeyDiscover
                }?.channelIds,
                orderBy: ["creation_timestamp"]
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

    func loadSubscriptionContent() {
        if loadingContent {
            return
        }

        let channelIds = if let selectedClaimId = selectedChannelClaim?.claimId {
            [selectedClaimId]
        } else {
            following.compactMap(\.claimId)
        }

        if channelIds.count > 0 {
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = false
            }

            loadingContent = true

            let releaseTimeValue = currentSortByIndex == 2 ? Helper
                .buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : nil
            Lbry.apiCall(
                method: BackendMethods.claimSearch,
                params: .init(
                    claimType: [.stream, .repost],
                    page: currentPage,
                    pageSize: pageSize,
                    releaseTime: [releaseTimeValue].compactMap { $0 } + [Helper.releaseTimeBeforeFuture],
                    notTags: Constants.NotTags,
                    channelIds: channelIds,
                    orderBy: Helper.sortByItemValues[currentSortByIndex]
                )
            )
            .subscribeResult(didLoadSubscriptionContent)
        } else {
            didLoadSubscriptionContent(.success(Page(items: [], isLastPage: false)))
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
        contentListView.reloadData()
        refreshControl.endRefreshing()
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }

    @IBAction func doneTapped(_ sender: UIButton) {
        Task {
            guard let following = await Wallet.shared.following,
                  following.count + selectedSuggestedFollows.count > 0
            else {
                Helper.showMessage(message: String.localized("Please select one or more creators to follow"))
                return
            }

            do {
                try await subscribeAll(selected: selectedSuggestedFollows)

                selectedSuggestedFollows.removeAll()

                suggestedView.isHidden = true
                mainView.isHidden = false
                showingSuggested = false

                resetSubscriptionContent()
                loadSubscriptionContent()
            } catch {
                Helper.showError(error: error)
            }
        }
    }

    @IBAction func discoverTapped(_ sender: Any) {
        suggestedView.isHidden = false
        mainView.isHidden = true
        showingSuggested = true

        suggestedFollows.removeAll(keepingCapacity: true)
        suggestedFollowsView.reloadData()

        loadSuggestedFollows()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return claims.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell

        if claims.count > indexPath.row {
            let claim = claims[indexPath.row]
            cell.setClaim(claim: claim)
        } else {
            cell.setClaim(claim: Claim())
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let cell = tableView.cellForRow(at: indexPath) as? ClaimTableViewCell else {
            return
        }

        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = cell.currentClaim

        AppDelegate.shared.mainNavigationController?.view.layer.add(
            Helper.buildFileViewTransition(),
            forKey: kCATransition
        )
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
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
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "suggested_channel_cell",
                for: indexPath
            ) as! SuggestedChannelCollectionViewCell

            if suggestedFollows.count > indexPath.row {
                let claim = suggestedFollows[indexPath.row]
                cell.setClaim(claim: claim)

                cell.setSelected(selected: selectedSuggestedFollows.contains(claim))
                if selectedSuggestedFollows.contains(claim) {
                    suggestedFollowsView.selectItem(
                        at: indexPath,
                        animated: false,
                        scrollPosition: .centeredVertically
                    )
                }
            }

            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "followed_channel_cell",
                for: indexPath
            ) as! ChannelCollectionViewCell

            if following.count > indexPath.row {
                let claim = following[indexPath.row]
                cell.setClaim(claim: claim)
            }

            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == suggestedFollowsView {
            if suggestedFollows.count > indexPath.row {
                let claim = suggestedFollows[indexPath.row]
                selectedSuggestedFollows.insert(claim)

                let cell = collectionView.cellForItem(at: indexPath) as? SuggestedChannelCollectionViewCell
                cell?.setSelected(selected: true)
            }
        } else {
            if !loadingContent, following.count > indexPath.row {
                let prevSelectedClaimId = selectedChannelClaim?.claimId

                let claim = following[indexPath.row]
                let selected = claim.selected

                for i in following.indices {
                    following[i].selected = false
                }

                if selected {
                    claim.selected = false
                    selectedChannelClaim = nil
                } else {
                    claim.selected = true
                    selectedChannelClaim = claim
                }

                if prevSelectedClaimId != selectedChannelClaim?.claimId {
                    resetSubscriptionContent()
                    loadSubscriptionContent()
                }

                collectionView.reloadData()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if collectionView == suggestedFollowsView {
            if suggestedFollows.count > indexPath.row {
                let claim = suggestedFollows[indexPath.row]
                selectedSuggestedFollows.remove(claim)

                let cell = collectionView.cellForItem(at: indexPath) as? SuggestedChannelCollectionViewCell
                cell?.setSelected(selected: false)
            }
        }
        // Treat channelListView as a row of buttons, didSelect is a click event, handle toggle there
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

    func subscribeAll(selected: Set<Claim>) async throws {
        loadingContainer.isHidden = false
        defer {
            loadingContainer.isHidden = true
        }

        try await withThrowingTaskGroup { taskGroup in
            for claim in selected {
                guard let claimId = claim.claimId,
                      let channelName = claim.name
                else {
                    throw GenericError("couldn't get claim info")
                }

                taskGroup.addTask {
                    _ = try await AccountMethods.subscriptionNew.call(params: .init(
                        claimId: claimId,
                        channelName: channelName,
                        notificationsDisabled: true // New subscriptions have notifications disabled
                    ))
                }
            }

            // Make task group throwing
            try await taskGroup.waitForAll()
        }

        await Wallet.shared.addOrSetFollowingAll(values: Dictionary(
            uniqueKeysWithValues: selected.map { ($0, true) }
        ))

        await Wallet.shared.queuePushSync()
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
        sortByLabel.text = "\(itemName.split(separator: " ")[0]) ▾"
        contentFromLabel.isHidden = currentSortByIndex != 2
    }

    func checkUpdatedContentFrom() {
        let itemName = Helper.contentFromItemNames[currentContentFromIndex]
        contentFromLabel.text = "\(itemName) ▾"
    }

    @IBAction func sortByLabelTapped(_ sender: Any) {
        Helper.showPickerActionSheet(
            title: String.localized("Sort content by"),
            origin: sortByLabel,
            rows: Helper.sortByItemNames,
            initialSelection: max(0, min(currentSortByIndex, Helper.sortByItemNames.count - 1))
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
        Helper.showPickerActionSheet(
            title: String.localized("Content from"),
            origin: contentFromLabel,
            rows: Helper.contentFromItemNames,
            initialSelection: max(0, min(currentContentFromIndex, Helper.contentFromItemNames.count - 1))
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

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }
}
