//
//  FileViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/11/2020.
//

import AVFoundation
import AVKit
import CoreData
import FirebaseAnalytics
import ImageScrollView
import OrderedCollections
import PerfectMarkdown
import PINRemoteImage
import SafariServices
import Starscream
import UIKit
import WebKit

class FileViewController: UIViewController, UIGestureRecognizerDelegate, UINavigationControllerDelegate,
    UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate,
    WebSocketDelegate, WKNavigationDelegate
{
    @IBOutlet var titleArea: UIView!
    @IBOutlet var publisherArea: UIView!
    @IBOutlet var titleAreaIconView: UIImageView!
    @IBOutlet var descriptionArea: UIView!
    @IBOutlet var descriptionDivider: UIView!
    @IBOutlet var detailsScrollView: UIScrollView!
    @IBOutlet var livestreamChatView: UIView!
    @IBOutlet var livestreamOfflinePlaceholder: UIImageView!
    @IBOutlet var livestreamOfflineMessageView: UIView!
    @IBOutlet var livestreamOfflineLabel: UILabel!
    @IBOutlet var livestreamerArea: UIView!
    @IBOutlet var commentAsChannelLabel: UILabel!

    @IBOutlet var mediaView: UIView!
    @IBOutlet var reloadStreamView: UIView!

    @IBOutlet var mediaLoadingIndicator: UIActivityIndicatorView!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var viewCountLabel: UILabel!
    @IBOutlet var timeAgoLabel: UILabel!

    @IBOutlet var publisherActionsArea: UIView!
    @IBOutlet var publisherImageView: UIImageView!
    @IBOutlet var publisherTitleLabel: UILabel!
    @IBOutlet var publisherNameLabel: UILabel!

    @IBOutlet var livestreamerActionsArea: UIView!
    @IBOutlet var livestreamerImageView: UIImageView!
    @IBOutlet var livestreamerTitleLabel: UILabel!
    @IBOutlet var livestreamerNameLabel: UILabel!

    @IBOutlet var chatInputField: UITextField!
    @IBOutlet var chatListView: UITableView!

    @IBOutlet var descriptionTextView: UITextView!

    @IBOutlet var followLabel: UILabel!
    @IBOutlet var followUnfollowIconView: UIImageView!
    @IBOutlet var bellView: UIView!
    @IBOutlet var bellIconView: UIImageView!

    @IBOutlet var streamerAreaActionsView: UIView!
    @IBOutlet var streamerFollowLabel: UILabel!
    @IBOutlet var streamerFollowUnfollowIconView: UIImageView!
    @IBOutlet var streamerBellView: UIView!
    @IBOutlet var streamerBellIconView: UIImageView!

    @IBOutlet var relatedOrPlaylistTitle: UILabel!
    @IBOutlet var loadingRelatedView: UIActivityIndicatorView!
    @IBOutlet var relatedContentListView: UITableView!
    @IBOutlet var relatedContentListHeightConstraint: NSLayoutConstraint!

    @IBOutlet var resolvingView: UIView!
    @IBOutlet var resolvingImageView: UIImageView!
    @IBOutlet var resolvingLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet var resolvingLabel: UILabel!
    @IBOutlet var resolvingCloseButton: UIButton!

    @IBOutlet var noCommentsLabel: UILabel!
    @IBOutlet var relatedContentArea: UIView!
    @IBOutlet var featuredCommentView: UIView!
    @IBOutlet var featuredCommentThumbnail: UIImageView!
    @IBOutlet var featuredCommentLabel: UILabel!

    @IBOutlet var commentExpandView: UIImageView!
    @IBOutlet var commentsContainerView: UIView!
    @IBOutlet var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet var streamerAreaHeightConstraint: NSLayoutConstraint!

    @IBOutlet var fireReactionCountLabel: UILabel!
    @IBOutlet var slimeReactionCountLabel: UILabel!
    @IBOutlet var fireReactionImage: UIImageView!
    @IBOutlet var slimeReactionImage: UIImageView!
    @IBOutlet var shareActionView: UIStackView!

    @IBOutlet var dismissPanRecognizer: UIPanGestureRecognizer!

    @IBOutlet var closeOtherContentButton: UIButton!
    @IBOutlet var contentInfoView: UIView!
    @IBOutlet var contentInfoLoading: UIActivityIndicatorView!
    @IBOutlet var contentInfoDescription: UILabel!
    @IBOutlet var contentInfoImage: UIImageView!
    @IBOutlet var contentInfoViewButton: UIButton!
    @IBOutlet var mediaViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var webViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var imageViewer: ImageScrollView!
    @IBOutlet var webView: WKWebView!
    @IBOutlet var dismissFileView: UIView!
    @IBOutlet var playerRateView: UIVisualEffectView!
    @IBOutlet var playerRateButton: UIButton!
    @IBOutlet var jumpBackwardView: UIVisualEffectView!
    @IBOutlet var jumpForwardView: UIVisualEffectView!

    var mediaViewHeight: CGFloat = 0

    let avpc = TouchInterceptingAVPlayerViewController()
    var currentPlayer: AVPlayer? // keep a strong reference to AVPlayer initialised in the file view
    var avpcIsReadyObserver: NSKeyValueObservation?
    var playerStartedObserver: NSKeyValueObservation?
    weak var commentsVc: CommentsViewController!

    var commentsDisabledChecked = false
    var commentsDisabled = false
    var commentsViewPresented = false
    var selectedRateIndex: Int = 3 /* 1x */
    var playlistClaim: Claim?
    var claim: Claim?
    var claimUrl: LbryUri?
    var subscribeUnsubscribeInProgress = false
    var relatedContent: [Claim] = []
    var playlistItems: [Claim] = []
    var currentPlaylistIndex: Int = 0
    var channels: [Claim] = []
    var loadingRelated = false
    var loadingPlaylist = false
    var fileViewLogged = false
    var loggingInProgress = false
    var playRequestTime: Int64 = 0
    var playerObserverAdded = false
    var imageViewerActive = false
    var otherContentWebUrl: String?
    var currentStreamUrl: URL?
    var streamInfoUrl: URL?

    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var comments = OrderedSet<Comment>()
    var authorThumbnailMap = [String: URL]()
    var currentCommentAsIndex = -1
    // From notification
    var currentCommentIsReply: Bool = false
    var currentCommentId: String?

    var numLikes = 0
    var numDislikes = 0
    var likesContent = false
    var dislikesContent = false
    var reacting = false
    var playerConnected = false
    var playerRate: Float = 1
    var isLivestream = false
    var isPlaylist = false
    var isLive = false
    var isTextContent = false
    var isImageContent = false
    var isOtherContent = false
    var membersOnly = false
    var avpcInitialised = false

    var loadingChannels = false
    var postingChat = false
    var messages: [Comment] = []
    var chatConnected = false
    var initialChatLoaded = false
    var chatWebsocket: Starscream.WebSocket?

    let checkLivestreamTranscodeInterval: Double = 30 // 30 seconds
    var checkLivestreamTranscodeTimer = Timer()
    var checkLivestreamTranscodeScheduled = false
    let bigThumbSpec = ImageSpec(size: CGSize(width: 0, height: 0), quality: 95)

    let availableRates = ["0.25x", "0.5x", "0.75x", "1x", "1.25x", "1.5x", "1.75x", "2x"]

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
        if AppDelegate.shared.currentClaim == claim ||
            (playlistItems.count > currentPlaylistIndex &&
                AppDelegate.shared.currentClaim == playlistItems[currentPlaylistIndex])
        {
            AppDelegate.shared.mainController.toggleMiniPlayer(hidden: true)
        }
        AppDelegate.shared.currentFileViewController = self

        if let claim, !isPlaylist {
            checkFollowing(claim)
            checkNotificationsDisabled(claim)
        }
    }

    // Returns true if reposted claim is a channel
    func checkRepost() -> Bool {
        if let claim = claim?.repostedClaim, let name = claim.name {
            if name.starts(with: "@") {
                // reposted channel, simply dismiss the view and show a channel view controller instead
                navigationController?.popViewController(animated: false)
                let vc = AppDelegate.shared.mainController.storyboard?
                    .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                vc.channelClaim = claim
                AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)

                return true
            }
        }
        return false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [AnalyticsParameterScreenName: "File", AnalyticsParameterScreenClass: "FileViewController"]
        )
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    override func viewDidLayoutSubviews() {
        mediaViewHeight = mediaViewHeightConstraint.constant
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        AppDelegate.shared.mainController.updateMiniPlayer()

        if AppDelegate.shared.lazyPlayer != nil {
            AppDelegate.shared.mainController.toggleMiniPlayer(hidden: false)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disconnectChatSocket()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        relatedContentListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")

        if #available(iOS 16, *) {
        } else {
            let rateActionHandler: UIActionHandler = { action in
                self.playerRateButton.setTitle(action.title, for: .normal)
                let rate = Float(action.title.dropLast()) ?? 1
                self.avpc.player?.rate = rate
                self.playerRate = rate
            }
            let rateActions = availableRates.map { title in UIAction(title: title, handler: rateActionHandler) }
            playerRateButton.menu = UIMenu(title: "", children: rateActions)
        }

        registerForKeyboardNotifications()

        imageViewer.setup()
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        contentInfoViewButton.layer.masksToBounds = true
        contentInfoViewButton.layer.cornerRadius = 16

        relatedContentListView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        featuredCommentThumbnail.rounded()
        livestreamOfflineMessageView.layer.cornerRadius = 8

        loadChannels()

        // Do any additional setup after loading the view.
        if claim == nil, claimUrl != nil {
            resolveAndDisplayClaim()
        } else if let currentClaim = claim,
                  let signingChannel = currentClaim.signingChannel,
                  let claimId = currentClaim.claimId
        {
            if checkRepost() {
                return
            }
            if Lbryio.isClaimBlocked(currentClaim) || Lbryio.isClaimBlocked(signingChannel) {
                displayClaimBlocked()
            } else if Lbryio.isClaimAppleFiltered(currentClaim) || Lbryio.isClaimAppleFiltered(signingChannel) {
                displayClaimBlockedWithMessage(
                    message: Lbryio.getFilteredMessageForClaim(claimId, signingChannel.claimId ?? "")
                )
            } else if Helper.isCustomBlocked(claimId: claimId, appDelegate: AppDelegate.shared) ||
                Helper.isCustomBlocked(claimId: signingChannel.claimId ?? "", appDelegate: AppDelegate.shared)
            {
                displayClaimBlockedWithMessage(
                    message: Helper.getCustomBlockedMessage(
                        claimId: claimId, appDelegate: AppDelegate.shared
                    ) ?? Helper.getCustomBlockedMessage(
                        claimId: signingChannel.claimId ?? "",
                        appDelegate: AppDelegate.shared
                    ) ?? ""
                )
            } else if currentClaim.value?.tags?.contains(Constants.MembersOnly) ?? false {
                membersOnly = true
                checkHasAccess()
            } else {
                displayClaim()
                if !isPlaylist {
                    loadAndDisplayViewCount(currentClaim)
                    loadReactions(currentClaim)
                }
                loadPlaylistOrRelated()
            }
        } else {
            displayNothingAtLocation()
        }
    }

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let info = notification.userInfo {
            let kbSize = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
            bottomLayoutConstraint.constant = kbSize.height
            streamerAreaHeightConstraint.constant = 0
            livestreamerArea.isHidden = true
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        bottomLayoutConstraint.constant = 0
        streamerAreaHeightConstraint.constant = 56
        livestreamerArea.isHidden = false
    }

    func checkHasAccess() {
        let isLivestream = !isPlaylist && claim?.value?.source == nil
        DispatchQueue.global().async {
            MembershipPerk.perkCheck(
                authToken: Lbryio.authToken,
                claimId: self.claim?.claimId,
                type: isLivestream ? .livestream : .content
            ) { result in
                if case let .success(hasAccess) = result {
                    DispatchQueue.main.async {
                        if !hasAccess {
                            self.displayClaimBlockedWithMessage(
                                message: "Only channel members can view this content\nJoin on odysee.com"
                            )
                        } else {
                            self.claim?.value?.tags?.removeAll { $0 == Constants.MembersOnly }
                            self.showClaimAndCheckFollowing()
                        }
                    }
                }
            }
        }
    }

    func showClaimAndCheckFollowing() {
        if checkRepost() {
            return
        }
        guard let claim, let signingChannel = claim.signingChannel else {
            return
        }

        if Lbryio.isClaimBlocked(claim) || Lbryio.isClaimBlocked(signingChannel) {
            displayClaimBlocked()
        } else if Lbryio.isClaimAppleFiltered(claim) || Lbryio.isClaimAppleFiltered(signingChannel) {
            displayClaimBlockedWithMessage(message: Lbryio.getFilteredMessageForClaim(
                claim.claimId ?? "", signingChannel.claimId ?? ""
            ))
        } else if Helper.isCustomBlocked(claimId: claim.claimId ?? "", appDelegate: AppDelegate.shared) ||
            Helper.isCustomBlocked(claimId: signingChannel.claimId ?? "", appDelegate: AppDelegate.shared)
        {
            displayClaimBlockedWithMessage(message:
                Helper.getCustomBlockedMessage(
                    claimId: claim.claimId ?? "",
                    appDelegate: AppDelegate.shared
                ) ?? Helper.getCustomBlockedMessage(
                    claimId: signingChannel.claimId ?? "",
                    appDelegate: AppDelegate.shared
                ) ?? ""
            )
        } else if claim.value?.tags?.contains(Constants.MembersOnly) ?? false {
            membersOnly = true
            checkHasAccess()
        } else {
            displayClaim()
            if !isPlaylist {
                loadAndDisplayViewCount(claim)
                loadReactions(claim)
                checkFollowing(claim)
                checkNotificationsDisabled(claim)
            }
            loadPlaylistOrRelated()
        }
    }

    func resolveAndDisplayClaim() {
        displayResolving()

        guard let url = claimUrl?.description else {
            showError(message: "couldn't get claimUrl")
            return
        }

        claim = Lbry.cachedClaim(url: url)
        if claim != nil {
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
        guard case let .success(resolve) = result, let entry = resolve.claims.first else {
            displayNothingAtLocation()
            return
        }

        claim = entry.value
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

    func displayClaimBlocked() {
        displayClaimBlockedWithMessage(
            message: "In response to a complaint we received under the US Digital Millennium Copyright Act, we have blocked access to this content from our applications."
        )
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
        if gestureRecognizer == dismissPanRecognizer {
            let translation = dismissPanRecognizer.translation(in: view)
            return abs(translation.y) > abs(translation.x)
        }
        return true
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
     }
     */

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }

    @objc func loadStreamInfo() {
        guard let streamInfoUrl, let claim else {
            showError(message: "couldn't get streamInfoUrl and/or claim")
            return
        }

        let session = URLSession.shared
        var req = URLRequest(url: streamInfoUrl)
        req.httpMethod = "GET"

        let task = session.dataTask(with: req, completionHandler: { data, _, error in
            guard let data = data, error == nil else {
                // handle error
                self.showError(message: "The livestream could not be loaded right now. Please try again later.")
                return
            }
            do {
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let livestreamData = response?["data"] as? [String: Any] {
                    self.isLive = livestreamData["live"] as? Bool ?? false
                    if !self.isLive {
                        self.displayLivestreamOffline()
                        return
                    }

                    if let streamUrl = (livestreamData["url"] as? String).flatMap(URL.init) {
                        if self.currentStreamUrl != nil, self.currentStreamUrl == streamUrl {
                            // no change
                            if self.checkLivestreamTranscodeScheduled {
                                self.checkLivestreamTranscodeTimer.invalidate()
                            }
                            return
                        }
                        let headers: [String: String] = [
                            "Referer": "https://ios.odysee.com/",
                        ]
                        DispatchQueue.main.async {
                            self.initializePlayerWithUrl(
                                singleClaim: claim, sourceUrl: streamUrl, headers: headers, forceInit: true
                            )
                        }
                        self.currentStreamUrl = streamUrl
                        // schedule livestream transcoded check
                        self.checkLivestreamTranscoded()
                    }
                }
            } catch {
                self.showError(message: "The livestream could not be loaded right now. Please try again later.")
                self.isLive = false
            }
        })
        task.resume()
    }

    func loadLivestream() {
        if !isLivestream {
            return
        }

        loadInitialChatMessages()
        loadLivestreamNew()
    }

    func loadLivestreamNew() {
        guard let claim,
              let claimId = claim.signingChannel?.claimId,
              let checkLiveUrl = URL(string: String(
                  format: "https://api.odysee.live/livestream/is_live?channel_claim_id=%@",
                  claimId
              ))
        else {
            showError(message: "couldn't get claim and/or checkLiveUrl")
            return
        }

        let session = URLSession.shared
        var req = URLRequest(url: checkLiveUrl)
        req.httpMethod = "GET"

        let task = session.dataTask(with: req, completionHandler: { data, _, error in
            guard let data = data, error == nil else {
                // handle error
                self.showError(message: "The livestream could not be loaded right now. Please try again later.")
                return
            }
            do {
                let response = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let livestreamData = response?["data"] as? [String: Any] {
                    let live = livestreamData["Live"] as? Bool ?? false
                    if !live {
                        self.loadLivestreamLegacy()
                        return
                    }

                    if let streamUrl = (livestreamData["VideoURL"] as? String).flatMap(URL.init) {
                        if !self.membersOnly {
                            let headers: [String: String] = [
                                "Referer": "https://ios.odysee.com/",
                            ]
                            DispatchQueue.main.async {
                                self.initializePlayerWithUrl(
                                    singleClaim: claim, sourceUrl: streamUrl, headers: headers, forceInit: true
                                )
                            }
                        } else {
                            self.getStreamingUrl(
                                claim,
                                baseStreamingUrl: streamUrl.absoluteString
                            )
                        }
                        self.currentStreamUrl = streamUrl
                    }
                }
            } catch {
                // use the old approach
                self.loadLivestreamLegacy()
            }
        })
        task.resume()
    }

    func loadLivestreamLegacy() {
        guard let claimId = claim?.signingChannel?.claimId else {
            showError(message: "couldn't get claimId")
            return
        }
        streamInfoUrl =
            URL(string: String(
                format: "https://api.live.odysee.com/v1/odysee/live/%@",
                claimId
            ))
        loadStreamInfo()
    }

    func displayLivestreamOffline() {
        DispatchQueue.main.async {
            AppDelegate.shared.lazyPlayer = nil

            self.avpc.view.isHidden = true
            self.livestreamOfflinePlaceholder.isHidden = false
            self.livestreamOfflineMessageView.isHidden = false
            self.livestreamOfflineLabel.text = String(
                format: String.localized("%@ isn't live right now. Check back later to watch the stream."),
                self.claim?.signingChannel?.name ?? ""
            )
        }
    }

    func checkLivestreamTranscoded() {
        if !checkLivestreamTranscodeScheduled {
            checkLivestreamTranscodeTimer = Timer.scheduledTimer(
                timeInterval: checkLivestreamTranscodeInterval,
                target: self,
                selector: #selector(loadStreamInfo),
                userInfo: nil,
                repeats: true
            )
            checkLivestreamTranscodeScheduled = true
        }
    }

    func checkCommentsDisabled(commentsDisabled: Bool, currentClaim: Claim) {
        DispatchQueue.main.async {
            self.commentsDisabled = commentsDisabled || self.membersOnly
            self.commentExpandView.isHidden = commentsDisabled || self.membersOnly
            self.noCommentsLabel.isHidden = !(commentsDisabled || self.membersOnly)
            self.noCommentsLabel.text = String
                .localized(
                    commentsDisabled ? "Comments are disabled." :
                        (
                            self.membersOnly ?
                                "Member only comments are only supported on odysee.com at this time" :
                                "There are no comments to display at this time. Be the first to post a comment!"
                        )
                )
            self.featuredCommentView.isHidden = commentsDisabled || self.membersOnly

            if !self.commentsDisabled {
                self.loadComments(currentClaim)
                if self.currentCommentId != nil {
                    self.commentAreaTapped(self)
                }
            }
        }
    }

    func displayClaimContentFromUrl(singleClaim: Claim, contentType: String, contentUrl: URL) {
        guard let permanentUrl = singleClaim.permanentUrl else {
            showError(message: "couldn't get permanentUrl")
            return
        }

        if isTextContent {
            webView.isHidden = false
            contentInfoDescription.text = String.localized("Loading content...")
            contentInfoLoading.isHidden = false
            loadTextContent(url: contentUrl, contentType: contentType)
            logFileView(url: permanentUrl, timeToStart: 0)
        } else if isImageContent {
            var thumbnailDisplayUrl = contentUrl
            if let thumbnail = singleClaim.value?.thumbnail?.url, !thumbnail.isBlank,
               let thumbnailUrl = URL(string: thumbnail)
            {
                thumbnailDisplayUrl = thumbnailUrl.makeImageURL(spec: bigThumbSpec)
            }
            contentInfoImage.pin_setImage(from: thumbnailDisplayUrl)
            let manager = PINRemoteImageManager.shared()
            manager.setValue("https://ios.odysee.com/", forHTTPHeaderField: "Referer")
            manager.downloadImage(with: contentUrl) { result in
                guard let image = result.image else { return }
                Thread.performOnMain {
                    self.imageViewer.display(image: image)
                }
            }
            contentInfoViewButton.isHidden = false
            logFileView(url: permanentUrl, timeToStart: 0)
        } else if let url = LbryUri.tryParse(url: permanentUrl, requireProto: false) {
            contentInfoLoading.isHidden = true
            let messageString = NSMutableAttributedString(string: String(
                format: String
                    .localized(
                        "This content cannot be viewed in the Odysee app at this time. Please open %@ in your web browser."
                    ),
                url.odyseeString
            ))
            let range = messageString.mutableString.range(of: url.odyseeString)
            if range.location != NSNotFound {
                messageString.addAttribute(.link, value: url.odyseeString, range: range)
            }
            contentInfoDescription.attributedText = messageString
            otherContentWebUrl = url.odyseeString
        }
    }

    func displaySingleClaim(_ singleClaim: Claim) {
        guard let permanentUrl = singleClaim.permanentUrl else {
            showError(message: "couldn't get permanentUrl")
            return
        }

        commentsDisabledChecked = false
        resolvingView.isHidden = true
        descriptionArea.isHidden = true
        descriptionDivider.isHidden = true

        var contentType: String?
        if let mediaType = claim?.value?.source?.mediaType {
            isTextContent = mediaType.starts(with: "text/")
            isImageContent = mediaType.starts(with: "image/")
            isOtherContent = !isTextContent && !isImageContent && !mediaType.starts(with: "video") && !mediaType
                .starts(with: "audio")
            contentType = mediaType
        }

        otherContentWebUrl = nil
        closeOtherContentButton.isHidden = true
        contentInfoView.isHidden = true
        mediaView.isHidden = false
        mediaViewHeightConstraint.constant = mediaViewHeight

        if isTextContent || isImageContent || isOtherContent {
            dismissFileView.isHidden = true
            contentInfoView.isHidden = false
            closeOtherContentButton.isHidden = false
            contentInfoViewButton.isHidden = true
            contentInfoImage.image = nil

            var params = [String: Any]()
            params["uri"] = permanentUrl
            Lbry.apiCall(
                method: Lbry.methodGet,
                params: params,
                connectionString: Lbry.lbrytvConnectionString,
                authToken: Lbryio.authToken,
                completion: { data, error in
                    guard let data = data, error == nil else {
                        self.showError(error: error)
                        return
                    }

                    if let result = data["result"] as? [String: Any] {
                        if let streamingUrl = result["streaming_url"] as? String,
                           let contentUrl = URL(
                               string: streamingUrl
                                   .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                           )
                        {
                            DispatchQueue.main.async {
                                self.displayClaimContentFromUrl(
                                    singleClaim: singleClaim,
                                    contentType: contentType ?? "",
                                    contentUrl: contentUrl
                                )
                            }
                        }
                    }
                }
            )
        } else if !avpcInitialised {
            avpc.allowsPictureInPicturePlayback = true
            avpc.updatesNowPlayingInfoCenter = false
            addChild(avpc)

            if #available(iOS 16, *) {
            } else {
                playerRateView.isHidden = false
                jumpBackwardView.isHidden = false
                jumpForwardView.isHidden = false
                avpc.playerRateView = playerRateView
                avpc.jumpBackwardView = jumpBackwardView
                avpc.jumpForwardView = jumpForwardView
                avpcIsReadyObserver = avpc.observe(\.player?.rate, options: .new) { avpc, _ in
                    if avpc.player?.rate ?? 0 > 0 {
                        avpc.hideViewsTimer?.invalidate()
                        avpc.hideViewsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseIn) {
                                avpc.playerRateView?.alpha = 0
                                avpc.jumpBackwardView?.alpha = 0
                                avpc.jumpForwardView?.alpha = 0
                            }
                        }
                    }
                }
            }

            avpc.view.frame = mediaView.bounds
            mediaView.addSubview(avpc.view)
            avpc.didMove(toParent: self)

            avpcInitialised = true
        }

        if let channelId = claim?.signingChannel?.claimId, let name = claim?.signingChannel?.name {
            Lbryio.areCommentsEnabled(
                channelId: channelId,
                channelName: name,
                completion: { enabled in
                    self.commentsDisabledChecked = true
                    self.checkCommentsDisabled(commentsDisabled: !enabled, currentClaim: singleClaim)
                }
            )
        }

        titleLabel.text = singleClaim.value?.title

        let releaseTime = Double(singleClaim.value?.releaseTime ?? "0") ?? 0
        let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?

        timeAgoLabel.text = Helper.fullRelativeDateFormatter.localizedString(for: date, relativeTo: Date())

        // publisher
        var thumbnailUrl: URL?
        publisherImageView.rounded()
        livestreamerImageView.rounded()
        if singleClaim.signingChannel != nil {
            if !isLivestream {
                publisherTitleLabel.text = singleClaim.signingChannel?.value?.title
                publisherNameLabel.text = singleClaim.signingChannel?.name
            } else {
                livestreamerTitleLabel.text = singleClaim.signingChannel?.value?.title
                livestreamerNameLabel.text = singleClaim.signingChannel?.name
            }
            if let thumbnail = singleClaim.signingChannel?.value?.thumbnail?.url,
               let thumbnailUrl_ = URL(string: thumbnail)
            {
                thumbnailUrl = thumbnailUrl_.makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
            }
        } else {
            publisherTitleLabel.text = String.localized("Anonymous")
            publisherActionsArea.isHidden = true
        }

        if let thumbnailUrl {
            let optimisedThumbUrl = thumbnailUrl.makeImageURL(spec: ClaimTableViewCell.channelImageSpec)
            if !isLivestream {
                publisherImageView.load(url: optimisedThumbUrl)
            } else {
                livestreamerImageView.load(url: optimisedThumbUrl)
            }
        } else {
            if !isLivestream {
                publisherImageView.image = UIImage(named: "spaceman")
                publisherImageView.backgroundColor = Helper.lightPrimaryColor
            } else {
                livestreamerImageView.image = UIImage(named: "spaceman")
                livestreamerImageView.backgroundColor = Helper.lightPrimaryColor
            }
        }

        if (singleClaim.value?.description).isBlank {
            descriptionArea.isHidden = true
            descriptionDivider.isHidden = true
            titleAreaIconView.isHidden = true
        } else {
            // details
            descriptionTextView.text = claim?.value?.description
        }
    }

    @IBAction func viewContentTapped(_ sender: UIButton) {
        imageViewer.isHidden = false
        imageViewer.layoutIfNeeded()
        imageViewerActive = true
    }

    @IBAction func contentInfoTapped(_ sender: Any) {
        if let url = URL(string: otherContentWebUrl ?? "") {
            let vc = SFSafariViewController(url: url)
            AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
        }
    }

    func loadTextContent(url: URL, contentType: String?) {
        DispatchQueue.global().async {
            do {
                var request = URLRequest(url: url)
                request.setValue("https://ios.odysee.com/", forHTTPHeaderField: "Referer")
                URLSession.shared.dataTask(with: request) { result in
                    guard case let .success(data) = result,
                          let contents = String(data: data.data, encoding: .utf8)
                    else {
                        self.handleContentLoadError(String(
                            format: String.localized("Could not load URL %@"),
                            url.absoluteString
                        ))
                        return
                    }

                    if contentType == "text/md" || contentType == "text/markdown" || contentType == "text/x-markdown" {
                        guard let html = contents.markdownToHTML else {
                            self
                                .handleContentLoadError(String(
                                    format: String.localized("Could not load URL %@"),
                                    url.absoluteString
                                ))
                            return
                        }

                        let mdHtml = self.buildMarkdownHTML(html)
                        self.loadWebViewContent(mdHtml)
                    } else if contentType == "text/html" {
                        self.loadWebViewContent(contents)
                    } else {
                        self.loadWebViewContent(self.buildPlainTextHTML(contents))
                    }
                }.resume()
            } catch {
                self
                    .handleContentLoadError(String(
                        format: String.localized("Could not load URL %@"),
                        url.absoluteString
                    ))
            }
        }
    }

    func loadWebViewContent(_ content: String) {
        DispatchQueue.main.async {
            self.webView.loadHTMLString(content, baseURL: nil)
        }
    }

    func buildPlainTextHTML(_ text: String) -> String {
        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8"/>
            <meta name="viewport" content="width=device-width, user-scalable=no"/>
            <style type="text/css">
              :root { color-scheme: light dark; }
              body { font-family: sans-serif; padding: 16px; overflow-wrap: break-word }
              img { width: 100%; }
              pre { white-space: pre-wrap; word-wrap: break-word; }
            </style>
          </head>
          <body>
            <pre>\(text)</pre>
          </body>
        </html>
        """
    }

    func buildMarkdownHTML(_ markdownHtml: String) -> String {
        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8"/>
            <meta name="viewport" content="width=device-width, user-scalable=no"/>
            <style type="text/css">
              :root { color-scheme: light dark; }
              body { font-family: sans-serif; padding: 16px; overflow-wrap: break-word }
              img { width: 100%; }
              pre { white-space: pre-wrap; word-wrap: break-word; }
              a { color: #DE0050 }
            </style>
          </head>
          <body>
            <div id="content">
        \(markdownHtml)
            </div>
          </body>
        </html>
        """
    }

    func loadWebViewURL(_ url: URL) {
        DispatchQueue.main.async {
            self.webView.load(URLRequest(url: url))
        }
    }

    func handleContentLoadError(_ message: String) {
        DispatchQueue.main.async {
            self.showError(message: message)
            self.webView.isHidden = true
            self.webViewHeightConstraint.constant = 0
        }
    }

    func displayClaim() {
        guard let claim else {
            displayNothingAtLocation()
            return
        }

        isPlaylist = if let playlist = playlistClaim {
            playlist.valueType == .collection
        } else {
            claim.valueType == .collection
        }
        isLivestream = !isPlaylist && claim.value?.source == nil
        detailsScrollView.isHidden = isLivestream
        livestreamChatView.isHidden = !isLivestream
        reloadStreamView.isHidden = !isLivestream
        relatedOrPlaylistTitle.text = isPlaylist ?
            (playlistClaim?.value?.title ?? claim.value?.title) :
            String.localized("Related Content")

        displayRelatedPlaceholders()

        if !isPlaylist {
            // for a playlist, we need to do a claim_search for the list of claim IDs first, and then display the first result
            connectChatSocket()
            displaySingleClaim(claim)

            // check if the content is paid
            if let fee = claim.value?.fee?.amount,
               let amount = Decimal(string: fee),
               amount > 0
            {
                let alert = UIAlertController(
                    title: String.localized("Content not supported"),
                    message: String.localized("This content is not supported in the app at this time."),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in }))
                present(alert, animated: true, completion: nil)
                return
            }

            if isLivestream {
                loadLivestream()
            } else if !isTextContent, !isImageContent, !isOtherContent {
                getStreamingUrl(claim)
            }
        }
    }

    func initializePlayerWithUrl(
        singleClaim: Claim,
        sourceUrl: URL,
        headers: [String: String] = [:],
        forceInit: Bool = false
    ) {
        assert(Thread.isMainThread)

        livestreamOfflinePlaceholder.isHidden = true

        avpc.delegate = AppDelegate.shared.mainController
        if !forceInit, AppDelegate.shared.lazyPlayer != nil, AppDelegate.shared.currentClaim != nil,
           AppDelegate.shared.currentClaim?.claimId == singleClaim.claimId
        {
            mediaLoadingIndicator.isHidden = true

            // Normally not needed,
            // but set this in case the state gets messed up and this FileViewController is new
            avpc.canStartPictureInPictureAutomaticallyFromInline = true

            avpc.player = AppDelegate.shared.lazyPlayer
            playerConnected = true
            return
        }

        let asset = AVURLAsset(url: sourceUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        currentPlayer = AVPlayer(playerItem: playerItem)

        AppDelegate.shared.currentClaim = singleClaim

        avpc.player = currentPlayer

        playerStartedObserver = currentPlayer?.observe(\.rate, options: .new) { [self] _, _ in
            playerStartedObserver = nil

            let saveCurrent = AppDelegate.shared.currentClaim
            let saveCurrentPlaylist = AppDelegate.shared.currentPlaylistClaim
            (AppDelegate.shared.mainViewController as? MainViewController)?.closeMiniPlayerTapped(self)
            AppDelegate.shared.currentClaim = saveCurrent
            AppDelegate.shared.currentPlaylistClaim = saveCurrentPlaylist

            AppDelegate.shared.lazyPlayer?.pause()

            AppDelegate.shared.lazyPlayer = currentPlayer
            currentPlayer = nil

            AppDelegate.shared.playerObserverAdded = false
            AppDelegate.shared.registerPlayerObserver()
            playerConnected = true
            playRequestTime = Int64(Date().timeIntervalSince1970 * 1000.0)

            avpc.canStartPictureInPictureAutomaticallyFromInline = true
            if UserDefaults.standard.integer(forKey: "BackgroundPlaybackMode") != 0 {
                avpc.allowsPictureInPicturePlayback = false
            }

            AppDelegate.shared.setupRemoteTransportControls()
        }

        Task {
            _ = try? await asset.load(.duration)
            mediaLoadingIndicator.isHidden = true
        }

        AppDelegate.shared.lazyPlayer?.pause()
        avpc.player?.play()

        let task = DispatchWorkItem { [weak self] in
            self?.dismissFileView.isHidden = true
        }
        // hide the dismiss file view control 5 seconds after playback starts
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5, execute: task)
    }

    func displayRelatedPlaceholders() {
        if isLivestream {
            return
        }

        relatedContent = []
        for _ in 1 ... 15 {
            let placeholder = Claim()
            placeholder.claimId = "placeholder"
            relatedContent.append(placeholder)
        }
        relatedContentListView.reloadData()
    }

    func checkTimeToStart() {
        if fileViewLogged || loggingInProgress {
            return
        }

        let timeToStartMs = Int64(Date().timeIntervalSince1970 * 1000.0) - playRequestTime
        let timeToStartSeconds = Int64(Double(timeToStartMs) / 1000.0)
        if let claimUrl = isPlaylist ? currentPlaylistClaim().permanentUrl : claim?.permanentUrl {
            Analytics.logEvent("play", parameters: [
                "url": claimUrl,
                "time_to_start_ms": timeToStartMs,
                "time_to_start_seconds": timeToStartSeconds,
            ])

            logFileView(url: claimUrl, timeToStart: timeToStartMs)
        }
    }

    func disconnectPlayer() {
        avpc.player = nil
        playerConnected = false
    }

    func connectPlayer() {
        if AppDelegate.shared.lazyPlayer != nil {
            avpc.player = AppDelegate.shared.lazyPlayer
        }
        playerConnected = true
    }

    func logFileView(url: String, timeToStart: Int64) {
        if loggingInProgress {
            return
        }

        guard let claimId = claim?.claimId, let txid = claim?.txid, let nout = claim?.nout else {
            showError(message: "couldn't get claim info")
            return
        }

        loggingInProgress = true

        var options = [String: String]()
        options["uri"] = url
        options["claim_id"] = claimId
        options["outpoint"] = String(format: "%@:%d", txid, nout)
        if timeToStart > 0 {
            options["time_to_start"] = String(timeToStart)
        }

        do {
            try Lbryio.post(resource: "file", action: "view", options: options, completion: { _, _ in
                // no need to check for errors here
                self.loggingInProgress = false
                self.fileViewLogged = true
                self.claimDailyView()
            })
        } catch {
            // pass
        }
    }

    func claimDailyView() {
        if let receiveAddress = UserDefaults.standard.string(forKey: Helper.keyReceiveAddress),
           !receiveAddress.isBlank
        {
            Lbryio.claimReward(type: "daily_view", walletAddress: receiveAddress, completion: { _, _ in
                // don't do anything here
            })
        } else {
            Lbry.apiCall(
                method: Lbry.Methods.addressUnused,
                params: .init()
            )
            .subscribeResult { result in
                guard case let .success(newAddress) = result else {
                    return
                }

                UserDefaults.standard.set(newAddress, forKey: Helper.keyReceiveAddress)
                Lbryio.claimReward(type: "daily_view", walletAddress: newAddress, completion: { _, _ in })
            }
        }
    }

    func loadAndDisplayViewCount(_ singleClaim: Claim) {
        if isLivestream {
            return
        }

        guard let claimId = singleClaim.claimId else {
            showError(message: "couldn't get claimId")
            return
        }

        do {
            try Lbryio.get(
                resource: "file",
                action: "view_count",
                options: ["claim_id": claimId],
                completion: { data, error in
                    guard let data = data, error == nil else {
                        // couldn't load the view count for display
                        DispatchQueue.main.async {
                            self.viewCountLabel.isHidden = true
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        let formatter = Helper.interactionCountFormatter
                        let viewCount = (data as! NSArray)[0] as! Int
                        self.viewCountLabel.isHidden = false
                        self.viewCountLabel.text = String(
                            format: viewCount == 1 ? String.localized("%@ view") : String.localized("%@ views"),
                            formatter.string(for: viewCount) ?? ""
                        )
                    }
                }
            )
        } catch {
            // pass
        }
    }

    func loadReactions(_ singleClaim: Claim) {
        if isLivestream {
            return
        }

        guard let claimId = singleClaim.claimId else {
            showError(message: "couldn't get claimId")
            return
        }

        do {
            let options: [String: String] = ["claim_ids": claimId]
            try Lbryio.post(resource: "reaction", action: "list", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }
                DispatchQueue.main.async {
                    // let viewCount = (data as! NSArray)[0] as! Int
                    self.numLikes = 0
                    self.numDislikes = 0
                    if let reactions = data as? [String: Any] {
                        if let myReactions = reactions["my_reactions"] as? [String: Any] {
                            let values = myReactions[claimId] as! [String: Any]
                            let likeCount = values["like"] as? Int
                            let dislikeCount = values["dislike"] as? Int
                            if (likeCount ?? 0) > 0 {
                                self.likesContent = true
                                self.numLikes += 1
                            }
                            if (dislikeCount ?? 0) > 0 {
                                self.dislikesContent = true
                                self.numDislikes += 1
                            }
                        }
                        if let othersReactions = reactions["others_reactions"] as? [String: Any] {
                            let values = othersReactions[claimId] as! [String: Any]
                            let likeCount = values["like"] as? Int
                            let dislikeCount = values["dislike"] as? Int
                            self.numLikes += likeCount ?? 0
                            self.numDislikes += dislikeCount ?? 0
                        }
                    }

                    self.displayReactionCounts()
                    self.checkMyReactions()
                }
            })
        } catch {
            // pass
        }
    }

    func displayReactionCounts() {
        DispatchQueue.main.async {
            let formatter = Helper.interactionCountFormatter
            self.fireReactionCountLabel.text = formatter.string(for: self.numLikes)
            self.slimeReactionCountLabel.text = formatter.string(for: self.numDislikes)
        }
    }

    func react(type: String) {
        if reacting {
            return
        }

        reacting = true
        let oldLikesContent = likesContent
        let oldNumLikes = numLikes
        let oldDislikesContent = dislikesContent
        let oldNumDislikes = numDislikes
        do {
            var remove = false
            guard let claimId = isPlaylist ? currentPlaylistClaim().claimId : claim?.claimId else {
                throw GenericError("couldn't get claimId")
            }
            var options: [String: String] = [
                "claim_ids": claimId,
                "type": type,
                "clear_types": type == Helper.reactionTypeLike ? Helper.reactionTypeDislike : Helper.reactionTypeLike,
            ]
            if (type == Helper.reactionTypeLike && likesContent) ||
                (type == Helper.reactionTypeDislike && dislikesContent)
            {
                remove = true
                options["remove"] = "true"
            }

            if type == Helper.reactionTypeLike {
                likesContent = !remove
                numLikes += (remove ? -1 : 1)
                if !remove, dislikesContent {
                    numDislikes -= 1
                    dislikesContent = false
                }
            }
            if type == Helper.reactionTypeDislike {
                dislikesContent = !remove
                numDislikes += (remove ? -1 : 1)
                if !remove, likesContent {
                    numLikes -= 1
                    likesContent = false
                }
            }
            displayReactionCounts()
            checkMyReactions()

            try Lbryio.post(resource: "reaction", action: "react", options: options, completion: { data, error in
                self.reacting = false

                guard data != nil, error == nil else {
                    self.showError(error: error)
                    self.likesContent = oldLikesContent
                    self.numLikes = oldNumLikes
                    self.dislikesContent = oldDislikesContent
                    self.numDislikes = oldNumDislikes
                    self.displayReactionCounts()
                    self.checkMyReactions()
                    return
                }
            })
        } catch {
            showError(error: error)
            reacting = false
            likesContent = oldLikesContent
            numLikes = oldNumLikes
            dislikesContent = oldDislikesContent
            numDislikes = oldNumDislikes
            displayReactionCounts()
            checkMyReactions()
        }
    }

    func checkMyReactions() {
        DispatchQueue.main.async {
            self.fireReactionImage.tintColor = self.likesContent ? Helper.fireActiveColor : UIColor.label
            self.slimeReactionImage.tintColor = self.dislikesContent ? Helper.slimeActiveColor : UIColor.label
        }
    }

    func loadPlaylistOrRelated() {
        if isPlaylist {
            loadPlaylistContent()
            return
        }

        loadRelatedContent()
    }

    func loadPlaylistContent() {
        if loadingPlaylist || isLivestream {
            return
        }

        var playlistClaims: [String]?
        if let playlist = playlistClaim {
            playlistClaims = playlist.value?.claims
            if let claimId = claim?.claimId {
                currentPlaylistIndex = playlistClaims?.firstIndex(of: claimId) ?? 0
            }
        } else {
            AppDelegate.shared.currentPlaylistClaim = claim
            playlistClaims = claim?.value?.claims
        }

        if playlistItems.count == 0 {
            displayResolving()
        }

        loadingRelated = true
        loadingRelatedView.isHidden = false

        if let playlistClaims {
            Lbry.apiCall(
                method: Lbry.Methods.claimSearch,
                params: .init(
                    claimType: [.stream],
                    page: 1,
                    pageSize: 999, // FIXME: pagination
                    releaseTime: [Helper.releaseTimeBeforeFuture],
                    notTags: Constants.NotTags + [Constants.MembersOnly],
                    claimIds: playlistClaims,
                    orderBy: Helper.sortByItemValues[1]
                )
            )
            .subscribeResult(didLoadPlaylistClaims)
        }
    }

    func didLoadPlaylistClaims(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        result.showErrorIfPresent()
        if case let .success(payload) = result {
            let playlistClaims = if let playlist = playlistClaim {
                playlist.value?.claims
            } else {
                claim?.value?.claims
            }

            if let playlistClaims {
                playlistItems = payload.items.sorted(like: playlistClaims, keyPath: \.claimId, transform: \.self)
            }
            relatedContentListView.reloadData()
        }
        loadingRelatedView.isHidden = true
        loadingRelated = false

        let singleClaim = playlistItems[currentPlaylistIndex]
        loadPlaylistItemClaim(singleClaim)
    }

    func playPreviousPlaylistItem() {
        if !isPlaylist || playlistItems.count == 0 {
            return
        }

        if currentPlaylistIndex > 0 {
            currentPlaylistIndex -= 1
            loadPlaylistItemClaim(playlistItems[currentPlaylistIndex])
        }
    }

    func playNextPlaylistItem() {
        if !isPlaylist || playlistItems.count == 0 {
            return
        }

        if currentPlaylistIndex < playlistItems.count - 1 {
            currentPlaylistIndex += 1
            loadPlaylistItemClaim(playlistItems[currentPlaylistIndex])
        }
    }

    func loadPlaylistItemClaim(_ singleClaim: Claim) {
        detailsScrollView.setContentOffset(.zero, animated: true)

        comments.removeAll()

        displaySingleClaim(singleClaim)
        if commentsVc != nil {
            commentsVc.comments.removeAll()
            commentsVc.resetCommentList()
            commentsVc.claimId = singleClaim.claimId
            commentsVc.commentsLastPageReached = false
            commentsVc.commentsDisabled = commentsDisabled
            if !commentsVc.commentsDisabled {
                commentsVc.loadComments()
            }
        }

        if !isTextContent, !isImageContent, !isOtherContent {
            getStreamingUrl(singleClaim)
        }
        loadAndDisplayViewCount(singleClaim)
        loadReactions(singleClaim)
        loadComments(singleClaim)

        checkFollowing(singleClaim)
        checkNotificationsDisabled(singleClaim)
    }

    func getStreamingUrl(_ singleClaim: Claim, baseStreamingUrl: String? = nil) {
        guard let uri = singleClaim.permanentUrl else {
            showError(message: "couldn't get permanentUrl")
            return
        }

        mediaLoadingIndicator.superview?.bringSubviewToFront(mediaLoadingIndicator)
        mediaLoadingIndicator.isHidden = false

        var params = [String: Any]()
        params["uri"] = uri
        if let baseStreamingUrl = baseStreamingUrl {
            params["base_streaming_url"] = baseStreamingUrl
        }

        Lbry.apiCall(
            method: Lbry.methodGet,
            params: params,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.mediaLoadingIndicator.isHidden = true
                    self.showError(error: error)
                    return
                }

                if let result = data["result"] as? [String: Any] {
                    if let streamingUrl = result["streaming_url"] as? String,
                       let sourceUrl = URL(
                           string: streamingUrl
                               .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                       )
                    {
                        self.getTranscodedUrlAndInitializePlayer(claim: singleClaim, sourceUrl: sourceUrl)
                    }
                }
            }
        )
    }

    func getTranscodedUrlAndInitializePlayer(claim: Claim, sourceUrl: URL) {
        class NoRedirectSession: NSObject, URLSessionTaskDelegate {
            func urlSession(
                _ session: URLSession,
                task: URLSessionTask,
                willPerformHTTPRedirection response: HTTPURLResponse,
                newRequest request: URLRequest,
                completionHandler: @escaping (URLRequest?) -> Void
            ) {
                completionHandler(nil)
            }
        }

        let session = URLSession(configuration: .default, delegate: NoRedirectSession(), delegateQueue: nil)
        var request = URLRequest(url: sourceUrl)
        request.httpMethod = "HEAD"
        request.setValue("https://ios.odysee.com/", forHTTPHeaderField: "Referer")
        let dataTask = session.dataTask(with: request) { result in
            guard case let .success(data) = result,
                  let response = data.response as? HTTPURLResponse,
                  response.statusCode == 200 || response.statusCode == 308
            else {
                if let releaseTime = Double(claim.value?.releaseTime ?? "0"),
                   (NSDate(timeIntervalSince1970: releaseTime) as Date) // TODO: Timezone check / conversion?
                   .timeIntervalSinceNow > -3600 /* 1 hour */
                {
                    self.showMessage(
                        message: "Failed to get media for this recently published content. Retrying in 30s"
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(30))) {
                        self.showClaimAndCheckFollowing()
                    }
                } else {
                    self.mediaLoadingIndicator.isHidden = true
                    self.showError(message: String.localized("Failed to get transcoded media location"))
                }
                return
            }

            if response.statusCode == 200 {
                DispatchQueue.main.async {
                    let headers: [String: String] = [
                        "Referer": "https://ios.odysee.com/",
                    ]
                    self.initializePlayerWithUrl(
                        singleClaim: claim,
                        sourceUrl: sourceUrl,
                        headers: headers
                    )
                }
            } else {
                guard var location = response.value(forHTTPHeaderField: "Location") else {
                    if let releaseTime = Double(claim.value?.releaseTime ?? "0"),
                       (NSDate(timeIntervalSince1970: releaseTime) as Date) // TODO: Timezone check / conversion?
                       .timeIntervalSinceNow > -3600 /* 1 hour */
                    {
                        self.showMessage(
                            message: "Failed to get media for this recently published content. Retrying in 30s"
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .seconds(30))) {
                            self.showClaimAndCheckFollowing()
                        }
                    } else {
                        self.mediaLoadingIndicator.isHidden = true
                        self.showError(message: String.localized("Failed to get transcoded media location"))
                    }
                    return
                }

                if location.hasPrefix("/"),
                   let components = URLComponents(url: sourceUrl, resolvingAgainstBaseURL: false),
                   let scheme = components.scheme,
                   let host = components.host
                {
                    location = "\(scheme)://\(host)\(location)"
                }

                if let mediaUrl = URL(
                    string: location
                        .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
                ) {
                    DispatchQueue.main.async {
                        let headers: [String: String] = [
                            "Referer": "https://ios.odysee.com/",
                        ]
                        self.initializePlayerWithUrl(
                            singleClaim: claim,
                            sourceUrl: mediaUrl,
                            headers: headers
                        )
                    }
                }
            }
        }
        dataTask.resume()
    }

    func loadRelatedContent() {
        if loadingRelated || isLivestream {
            return
        }

        guard let query = claim?.value?.title, let claimId = claim?.claimId else {
            showError(message: "couldn't get title and/or claimId")
            return
        }

        loadingRelated = true
        loadingRelatedView.isHidden = false
        Lighthouse.search(rawQuery: query, size: 16, from: 0, relatedTo: claimId, completion: { results, _ in
            guard let results, results.count != 0 else {
                // self.checkNoResults()
                DispatchQueue.main.async {
                    self.loadingRelatedView.isHidden = true
                }
                return
            }

            let urls = results.compactMap { item in
                LbryUri.tryParse(
                    url: String(format: "%@#%@", item["name"] as! String, item["claimId"] as! String),
                    requireProto: false
                )?.description
            }
            Lbry.apiCall(
                method: Lbry.Methods.resolve,
                params: .init(urls: urls)
            )
            .subscribeResult(self.handleRelatedContentResult)
        })
    }

    // The main-thread part of the related content loading flow, at the end.
    func handleRelatedContentResult(_ result: Result<ResolveResult, Error>) {
        assert(Thread.isMainThread)
        if case let .success(resolve) = result {
            // Filter out self.claim.
            relatedContent = resolve.claims.values.filter { testClaim in
                let testID = testClaim.claimId
                return testID != self.claim?.claimId
            }
            relatedContentListView.reloadData()
        }
        loadingRelated = false
        loadingRelatedView.isHidden = true
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if object as AnyObject? === AppDelegate.shared.lazyPlayer {
            if keyPath == "timeControlStatus", AppDelegate.shared.lazyPlayer?.timeControlStatus == .playing {
                checkTimeToStart()
                return
            }
        }
        if keyPath == "contentSize" {
            if object as AnyObject? === relatedContentListView {
                let contentHeight: CGFloat = relatedContentListView.contentSize.height
                relatedContentListHeightConstraint.constant = contentHeight
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == relatedContentListView {
            return isPlaylist ? playlistItems.count : relatedContent.count
        }

        if tableView == chatListView {
            return messages.count
        }

        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == relatedContentListView {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "claim_cell",
                for: indexPath
            ) as! ClaimTableViewCell
            let claim: Claim = isPlaylist ? playlistItems[indexPath.row] : relatedContent[indexPath.row]
            cell.setClaim(claim: claim)
            return cell
        }

        if tableView == chatListView {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "chat_message_cell",
                for: indexPath
            ) as! ChatMessageTableViewCell
            let comment: Comment = messages[indexPath.row]
            cell.setComment(comment: comment)
            return cell
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == relatedContentListView {
            tableView.deselectRow(at: indexPath, animated: true)
            let claim: Claim = isPlaylist ? playlistItems[indexPath.row] : relatedContent[indexPath.row]
            if claim.claimId == "placeholder" {
                return
            }

            if isPlaylist {
                // play the item and set the current index
                let index = indexPath.row
                currentPlaylistIndex = index
                loadPlaylistItemClaim(claim)
                return
            }

            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = claim

            // dismiss the current file view before displaying the new one
            AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
            AppDelegate.shared.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
        }

        if tableView == chatListView {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func closeOtherContentTapped(_ sender: UIButton) {
        if imageViewerActive {
            imageViewer.isHidden = true
            imageViewerActive = false
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func reloadTapped(_ sender: Any) {
        if let player = AppDelegate.shared.player {
            if player.rate != 0, player.error == nil {
                return
            }
        }

        if !isLivestream {
            return
        }

        loadLivestream()
    }

    @IBAction func commentAreaTapped(_ sender: Any) {
        if commentsDisabled || !commentsDisabledChecked {
            return
        }

        if commentsViewPresented {
            commentsContainerView.isHidden = false
            return
        }

        commentsVc = storyboard?.instantiateViewController(identifier: "comments_vc") as? CommentsViewController
        commentsVc.claimId = isPlaylist ? playlistItems[currentPlaylistIndex].claimId : claim?.claimId
        commentsVc.commentsDisabled = commentsDisabled
        commentsVc.comments = comments.elements
        commentsVc.currentCommentId = currentCommentId
        commentsVc.currentCommentIsReply = currentCommentIsReply
        commentsVc.authorThumbnailMap = authorThumbnailMap
        commentsVc.commentsLastPageReached = commentsLastPageReached

        commentsVc.willMove(toParent: self)
        commentsContainerView.addSubview(commentsVc.view)
        commentsVc.view.frame = CGRect(
            x: 0,
            y: 0,
            width: commentsContainerView.bounds.width,
            height: commentsContainerView.bounds.height
        )
        addChild(commentsVc)
        commentsVc.didMove(toParent: self)

        commentsContainerView.isHidden = false
        closeOtherContentButton.isHidden = true
        commentsViewPresented = true
    }

    func closeCommentsView() {
        commentsContainerView.isHidden = true
        if isTextContent || isImageContent || isOtherContent {
            closeOtherContentButton.isHidden = false
        }
        view.endEditing(true)
    }

    @IBAction func fireTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }
        react(type: Helper.reactionTypeLike)
    }

    @IBAction func slimeTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }
        react(type: Helper.reactionTypeDislike)
    }

    @IBAction func publisherTapped(_ sender: Any) {
        let publisher = isPlaylist ? currentPlaylistClaim().signingChannel : claim?.signingChannel
        if let channelClaim = publisher {
            navigationController?.popViewController(animated: false)
            let vc = AppDelegate.shared.mainController.storyboard?
                .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = channelClaim
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    func showUAView() {
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func followUnfollowTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }

        let publisher = isPlaylist ? currentPlaylistClaim().signingChannel : claim?.signingChannel
        if let channelClaim = publisher {
            subscribeOrUnsubscribe(
                claim: channelClaim,
                notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: channelClaim),
                unsubscribing: Lbryio.isFollowing(claim: channelClaim)
            )

            // check if the following tab is open to prevent a crash
            if let vc = AppDelegate.shared.mainTabViewController?.selectedViewController as? FollowingViewController {
                vc.removeFollowing(claim: channelClaim)
            }
        }
    }

    @IBAction func bellTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            // shouldn't be able to access this action if the user is not signed in, but just in case
            showUAView()
            return
        }

        let publisher = isPlaylist ? currentPlaylistClaim().signingChannel : claim?.signingChannel
        if let channelClaim = publisher {
            subscribeOrUnsubscribe(
                claim: channelClaim,
                notificationsDisabled: !Lbryio.isNotificationsDisabledForSub(claim: channelClaim),
                unsubscribing: false
            )
        }
    }

    func checkFollowing(_ singleClaim: Claim) {
        guard let channelClaim = singleClaim.signingChannel else {
            return
        }

        DispatchQueue.main.async {
            if Lbryio.isFollowing(claim: channelClaim) {
                // show unfollow and bell icons
                self.followLabel.isHidden = true
                self.bellView.isHidden = false
                self.followUnfollowIconView.image = UIImage(systemName: "heart.slash.fill")
                self.followUnfollowIconView.tintColor = UIColor.label

                self.streamerFollowLabel.isHidden = true
                self.streamerBellView.isHidden = false
                self.streamerFollowUnfollowIconView.image = UIImage(systemName: "heart.slash.fill")
                self.streamerFollowUnfollowIconView.tintColor = UIColor.label
            } else {
                self.followLabel.isHidden = false
                self.bellView.isHidden = true
                self.followUnfollowIconView.image = UIImage(systemName: "heart")
                self.followUnfollowIconView.tintColor = UIColor.systemRed

                self.streamerFollowLabel.isHidden = false
                self.streamerBellView.isHidden = true
                self.streamerFollowUnfollowIconView.image = UIImage(systemName: "heart")
                self.streamerFollowUnfollowIconView.tintColor = UIColor.systemRed
            }
        }
    }

    func checkNotificationsDisabled(_ singleClaim: Claim) {
        guard let channelClaim = singleClaim.signingChannel else {
            return
        }

        if !Lbryio.isFollowing(claim: channelClaim) {
            return
        }

        DispatchQueue.main.async {
            if Lbryio.isNotificationsDisabledForSub(claim: channelClaim) {
                self.bellIconView.image = UIImage(systemName: "bell.fill")
            } else {
                self.bellIconView.image = UIImage(systemName: "bell.slash.fill")
            }
        }
    }

    func currentPlaylistClaim() -> Claim {
        return playlistItems[currentPlaylistIndex]
    }

    // TODO: Refactor into a more reusable call to prevent code duplication
    func subscribeOrUnsubscribe(claim: Claim?, notificationsDisabled: Bool, unsubscribing: Bool) {
        if subscribeUnsubscribeInProgress {
            return
        }

        guard let actualClaim = isPlaylist ? currentPlaylistClaim() : self.claim,
              let claim,
              let claimId = claim.claimId,
              let name = claim.name,
              let permanentUrl = claim.permanentUrl
        else {
            showError(message: "couldn't get claim")
            return
        }

        subscribeUnsubscribeInProgress = true
        do {
            var options = [String: String]()
            options["claim_id"] = claimId
            if !unsubscribing {
                options["channel_name"] = name
                options["notifications_disabled"] = String(notificationsDisabled)
            }

            let subUrl: LbryUri = try LbryUri.parse(url: permanentUrl, requireProto: false)
            try Lbryio.get(
                resource: "subscription",
                action: unsubscribing ? "delete" : "new",
                options: options,
                completion: { data, error in
                    self.subscribeUnsubscribeInProgress = false
                    guard data != nil, error == nil else {
                        self.showError(error: error)
                        self.checkFollowing(actualClaim)
                        self.checkNotificationsDisabled(actualClaim)
                        return
                    }

                    if !unsubscribing {
                        Lbryio.addSubscription(
                            sub: LbrySubscription.fromClaim(
                                claim: claim,
                                notificationsDisabled: notificationsDisabled
                            ),
                            url: subUrl.description
                        )
                        if let channelName = subUrl.channelName {
                            self.addSubscription(
                                url: subUrl.description,
                                channelName: channelName,
                                isNotificationsDisabled: notificationsDisabled,
                                reloadAfter: true
                            )
                        }
                    } else {
                        Lbryio.removeSubscription(subUrl: subUrl.description)
                        if let channelName = subUrl.channelName {
                            self.removeSubscription(url: subUrl.description, channelName: channelName)
                        }
                    }

                    self.checkFollowing(actualClaim)
                    self.checkNotificationsDisabled(actualClaim)
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
            let context: NSManagedObjectContext = AppDelegate.shared.persistentContainer.viewContext
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let subToSave = Subscription(context: context)
            subToSave.url = url
            subToSave.channelName = channelName
            subToSave.isNotificationsDisabled = isNotificationsDisabled

            AppDelegate.shared.saveContext()
        }
    }

    func removeSubscription(url: String, channelName: String) {
        // remove the subscription from CoreData
        DispatchQueue.main.async {
            let context: NSManagedObjectContext = AppDelegate.shared.persistentContainer.viewContext
            let fetchRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "url == %@", url)

            do {
                let subs = try context.fetch(fetchRequest)
                for sub in subs {
                    context.delete(sub)
                }

                try context.save()
            } catch {
                // pass
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

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }

    @IBAction func dismissFileViewTapped(_ sender: Any) {
        let transition = CATransition()
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = .fromBottom
        AppDelegate.shared.mainNavigationController?.view.layer.add(transition, forKey: kCATransition)
        navigationController?.popViewController(animated: false)
    }

    var interactiveDismiss: UIPercentDrivenInteractiveTransition?
    @IBAction func dismissFileViewPanned(_ sender: Any) {
        assert(sender as? NSObject == dismissPanRecognizer)
        switch dismissPanRecognizer.state {
        case .began:
            interactiveDismiss = UIPercentDrivenInteractiveTransition()
            navigationController?.delegate = self
            navigationController?.popViewController(animated: true)
        case .changed:
            let percentComplete = dismissPanRecognizer.translation(in: view).y / view.bounds.size.height
            interactiveDismiss?.update(percentComplete)
        case .cancelled:
            interactiveDismiss?.cancel()
            interactiveDismiss = nil
        case .ended:
            if (dismissPanRecognizer?.velocity(in: view).y ?? 0) > 0 {
                interactiveDismiss?.finish()
            } else {
                interactiveDismiss?.cancel()
            }
            interactiveDismiss = nil
        case .failed,
             .recognized,
             .possible: ()
        @unknown default: ()
        }
    }

    @IBAction func jumpBackwardTapped(_ sender: Any) {
        if let player = avpc.player {
            player.seek(to: player.currentTime() - CMTime(seconds: 10, preferredTimescale: 1))
        }
    }

    @IBAction func jumpForwardTapped(_ sender: Any) {
        if let player = avpc.player {
            player.seek(to: player.currentTime() + CMTime(seconds: 10, preferredTimescale: 1))
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        if interactiveDismiss != nil {
            return FileDismissAnimationController()
        }
        return nil
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        return interactiveDismiss
    }

    @IBAction func shareActionTapped(_ sender: Any) {
        if let shareClaim = isPlaylist ? currentPlaylistClaim() : claim,
           let canonicalUrl = shareClaim.canonicalUrl,
           let url = LbryUri.tryParse(url: canonicalUrl, requireProto: false)
        {
            let items: [Any] = [URL(string: url.odyseeString) ?? url.odyseeString]
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = shareActionView
            present(vc, animated: true)
        }
    }

    @IBAction func supportActionTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }

        let vc = storyboard?.instantiateViewController(identifier: "support_vc") as! SupportViewController
        let supportClaim = isPlaylist ? currentPlaylistClaim() : claim
        vc.claim = supportClaim
        vc.modalPresentationStyle = .overCurrentContext
        present(vc, animated: true)
    }

    @IBAction func downloadActionTapped(_ sender: Any) {
        showMessage(message: String.localized("This feature is not yet available."))
    }

    @IBAction func reportActionTapped(_ sender: Any) {
        if let claimId = claim?.claimId,
           let url = URL(string: String(format: "https://odysee.com/$/report_content?claimId=%@", claimId))
        {
            let vc = SFSafariViewController(url: url)
            AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
        }
    }

    @IBAction func titleAreaTapped(_ sender: Any) {
        if descriptionArea.isHidden {
            descriptionArea.isHidden = descriptionTextView.text.isBlank
            descriptionDivider.isHidden = descriptionTextView.text.isBlank
            titleAreaIconView.image = UIImage(systemName: descriptionArea.isHidden ? "chevron.down" : "chevron.up")
        } else {
            descriptionArea.isHidden = true
            descriptionDivider.isHidden = true
            titleAreaIconView.image = UIImage(systemName: "chevron.down")
        }
    }

    @IBAction func commentAsTapped(_ sender: Any) {
        chatInputField.resignFirstResponder()

        _ = Helper.showPickerActionSheet(
            title: String.localized("Comment as"),
            origin: commentAsChannelLabel,
            rows: channels.map { $0.name ?? "" },
            initialSelection: currentCommentAsIndex,
        ) { _, selectedIndex, _ in
            let prevIndex = self.currentCommentAsIndex
            self.currentCommentAsIndex = selectedIndex
            if prevIndex != self.currentCommentAsIndex {
                self.updateCommentAsChannel(self.currentCommentAsIndex)
            }
        }
    }

    func loadComments(_ singleClaim: Claim) {
        if commentsDisabled || commentsLoading || isLivestream {
            return
        }

        guard let claimId = singleClaim.claimId else {
            showError(message: "couldn't get claimId")
            return
        }

        commentsLoading = true
        Lbry.commentApiCall(
            method: Lbry.CommentMethods.list,
            params: .init(
                claimId: claimId,
                page: commentsCurrentPage,
                pageSize: commentsPageSize,
                skipValidation: true
            )
        )
        .subscribeResult(didLoadComments)
    }

    func didLoadComments(_ result: Result<Page<Comment>, Error>) {
        assert(Thread.isMainThread)

        commentsLoading = false
        guard case let .success(page) = result else {
            // TODO: Enable after `mismatch in is_protected` fixed on members-only content
            // assertionFailure()
            return
        }

        commentsLastPageReached = page.isLastPage
        let oldCount = comments.count
        comments.append(contentsOf: page.items)
        let newComments = comments.suffix(from: oldCount)

        if !comments.isEmpty {
            resolveCommentAuthors(urls: newComments.compactMap(\.channelUrl))
        }
        checkNoComments()
        checkFeaturedComment()
    }

    func checkFeaturedComment() {
        if comments.count > 0 {
            featuredCommentLabel.text = comments[0].comment
            if let channelUrl = comments[0].channelUrl,
               let thumbUrl = authorThumbnailMap[channelUrl]
            {
                featuredCommentThumbnail.backgroundColor = UIColor.clear
                featuredCommentThumbnail.load(url: thumbUrl)
            } else {
                featuredCommentThumbnail.image = UIImage(named: "spaceman")
                featuredCommentThumbnail.backgroundColor = Helper.lightPrimaryColor
            }
        }
    }

    func resolveCommentAuthors(urls: [String]) {
        Lbry.apiCall(
            method: Lbry.Methods.resolve,
            params: .init(urls: urls)
        )
        .subscribeResult(didResolveCommentAuthors)
    }

    func didResolveCommentAuthors(_ result: Result<ResolveResult, Error>) {
        guard case let .success(resolve) = result else {
            return
        }
        Helper.addThumbURLs(claims: resolve.claims, thumbURLs: &authorThumbnailMap)
        checkFeaturedComment()
    }

    func checkNoComments() {
        noCommentsLabel.isHidden = comments.count > 0
        featuredCommentView.isHidden = comments.count == 0
    }

    func loadChannels() {
        if loadingChannels {
            return
        }

        loadingChannels = true
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
        loadingChannels = false
        guard case let .success(page) = result else {
            return
        }
        channels.removeAll(keepingCapacity: true)
        channels.append(contentsOf: page.items)
        Lbry.ownChannels = channels.filter { $0.claimId != "anonymous" }
        let index = channels.firstIndex { $0.claimId == Lbry.defaultChannelId } ?? 0
        if channels.count > index, currentCommentAsIndex == -1 {
            currentCommentAsIndex = index
            updateCommentAsChannel(index)
        }
    }

    func connectChatSocket() {
        if isLivestream,
           let claimId = claim?.claimId,
           let url = URL(string: String(format: "%@%@", Lbryio.wsCommmentBaseUrl, claimId))
        {
            chatWebsocket = WebSocket(request: URLRequest(url: url))
            chatWebsocket?.delegate = self
            chatWebsocket?.connect()
        }
    }

    func loadInitialChatMessages() {
        if initialChatLoaded {
            return
        }

        guard let claimId = claim?.claimId else {
            showError(message: "couldn't get claimId")
            return
        }

        Lbry.commentApiCall(
            method: Lbry.CommentMethods.list,
            params: .init(
                claimId: claimId,
                page: 1,
                pageSize: 75,
                skipValidation: true
            )
        )
        .subscribeResult(didLoadInitialChatMessages)
    }

    func didLoadInitialChatMessages(_ result: Result<Page<Comment>, Error>) {
        assert(Thread.isMainThread)

        initialChatLoaded = true
        guard case let .success(page) = result else {
            // TODO: Enable after `mismatch in is_protected` fixed on members-only content
            // assertionFailure()
            return
        }

        if messages.count == 0 {
            // only append initial items if the list is empty
            messages.append(contentsOf: page.items)
            messages.sort(by: { $1.timestamp ?? 0 > $0.timestamp ?? 0 })
            chatListView.reloadData()
            if messages.count >= 1 {
                let indexPath = IndexPath(row: messages.count - 1, section: 0)
                chatListView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }

    func handleChatMessageReceived(data: [String: Any]) {
        var comment = Comment()
        comment.comment = data["comment"] as? String
        comment.channelName = data["channel_name"] as? String
        messages.append(comment)

        DispatchQueue.main.async {
            self.chatListView.reloadData()
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            self.chatListView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    func didReceive(event: WebSocketEvent, client: Starscream.WebSocket) {
        switch event {
        case .connected:
            chatConnected = true
        case .disconnected:
            chatConnected = false
        case let .text(string):
            do {
                if let jsonData = string.data(using: .utf8, allowLossyConversion: false) {
                    if let response = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                        if response["type"] as? String == "delta" {
                            if let data = response["data"] as? [String: Any] {
                                if let commentData = data["comment"] as? [String: Any] {
                                    handleChatMessageReceived(data: commentData)
                                }
                            }
                        }
                    }
                }
            } catch {
                // pass
            }
        case .binary:
            break
        case .ping:
            break
        case .pong:
            break
        case .viabilityChanged:
            break
        case .reconnectSuggested:
            break
        case .cancelled:
            chatConnected = false
        case .error:
            chatConnected = false
        }
    }

    func disconnectChatSocket() {
        if chatWebsocket != nil, chatConnected {
            chatWebsocket?.disconnect()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState", completionHandler: { complete, _ in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { height, _ in
                    self.webViewHeightConstraint.constant = height as! CGFloat
                    webView.scrollView.isScrollEnabled = false

                    self.mediaView.isHidden = true
                    self.mediaViewHeight = self.mediaViewHeightConstraint.constant
                    self.mediaViewHeightConstraint.constant = 0
                    self.contentInfoLoading.isHidden = true
                    self.contentInfoView.isHidden = true
                })
            }
        })
    }

    func updateCommentAsChannel(_ index: Int) {
        guard index > 0,
              channels.count > index,
              let name = channels[index].name
        else {
            return
        }

        commentAsChannelLabel.text = String(format: String.localized("Comment as %@"), name)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == chatInputField {
            textField.resignFirstResponder()
            if postingChat {
                return false
            }

            if textField.text.isBlank {
                showError(message: String.localized("Please enter a chat message"))
                return false
            }

            if loadingChannels {
                showError(message: String.localized("Please wait while we load your channels"))
                return false
            }
            if channels.count == 0 {
                showError(message: String.localized("You need to create a channel before you can post comments"))
                return false
            }
            if currentCommentAsIndex == -1 {
                showError(message: String.localized("No channel selected. This is probably a bug."))
            }

            guard let chatText = chatInputField.text else {
                showError(message: String.localized("Please enter a chat message"))
                return false
            }

            let commentAsChannel = channels[currentCommentAsIndex]
            DispatchQueue.main.async {
                self.chatInputField.isEnabled = false
            }

            guard let channelId = commentAsChannel.claimId, let claimId = claim?.claimId else {
                showError(message: "couldn't get channelId and/or claimId")
                return false
            }

            Lbry.apiCall(
                method: Lbry.Methods.channelSign,
                params: .init(
                    channelId: channelId,
                    hexdata: Helper.strToHex(chatText)
                )
            )
            .flatMap { channelSignResult in
                Lbry.commentApiCall(
                    method: Lbry.CommentMethods.create,
                    params: .init(
                        claimId: claimId,
                        channelId: channelId,
                        signature: channelSignResult.signature,
                        signingTs: channelSignResult.signingTs,
                        comment: chatText
                    )
                )
            }
            .subscribeResult { result in
                if case let .failure(error) = result {
                    self.showError(error: error)
                } else {
                    self.chatInputField.text = ""
                }
                self.postingChat = false
                self.chatInputField.isEnabled = true
            }

            return true
        }
        return false
    }
}

class TouchInterceptingAVPlayerViewController: AVPlayerViewController {
    var playerRateView: UIView?
    var jumpBackwardView: UIView?
    var jumpForwardView: UIView?
    var hideViewsTimer: Timer?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if #available(iOS 16, *) {
        } else {
            UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseIn) {
                if let playerRateView = self.playerRateView,
                   let jumpForwardView = self.jumpForwardView,
                   let jumpBackwardView = self.jumpBackwardView
                {
                    if playerRateView.alpha == 0 {
                        playerRateView.alpha = 1
                        jumpBackwardView.alpha = 1
                        jumpForwardView.alpha = 1
                        self.hideViewsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                            UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseIn) {
                                if self.player?.rate != 0 { // Do not hide when paused
                                    playerRateView.alpha = 0
                                    jumpBackwardView.alpha = 0
                                    jumpForwardView.alpha = 0
                                }
                            }
                        }
                    } else {
                        playerRateView.alpha = 0
                        jumpBackwardView.alpha = 0
                        jumpForwardView.alpha = 0
                        self.hideViewsTimer?.invalidate()
                    }
                }
            }
        }
    }
}
