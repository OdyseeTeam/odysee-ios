//
//  HomeViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import FirebaseAnalytics
import OrderedCollections
import PINRemoteImage
import UIKit

class HomeViewController: UIViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UITableViewDataSourcePrefetching,
    UICollectionViewDataSourcePrefetching,
    BlockChannelStatusObserver
{
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var claimListView: UITableView!
    @IBOutlet var categoryButtonsContainer: UIStackView!
    @IBOutlet var noContentView: UIStackView!

    @IBOutlet var sortByLabel: UILabel!
    @IBOutlet var contentFromLabel: UILabel!

    static var categoryIndexWildWest = -1
    static let categoryKeyWildWest = "WILD_WEST"
    static let categoryKeyPrimaryContent = "PRIMARY_CONTENT"

    let refreshControl = UIRefreshControl()
    var categories: [String] = []
    var channelLimits: [Int] = []
    var channelIds: [[String]?] = []
    var wildWestExcludedChannelIds: [String]? = []
    var currentCategoryIndex: Int = 0
    var categoryButtons: [UIButton] = []

    let pageSize: Int = 20
    var claimsCurrentPage: Int = 1
    var claimsLastPageReached: Bool = false
    var livestreamsCurrentPage: Int = 1
    var livestreamsLastPageReached: Bool = false
    var loadingClaims: Bool = false
    var loadingLivestreams: Bool = false
    var claims = OrderedSet<Claim>()
    var livestreamInfos = [LivestreamInfo]()
    var livestreams = OrderedSet<LivestreamData>()

    var livestreamsView: UIStackView!
    var livestreamsLabel: UILabel!
    var livestreamsCollectionView: UICollectionView!

    var currentSortByIndex = 0 // default to Trending content
    var currentContentFromIndex = 1 // default to Past week

    var claimsPrefetchController: ImagePrefetchingController!
    var livestreamsPrefetchController: ImagePrefetchingController!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [AnalyticsParameterScreenName: "Home", AnalyticsParameterScreenClass: "HomeViewController"]
        )

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(
            bottom: Helper.miniPlayerBottomWithTabBar(appDelegate: AppDelegate.shared))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buildDynamicCategories()
        claimsPrefetchController = ImagePrefetchingController { [unowned self] indexPath in
            let claim = claims[indexPath.row]
            return ClaimTableViewCell.imagePrefetchURLs(claim: claim)
        }
        livestreamsPrefetchController = ImagePrefetchingController { [unowned self] indexPath in
            let claim = livestreams[indexPath.row].claim
            return LivestreamCollectionViewCell.imagePrefetchURLs(claim: claim)
        }
        // Do any additional setup after loading the view.
        refreshControl.attributedTitle = NSAttributedString(string: String.localized("Pull down to refresh"))
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        refreshControl.tintColor = Helper.primaryColor
        claimListView.addSubview(refreshControl)
        claimListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
        createLivestreamsView()

        loadingContainer.layer.cornerRadius = 20

        for category in categories {
            addCategoryButton(label: category)
        }
        selectCategoryButton(button: categoryButtons[0])

        if let mainVc = AppDelegate.shared.mainViewController as? MainViewController {
            mainVc.addBlockChannelObserver(name: "home", observer: self)
        }

        if claims.count == 0 {
            loadClaims()
        }
        if livestreams.count == 0 {
            loadLivestreams()
        }
    }

    func buildDynamicCategories() {
        for (idx, category) in ContentSources.DynamicContentCategories.enumerated() {
            categories.append(String.localized(category.label))
            channelLimits.append(category.channelLimit)
            channelIds.append(category.channelIds)
            if category.key == Self.categoryKeyWildWest {
                wildWestExcludedChannelIds = category.excludedChannelIds
                Self.categoryIndexWildWest = idx
            }
        }
    }

    func didLoadClaims(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        result.showErrorIfPresent()
        if case var .success(payload) = result {
            payload.items.removeAll { Helper.isChannelBlocked(claimId: $0.signingChannel?.claimId) }

            let oldCount = claims.count
            claims.append(contentsOf: payload.items)
            if claims.count != oldCount {
                claimListView.reloadData()
            }
            claimsLastPageReached = payload.isLastPage
        }
        if !loadingLivestreams {
            loadingContainer.isHidden = true
        }
        loadingClaims = false
        checkNoContent()
        refreshControl.endRefreshing()
    }

    func loadClaims() {
        assert(Thread.isMainThread)
        if loadingClaims {
            return
        }

        noContentView.isHidden = true
        loadingContainer.isHidden = false
        loadingClaims = true

        // Capture category index for use in sorting, before leaving main thread.
        let category = currentCategoryIndex
        let isWildWest = category == Self.categoryIndexWildWest
        let releaseTimeValue = currentSortByIndex == 2 ? Helper
            .buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : Helper
            .releaseTime6Months()

        Lbry.apiCall(
            method: Lbry.Methods.claimSearch,
            params: .init(
                claimType: [.stream, .repost],
                streamTypes: [.audio, .video],
                page: claimsCurrentPage,
                pageSize: pageSize,
                releaseTime: [
                    isWildWest ?
                        Helper.buildReleaseTime(contentFrom: Helper.contentFromItemNames[1]) :
                        releaseTimeValue
                ].compactMap { $0 } + [Helper.releaseTimeBeforeFuture],
                limitClaimsPerChannel: channelLimits[currentCategoryIndex],
                notTags: Constants.NotTags + (isWildWest ? [] : [Constants.MembersOnly]),
                channelIds: isWildWest ? nil : channelIds[currentCategoryIndex],
                notChannelIds: isWildWest ? wildWestExcludedChannelIds : nil,
                orderBy: isWildWest ?
                    ["trending_group", "trending_mixed"]
                    : Helper.sortByItemValues[currentSortByIndex]
            ),
            transform: { page in
                if self.currentSortByIndex == 1 /* release_time */ {
                    page.items.sort {
                        $0.value?.releaseTime.flatMap(Int64.init) ?? 0 > $1.value?.releaseTime.flatMap(Int64.init) ?? 0
                    }
                }
            }
        )
        .subscribeResult(didLoadClaims)
    }

    func loadLivestreams() {
        assert(Thread.isMainThread)
        if loadingLivestreams {
            return
        }

        loadingContainer.isHidden = false
        loadingLivestreams = true

        if livestreamInfos.count > 0 {
            claimSearchLivestreams()
            return
        }

        OdyseeLivestream.all { result in
            if case let .success(infos) = result {
                self.livestreamInfos = infos.sorted {
                    $1.viewerCount < $0.viewerCount
                }

                self.claimSearchLivestreams()
            } else if case let .failure(error) = result {
                DispatchQueue.main.async {
                    AppDelegate.shared.mainController.showError(message: error.localizedDescription)
                }
            }
        }
    }

    func claimSearchLivestreams() {
        let isWildWest = currentCategoryIndex == Self.categoryIndexWildWest
        if !isWildWest {
            livestreamInfos = livestreamInfos.filter {
                channelIds[currentCategoryIndex]?.contains($0.channelClaimId) ?? false
            }

            guard livestreamInfos.count > 0 else {
                DispatchQueue.main.async { [self] in
                    claimListView.tableHeaderView = nil
                    if !loadingClaims {
                        loadingContainer.isHidden = true
                    }
                    loadingLivestreams = false
                }
                return
            }
        } else {
            guard livestreamInfos.count > 0 else {
                // Livestreams are "expected" in Wild West so show no livestreams message
                DispatchQueue.main.async { [self] in
                    claimListView.tableHeaderView = livestreamsView
                    livestreamsCollectionView.isHidden = true
                    livestreamsLabel.text = String
                        .localized("No livestreams to display at this time. Please try again later.")
                    if !loadingClaims {
                        loadingContainer.isHidden = true
                    }
                    loadingLivestreams = false
                }
                return
            }
        }

        DispatchQueue.main.async { [self] in
            claimListView.tableHeaderView = livestreamsView
            livestreamsCollectionView.isHidden = false
            livestreamsLabel.text = String.localized("Livestreams")
        }

        let claimIds = livestreamInfos.map(\.activeClaimId)
        let pageClaimIds = Array(claimIds[
            (livestreamsCurrentPage - 1) * pageSize
                ..<
                min(livestreamsCurrentPage * pageSize, claimIds.count)
        ])

        Lbry.apiCall(
            method: Lbry.Methods.claimSearch,
            params: .init(
                claimType: [.stream],
                releaseTime: [Helper.releaseTimeBeforeFuture],
                hasNoSource: true,
                notTags: Constants.NotTags + (isWildWest ? [] : [Constants.MembersOnly]),
                notChannelIds: isWildWest ? wildWestExcludedChannelIds : nil,
                claimIds: pageClaimIds
            )
        ).subscribeResult { [self] result in
            if case let .success(payload) = result {
                let oldCount = livestreams.count
                for claim in payload.items {
                    let livestreamInfo = livestreamInfos.first { $0.activeClaimId == claim.claimId }
                    let livestreamData = LivestreamData(
                        startTime: livestreamInfo?.startTime ?? Date(),
                        viewerCount: livestreamInfo?.viewerCount ?? 0,
                        claim: claim
                    )
                    livestreams.append(livestreamData)
                }
                livestreams.sort {
                    $1.viewerCount < $0.viewerCount
                }
                if livestreams.count != oldCount {
                    livestreamsCollectionView.reloadData()
                }

                livestreamsLastPageReached = livestreamsCurrentPage * pageSize > livestreamInfos.count

                if !loadingClaims {
                    loadingContainer.isHidden = true
                }
                loadingLivestreams = false
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return claims.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell

        let claim: Claim = claims[indexPath.row]
        cell.setClaim(claim: claim, showRepostOverlay: false)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = claims[indexPath.row]
        let actualClaim = if claim.valueType == ClaimType.repost, let repostedClaim = claim.repostedClaim {
            repostedClaim
        } else {
            claim
        }

        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = actualClaim

        AppDelegate.shared.mainNavigationController?.view.layer.add(
            Helper.buildFileViewTransition(),
            forKey: kCATransition
        )
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return livestreams.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "livestream_cell",
            for: indexPath
        ) as! LivestreamCollectionViewCell

        let livestream = livestreams[indexPath.row]
        cell.setLivestreamInfo(
            claim: livestream.claim,
            startTime: livestream.startTime,
            viewerCount: livestream.viewerCount
        )

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        collectionView.cellForItem(at: indexPath)?.contentView.backgroundColor = .systemGray4
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        collectionView.cellForItem(at: indexPath)?.contentView.backgroundColor = nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let claim = livestreams[indexPath.row].claim
        let vc = storyboard?.instantiateViewController(withIdentifier: "file_view_vc") as! FileViewController
        vc.claim = claim

        AppDelegate.shared.mainNavigationController?.view.layer.add(
            Helper.buildFileViewTransition(),
            forKey: kCATransition
        )
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if claimListView.contentOffset.y >= (claimListView.contentSize.height - claimListView.bounds.size.height) {
            if !loadingClaims, !claimsLastPageReached {
                claimsCurrentPage += 1
                loadClaims()
            }
            return
        }

        if scrollView == livestreamsCollectionView, livestreamsCollectionView.contentOffset.x >=
            (livestreamsCollectionView.contentSize.width - livestreamsCollectionView.bounds.size.width)
        {
            if !loadingLivestreams, !livestreamsLastPageReached {
                livestreamsCurrentPage += 1
                loadLivestreams()
            }
            return
        }

        guard !refreshControl.isRefreshing, !loadingClaims, !loadingLivestreams else {
            return
        }

        if claimListView.contentOffset.y < -300 {
            resetContent()
            loadClaims()
            loadLivestreams()
            refreshControl.beginRefreshing()
        }
    }

    func addCategoryButton(label: String) {
        let button = UIButton(type: .system)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 20, bottom: 4, right: 20)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = Helper.primaryColor.cgColor
        button.setTitle(label, for: .normal)
        button.setTitleColor(UIColor.label, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.addTarget(self, action: #selector(categoryButtonTapped), for: .touchUpInside)

        categoryButtons.append(button)
        categoryButtonsContainer.addArrangedSubview(button)
    }

    @objc func categoryButtonTapped(sender: UIButton) {
        for button in categoryButtons {
            if button.backgroundColor == Helper.primaryColor {
                button.backgroundColor = UIButton(type: .roundedRect).backgroundColor
                button.setTitleColor(UIColor.label, for: .normal)
                break
            }
        }
        selectCategoryButton(button: sender)

        if let category = sender.title(for: .normal) {
            currentCategoryIndex = categories.firstIndex(of: category) ?? 0
            resetContent()
            loadClaims()
            loadLivestreams()
        }
    }

    func resetContent() {
        assert(Thread.isMainThread)
        claimsCurrentPage = 1
        claimsLastPageReached = false
        livestreamsCurrentPage = 1
        livestreamsLastPageReached = false
        claims.removeAll()
        livestreamInfos.removeAll()
        livestreams.removeAll()
        claimListView.reloadData()
        livestreamsCollectionView.reloadData()
    }

    func selectCategoryButton(button: UIButton) {
        button.backgroundColor = Helper.primaryColor
        button.setTitleColor(UIColor.white, for: .normal)
    }

    func checkNoContent() {
        assert(Thread.isMainThread)
        noContentView.isHidden = !claims.isEmpty
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
            initialSelection: currentSortByIndex
        ) { _, selectedIndex, _ in
            let prevIndex = self.currentSortByIndex
            self.currentSortByIndex = selectedIndex
            if prevIndex != self.currentSortByIndex {
                self.checkUpdatedSortBy()
                self.resetContent()
                self.loadClaims()
            }
        }
    }

    @IBAction func contentFromLabelTapped(_ sender: Any) {
        Helper.showPickerActionSheet(
            title: String.localized("Content from"),
            origin: contentFromLabel,
            rows: Helper.contentFromItemNames,
            initialSelection: currentContentFromIndex
        ) { _, selectedIndex, _ in
            let prevIndex = self.currentContentFromIndex
            self.currentContentFromIndex = selectedIndex
            if prevIndex != self.currentContentFromIndex {
                self.checkUpdatedContentFrom()
                self.resetContent()
                self.loadClaims()
            }
        }
    }

    @objc func refresh(_ sender: AnyObject) {
        if loadingClaims {
            return
        }

        resetContent()
        loadClaims()
        loadLivestreams()
    }

    func createLivestreamsView() {
        livestreamsLabel = UILabel()
        livestreamsLabel.translatesAutoresizingMaskIntoConstraints = false
        livestreamsLabel.text = String.localized("Livestreams")
        livestreamsLabel.numberOfLines = 0
        let titleHeight = livestreamsLabel.intrinsicContentSize.height

        let collectionViewFrame = CGRect(x: 0, y: 0, width: 0, height: 199)
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.itemSize = CGSize(width: 196, height: 199)
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        livestreamsCollectionView = UICollectionView(
            frame: collectionViewFrame,
            collectionViewLayout: collectionViewLayout
        )
        livestreamsCollectionView.autoresizingMask = .flexibleWidth

        livestreamsCollectionView.dataSource = self
        livestreamsCollectionView.delegate = self
        livestreamsCollectionView.prefetchDataSource = self

        livestreamsCollectionView.register(
            LivestreamCollectionViewCell.nib,
            forCellWithReuseIdentifier: "livestream_cell"
        )

        let livestreamsViewFrame = CGRect(x: 0, y: 0, width: 0, height: 199 + titleHeight)
        livestreamsView = UIStackView(frame: livestreamsViewFrame)
        livestreamsView.axis = .vertical
        livestreamsView.alignment = .trailing // HACK to prevent conflicting leading constraint

        livestreamsView.addArrangedSubview(livestreamsLabel)
        livestreamsView.addArrangedSubview(livestreamsCollectionView)
        NSLayoutConstraint.activate([
            livestreamsLabel.leadingAnchor.constraint(equalTo: livestreamsView.leadingAnchor, constant: 18),
            livestreamsCollectionView.leadingAnchor.constraint(equalTo: livestreamsView.leadingAnchor),
        ])
    }

    func blockChannelStatusChanged(claimId: String, isBlocked: Bool) {
        claims.removeAll {
            Helper.isChannelBlocked(claimId: $0.signingChannel?.claimId)
        }
        claimListView.reloadData()
    }

    // MARK: UITableViewDataSourcePrefetching

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        claimsPrefetchController.prefetch(at: indexPaths)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        claimsPrefetchController.cancelPrefetching(at: indexPaths)
    }

    // MARK: UICollectionViewDataSourcePrefetching

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        livestreamsPrefetchController.prefetch(at: indexPaths)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        livestreamsPrefetchController.cancelPrefetching(at: indexPaths)
    }
}
