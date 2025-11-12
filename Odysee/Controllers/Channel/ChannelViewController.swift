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

class ChannelViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UITableViewDelegate,
    UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, UIPickerViewDelegate,
    UIPickerViewDataSource, UITextViewDelegate, BlockChannelStatusObserver
{
    var channelClaim: Claim?
    var claimUrl: LbryUri?
    var page: Int?
    var subscribeUnsubscribeInProgress = false
    var livestreamTimer = Timer()
    let livestreamTimerInterval: Double = 60 // 1 minute
    let coverImageSpec = ImageSpec(size: CGSize(width: 0, height: 0), quality: 95)

    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var coverImageView: UIImageView!

    @IBOutlet var pageControl: UIPageControl!
    @IBOutlet var pageScrollView: UIScrollView!
    @IBOutlet var channelCommunityView: UIView!

    @IBOutlet var contentListView: UITableView!
    @IBOutlet var contentLoadingContainer: UIView!
    @IBOutlet var sortByLabel: UILabel!
    @IBOutlet var contentFromLabel: UILabel!

    @IBOutlet var titleLabel: UIPaddedLabel!
    @IBOutlet var followerCountLabel: UIPaddedLabel!

    @IBOutlet var noChannelContentView: UIView!
    @IBOutlet var noAboutContentView: UIView!

    @IBOutlet var websiteStackView: UIView!
    @IBOutlet var emailStackView: UIView!
    @IBOutlet var websiteLabel: UILabel!
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var descriptionTextView: UITextView!

    @IBOutlet var shareView: UIView!
    @IBOutlet var followLabel: UILabel!
    @IBOutlet var followUnfollowIconView: UIImageView!
    @IBOutlet var bellView: UIView!
    @IBOutlet var bellIconView: UIImageView!

    @IBOutlet var resolvingView: UIView!
    @IBOutlet var resolvingImageView: UIImageView!
    @IBOutlet var resolvingLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet var resolvingLabel: UILabel!
    @IBOutlet var resolvingCloseButton: UIButton!

    @IBOutlet var blockUnblockLabel: UILabel!

    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!

    var commentsViewPresented = false
    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loadingContent: Bool = false
    var claims = OrderedSet<Claim>()
    var activeLivestreamClaim: Claim?
    var futureStreams = OrderedSet<Claim>()
    var channels: [Claim] = []

    var activeLivestreamClaimCell: ClaimTableViewCell!
    var activeLivestreamView: UIStackView!
    var futureStreamsLabel: UILabel!
    var futureStreamsView: UIStackView!
    var futureStreamsCollectionView: UICollectionView!

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

        if !Lbryio.isSignedIn(), pageControl.currentPage == 2 {
            pageControl.currentPage = 1
            updateScrollViewForPage(page: pageControl.currentPage)
        }

        if Lbryio.isSignedIn() {
            loadChannels()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Channel",
                AnalyticsParameterScreenClass: "ChannelViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        contentListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
        createLivestreamsView()
        contentLoadingContainer.layer.cornerRadius = 20
        titleLabel.layer.cornerRadius = 8
        titleLabel.textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

        followerCountLabel.layer.cornerRadius = 8
        followerCountLabel.textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

        // Do any additional setup after loading the view
        thumbnailImageView.rounded()

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let mainVc = appDelegate.mainViewController as? MainViewController {
            mainVc.addBlockChannelObserver(name: "channel", observer: self)
        }

        // TODO: If channelClaim is not set, resolve the claim url before displaying
        if channelClaim == nil, claimUrl != nil {
            resolveAndDisplayClaim()
        } else if channelClaim != nil {
            if Lbryio.isClaimAppleFiltered(channelClaim!) {
                displayClaimBlockedWithMessage(
                    message: Lbryio
                        .getFilteredMessageForClaim(channelClaim!.claimId!, channelClaim!.claimId!)
                )
                return
            }

            displayClaim()
            loadAndDisplayFollowerCount()
            loadContent()
            displayCommentsView()
        } else {
            displayNothingAtLocation()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let mainVc = appDelegate.mainViewController as? MainViewController {
            mainVc.removeBlockChannelObserver(name: "channel")
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
        vc.view.frame = CGRect(
            x: 0,
            y: 0,
            width: channelCommunityView.bounds.width,
            height: channelCommunityView.bounds.height
        )
        addChild(vc)
        vc.didMove(toParent: self)

        commentsViewPresented = true
    }

    func showClaimAndCheckFollowing() {
        displayClaim()
        loadAndDisplayFollowerCount()
        loadContent()
        displayCommentsView()

        if let page = page {
            pageControl.currentPage = page
            updateScrollViewForPage(page: pageControl.currentPage)
        }

        checkFollowing()
        checkNotificationsDisabled()
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

        Lbry.apiCall(
            method: Lbry.Methods.resolve,
            params: .init(urls: [url])
        )
        .subscribeResult(didResolveClaim)
    }

    func didResolveClaim(_ result: Result<ResolveResult, Error>) {
        guard case let .success(resolve) = result, let claim = resolve.claims.values.first else {
            result.showErrorIfPresent()
            displayNothingAtLocation()
            return
        }

        channelClaim = claim
        if Lbryio.isClaimAppleFiltered(channelClaim!) {
            displayClaimBlockedWithMessage(
                message: Lbryio
                    .getFilteredMessageForClaim(channelClaim!.claimId!, channelClaim!.claimId!)
            )
            return
        }

        showClaimAndCheckFollowing()
    }

    func displayResolving() {
        DispatchQueue.main.async {
            self.resolvingView.isHidden = false
            self.resolvingLoadingIndicator.isHidden = false
            self.resolvingImageView.image = UIImage(named: "spaceman_happy")
            self.resolvingLabel.text = String.localized("Resolving content...")
            self.resolvingCloseButton.isHidden = true
        }
    }

    func displayNothingAtLocation() {
        DispatchQueue.main.async {
            self.resolvingView.isHidden = false
            self.resolvingLoadingIndicator.isHidden = true
            self.resolvingImageView.image = UIImage(named: "spaceman_sad")
            self.resolvingLabel.text = String.localized("There's nothing at this location.")
            self.resolvingCloseButton.isHidden = false
        }
    }

    func displayClaimBlockedWithMessage(message: String) {
        DispatchQueue.main.async {
            self.resolvingView.isHidden = false
            self.resolvingLoadingIndicator.isHidden = true
            self.resolvingImageView.image = UIImage(named: "spaceman_sad")
            self.resolvingLabel.text = String
                .localized(
                    message
                )
            self.resolvingCloseButton.isHidden = false
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func checkCommentsDisabled(_ commentsDisabled: Bool) {
        DispatchQueue.main.async {
            self.commentsDisabled = commentsDisabled
            self.displayCommentsView()
        }
    }

    func displayClaim() {
        resolvingView.isHidden = true

        if channelClaim?.value != nil {
            blockUnblockLabel.text = String.localized(
                Helper.isChannelBlocked(claimId: channelClaim?.claimId) ?
                    "Unblock channel" : "Block channel"
            )

            Lbryio.areCommentsEnabled(
                channelId: channelClaim!.claimId!,
                channelName: channelClaim!.name!,
                completion: { enabled in
                    self.commentsDisabledChecked = true
                    self.checkCommentsDisabled(!enabled)
                }
            )

            if channelClaim?.value?.thumbnail != nil {
                let optimisedThumbUrl = URL(string: (channelClaim?.value?.thumbnail?.url)!)!
                    .makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
                thumbnailImageView.load(url: optimisedThumbUrl)
            } else {
                thumbnailImageView.image = UIImage(named: "spaceman")
                thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
            }

            if channelClaim?.value?.cover != nil {
                let optimisedCoverUrl = URL(string: (channelClaim?.value?.cover?.url)!)!
                    .makeImageURL(spec: coverImageSpec)
                coverImageView.load(url: optimisedCoverUrl)
            } else {
                coverImageView.image = UIImage(named: "spaceman_cover")
            }

            titleLabel.text = channelClaim?.value?.title

            // about page
            let website = channelClaim?.value?.websiteUrl
            let email = channelClaim?.value?.email
            let description = channelClaim?.value?.description

            if website.isBlank, email.isBlank, description.isBlank {
                websiteStackView.isHidden = true
                emailStackView.isHidden = true
                descriptionTextView.isHidden = true
                noAboutContentView.isHidden = false
            } else {
                websiteStackView.isHidden = website.isBlank
                websiteLabel.text = website ?? ""
                emailStackView.isHidden = email.isBlank
                emailLabel.text = email ?? ""
                descriptionTextView.isHidden = description.isBlank
                descriptionTextView.text = description
                noAboutContentView.isHidden = true
            }
        }

        // schedule livestream timer
        livestreamTimer = Timer.scheduledTimer(
            timeInterval: livestreamTimerInterval,
            target: self,
            selector: #selector(checkLivestream),
            userInfo: nil,
            repeats: true
        )
    }

    func loadAndDisplayFollowerCount() {
        var options = [String: String]()
        options["claim_id"] = channelClaim?.claimId
        try! Lbryio.get(resource: "subscription", action: "sub_count", options: options, completion: { data, error in
            guard let data = data, error == nil else {
                return
            }
            DispatchQueue.main.async {
                let formatter = Helper.interactionCountFormatter
                let followerCount = (data as! NSArray)[0] as! Int
                self.followerCountLabel.isHidden = false
                self.followerCountLabel.text = String(
                    format: followerCount == 1 ? String.localized("%@ follower") : String.localized("%@ followers"),
                    formatter.string(for: followerCount)!
                )
            }
        })
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            let pageIndex = Int(round(scrollView.contentOffset.x / view.frame.width))
            pageControl.currentPage = pageIndex
        } else if scrollView == contentListView {
            if contentListView.contentOffset
                .y >= (contentListView.contentSize.height - contentListView.bounds.size.height)
            {
                if !loadingContent, !lastPageReached {
                    currentPage += 1
                    loadContent()
                }
            }
        }
    }

    func resetContent() {
        currentPage = 1
        lastPageReached = false
        activeLivestreamClaim = nil
        futureStreams.removeAll()
        claims.removeAll()
        contentListView.reloadData()
    }

    func loadContent() {
        if loadingContent {
            return
        }

        DispatchQueue.main.async {
            self.contentLoadingContainer.isHidden = false
        }

        loadingContent = true
        noChannelContentView.isHidden = true
        let releaseTimeValue = currentSortByIndex == 2 ? Helper
            .buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : nil
        Lbry.apiCall(
            method: Lbry.Methods.claimSearch,
            params: .init(
                claimType: [.stream, .repost],
                page: currentPage,
                pageSize: pageSize,
                releaseTime: [releaseTimeValue].compactMap { $0 } + [Helper.releaseTimeBeforeFuture],
                hasNoSource: false,
                notTags: Constants.NotTags,
                channelIds: [channelClaim?.claimId ?? ""],
                orderBy: Helper.sortByItemValues[currentSortByIndex]
            )
        )
        .subscribeResult(didLoadContent)
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
        if loadingContent {
            return
        }

        loadingContent = true

        OdyseeLivestream.channelIsLive(channelClaimId: channelClaim?.claimId ?? "") { result in
            self.loadingContent = false
            guard case let .success(channelLiveInfo) = result else {
                DispatchQueue.main.async {
                    result.showErrorIfPresent()
                }
                return
            }

            var urlsToResolve = (channelLiveInfo.futureClaimsUrls ?? [])
            if channelLiveInfo.live {
                urlsToResolve.append(channelLiveInfo.activeClaimUrl)
            }

            guard urlsToResolve.count > 0 else {
                DispatchQueue.main.async {
                    self.contentListView.tableHeaderView = nil
                }
                return
            }

            Lbry.apiCall(
                method: Lbry.Methods.resolve,
                params: .init(urls: urlsToResolve)
            )
            .subscribeResult { [self] result in
                guard case let .success(resolveResult) = result else {
                    result.showErrorIfPresent()
                    return
                }

                var claims = Array(resolveResult.claims.values)
                var activeClaim: Claim?
                if channelLiveInfo.live {
                    activeClaim = claims.first { $0.canonicalUrl == channelLiveInfo.activeClaimUrl }
                    claims = claims.filter { $0.canonicalUrl != channelLiveInfo.activeClaimUrl }
                }

                futureStreams.append(contentsOf: claims)

                contentListView.tableHeaderView = futureStreamsView
                if claims.count > 0 {
                    futureStreamsLabel.isHidden = false
                    futureStreamsCollectionView.isHidden = false
                }
                if let activeClaim = activeClaim {
                    activeLivestreamClaim = activeClaim
                    activeLivestreamView.isHidden = false
                    activeLivestreamClaimCell.setLivestreamClaim(
                        claim: activeClaim,
                        startTime: channelLiveInfo.startTime,
                        viewerCount: channelLiveInfo.viewerCount
                    )

                    let tapGestureRecognizer = UITapGestureRecognizer(
                        target: self,
                        action: #selector(activeLivestreamTapped(_:))
                    )
                    activeLivestreamClaimCell.contentView.addGestureRecognizer(tapGestureRecognizer)
                }

                NSLayoutConstraint.activate([
                    futureStreamsView.widthAnchor
                        .constraint(equalTo: contentListView.widthAnchor),
                    futureStreamsView.leadingAnchor
                        .constraint(equalTo: contentListView.leadingAnchor),
                    futureStreamsView.trailingAnchor
                        .constraint(equalTo: contentListView.trailingAnchor)
                ])
                futureStreamsView.layoutIfNeeded()

                checkNoContent()
            }
        }
    }

    func checkNoContent() {
        noChannelContentView.isHidden = claims.count > 0 || activeLivestreamClaim != nil || futureStreams.count > 0
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
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "claim_cell",
                for: indexPath
            ) as! ClaimTableViewCell

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

            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return futureStreams.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "livestream_cell",
            for: indexPath
        ) as! LivestreamCollectionViewCell

        let futureStream = futureStreams[indexPath.row]
        cell.setFutureStreamClaim(claim: futureStream)

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

        let claim = futureStreams[indexPath.row]
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(withIdentifier: "file_view_vc") as! FileViewController
        vc.claim = claim

        appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
        appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
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
        let (picker, alert) = Helper.buildPickerActionSheet(
            title: String.localized("Sort content by"),
            sourceView: sortByLabel,
            dataSource: self,
            delegate: self,
            parent: self,
            handler: { _ in
                let selectedIndex = self.sortByPicker.selectedRow(inComponent: 0)
                let prevIndex = self.currentSortByIndex
                self.currentSortByIndex = selectedIndex
                if prevIndex != self.currentSortByIndex {
                    self.checkUpdatedSortBy()
                    self.resetContent()
                    self.loadContent()
                }
            }
        )

        sortByPicker = picker
        present(alert, animated: true, completion: {
            self.sortByPicker.selectRow(self.currentSortByIndex, inComponent: 0, animated: true)
        })
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func contentFromLabelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(
            title: String.localized("Content from"),
            sourceView: contentFromLabel,
            dataSource: self,
            delegate: self,
            parent: self,
            handler: { _ in
                let selectedIndex = self.contentFromPicker.selectedRow(inComponent: 0)
                let prevIndex = self.currentContentFromIndex
                self.currentContentFromIndex = selectedIndex
                if prevIndex != self.currentContentFromIndex {
                    self.checkUpdatedContentFrom()
                    self.resetContent()
                    self.loadContent()
                }
            }
        )

        contentFromPicker = picker
        present(alert, animated: true, completion: {
            self.contentFromPicker.selectRow(self.currentContentFromIndex, inComponent: 0, animated: true)
        })
    }

    @IBAction func backTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func pageChanged(_ sender: UIPageControl) {
        let page = sender.currentPage
        view.endEditing(true)
        updateScrollViewForPage(page: page)
    }

    func updateScrollViewForPage(page: Int) {
        var frame: CGRect = pageScrollView.frame
        frame.origin.x = frame.size.width * CGFloat(page)
        frame.origin.y = 0
        pageScrollView.scrollRectToVisible(frame, animated: true)
    }

    @IBAction func websiteTapped(_ sender: Any) {
        if var websiteUrl = websiteLabel.text, !websiteUrl.isBlank {
            if !websiteUrl.starts(with: "http://"), !websiteUrl.starts(with: "https://") {
                websiteUrl = String(format: "http://%@", websiteUrl)
            }
            if let url = URL(string: websiteUrl) {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }

    @objc func activeLivestreamTapped(_ sender: Any) {
        if let claim = activeLivestreamClaim {
            let actualClaim = (claim.valueType == ClaimType.repost && claim.repostedClaim != nil) ?
                claim.repostedClaim! : claim

            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = actualClaim

            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }

    func checkFollowing() {
        DispatchQueue.main.async {
            if Lbryio.isFollowing(claim: self.channelClaim!) {
                // show unfollow and bell icons
                self.followLabel.isHidden = true
                self.bellView.isHidden = false
                self.followUnfollowIconView.image = UIImage(systemName: "heart.slash.fill")
                self.followUnfollowIconView.tintColor = UIColor.label
            } else {
                self.followLabel.isHidden = false
                self.bellView.isHidden = true
                self.followUnfollowIconView.image = UIImage(systemName: "heart")
                self.followUnfollowIconView.tintColor = UIColor.systemRed
            }
        }
    }

    func checkNotificationsDisabled(showMessage: Bool = false) {
        if !Lbryio.isFollowing(claim: channelClaim!) {
            return
        }

        DispatchQueue.main.async {
            if Lbryio.isNotificationsDisabledForSub(claim: self.channelClaim!) {
                self.bellIconView.image = UIImage(systemName: "bell.fill")
                if showMessage {
                    self.showMessage(message: String.localized("You will not receive notifications for this channel"))
                }
            } else {
                self.bellIconView.image = UIImage(systemName: "bell.slash.fill")
                if showMessage {
                    self.showMessage(message: String.localized("You will receive all notifications"))
                }
            }
        }
    }

    @IBAction func shareActionTapped(_ sender: Any) {
        let url = LbryUri.tryParse(url: channelClaim!.shortUrl!, requireProto: false)
        if let url = url {
            let items: [Any] = [URL(string: url.odyseeString) ?? url.odyseeString]
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = shareView
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

    @IBAction func blockUnblockActionTapped(_ sender: Any) {
        if let current = channelClaim {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let isBlocked = Helper.isChannelBlocked(claimId: current.claimId)
            if let mainVc = appDelegate.mainViewController as? MainViewController {
                if isBlocked {
                    mainVc.removeBlockedChannel(claimId: current.claimId!)
                } else {
                    let alert = UIAlertController(
                        title: String(format: String.localized("Block %@?"), current.name!),
                        message: String(
                            format: String
                                .localized(
                                    "Are you sure you want to block this channel? You will no longer see comments nor content from %@."
                                ),
                            current.name!
                        ),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
                        mainVc.addBlockedChannel(
                            claimId: current.claimId!,
                            channelName: current.name!,
                            notifyAfter: true
                        )
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("No"), style: .destructive))
                    present(alert, animated: true)
                }
            }
        }
    }

    @IBAction func reportActionTapped(_ sender: Any) {
        if let current = channelClaim {
            if let url =
                URL(string: String(format: "https://odysee.com/$/report_content?claimId=%@", current.claimId!))
            {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }

    func showUAView() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func followUnfollowActionTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }
        if Lbryio.isFollowing(claim: channelClaim!) {
            let alert = UIAlertController(
                title: String.localized("Stop following channel?"),
                message: String.localized("Are you sure you want to stop following this channel?"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
                self.subscribeOrUnsubscribe(
                    claim: self.channelClaim!,
                    notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: self.channelClaim!),
                    unsubscribing: true
                )

                // check if the following tab is open to prevent a crash
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                if let vc = appDelegate.mainTabViewController?.selectedViewController as? FollowingViewController {
                    vc.removeFollowing(claim: self.channelClaim!)
                }
            })
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { _ in }))
            present(alert, animated: true, completion: nil)
        } else {
            subscribeOrUnsubscribe(
                claim: channelClaim!,
                notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: channelClaim!),
                unsubscribing: false
            )
        }
    }

    @IBAction func bellActionTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }
        subscribeOrUnsubscribe(
            claim: channelClaim!,
            notificationsDisabled: !Lbryio.isNotificationsDisabledForSub(claim: channelClaim!),
            unsubscribing: false
        )
    }

    func subscribeOrUnsubscribe(claim: Claim?, notificationsDisabled: Bool, unsubscribing: Bool) {
        if subscribeUnsubscribeInProgress {
            return
        }

        subscribeUnsubscribeInProgress = true
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
                    self.subscribeUnsubscribeInProgress = false
                    guard let _ = data, error == nil else {
                        // print(error)
                        self.showError(error: error)
                        self.checkFollowing()
                        self.checkNotificationsDisabled()
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

                    self.checkFollowing()
                    self.checkNotificationsDisabled(showMessage: true)

                    Lbryio.subscriptionsDirty = true
                    Lbry.saveSharedUserState(completion: { success, err in
                        guard err == nil else {
                            // pass
                            return
                        }
                        if success {
                            // run wallet sync
                            Lbry.pushSyncWallet()
                        }
                    })
                }
            )
        } catch {
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

    func createLivestreamsView() {
        let activeLivestreamLabel = UILabel()
        activeLivestreamLabel.translatesAutoresizingMaskIntoConstraints = false
        activeLivestreamLabel.text = String.localized("Live stream in progress")
        activeLivestreamLabel.font = .systemFont(ofSize: 20)

        activeLivestreamClaimCell = (
            Bundle.main
                .loadNibNamed("ClaimTableViewCell", owner: self)?[0] as! ClaimTableViewCell
        )

        activeLivestreamView = UIStackView(arrangedSubviews: [
            activeLivestreamLabel,
            activeLivestreamClaimCell.contentView
        ])
        activeLivestreamView.isHidden = true
        activeLivestreamView.translatesAutoresizingMaskIntoConstraints = false
        activeLivestreamView.axis = .vertical
        activeLivestreamView.alignment = .leading
        activeLivestreamView.backgroundColor = Helper.primaryColor.withAlphaComponent(0.3)
        activeLivestreamView.layer.cornerRadius = 8

        futureStreamsLabel = UILabel()
        futureStreamsLabel.isHidden = true
        futureStreamsLabel.translatesAutoresizingMaskIntoConstraints = false
        futureStreamsLabel.text = String.localized("Upcoming Livestreams")

        let collectionViewFrame = CGRect(x: 0, y: 0, width: 0, height: 199)
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.itemSize = CGSize(width: 196, height: 199)
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        futureStreamsCollectionView = UICollectionView(
            frame: collectionViewFrame,
            collectionViewLayout: collectionViewLayout
        )
        futureStreamsCollectionView.isHidden = true
        futureStreamsCollectionView.translatesAutoresizingMaskIntoConstraints = false

        futureStreamsCollectionView.dataSource = self
        futureStreamsCollectionView.delegate = self

        futureStreamsCollectionView.register(
            LivestreamCollectionViewCell.nib,
            forCellWithReuseIdentifier: "livestream_cell"
        )

        futureStreamsView = UIStackView(arrangedSubviews: [
            activeLivestreamView,
            futureStreamsLabel,
            futureStreamsCollectionView
        ])
        futureStreamsView.translatesAutoresizingMaskIntoConstraints = false
        futureStreamsView.spacing = 10
        futureStreamsView.axis = .vertical
        futureStreamsView.alignment = .center // HACK to prevent conflicting constraints

        NSLayoutConstraint.activate([
            activeLivestreamLabel.leadingAnchor
                .constraint(equalTo: activeLivestreamView.leadingAnchor, constant: 16),
            activeLivestreamLabel.topAnchor
                .constraint(equalTo: activeLivestreamView.topAnchor, constant: 8),
            activeLivestreamClaimCell.contentView.leadingAnchor
                .constraint(equalTo: activeLivestreamView.leadingAnchor),
            activeLivestreamView.leadingAnchor
                .constraint(equalTo: futureStreamsView.leadingAnchor, constant: 10),
            activeLivestreamView.trailingAnchor
                .constraint(equalTo: futureStreamsView.trailingAnchor, constant: -10),
            futureStreamsLabel.leadingAnchor
                .constraint(equalTo: futureStreamsView.leadingAnchor, constant: 18),
            futureStreamsCollectionView.leadingAnchor
                .constraint(equalTo: futureStreamsView.leadingAnchor),
            futureStreamsCollectionView.trailingAnchor
                .constraint(equalTo: futureStreamsView.trailingAnchor),
            futureStreamsCollectionView.heightAnchor
                .constraint(equalToConstant: collectionViewFrame.height)
        ])
    }

    func blockChannelStatusChanged(claimId: String, isBlocked: Bool) {
        if let current = channelClaim {
            blockUnblockLabel.text = String.localized(
                Helper.isChannelBlocked(claimId: current.claimId) ?
                    "Unblock channel" : "Block channel"
            )
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
