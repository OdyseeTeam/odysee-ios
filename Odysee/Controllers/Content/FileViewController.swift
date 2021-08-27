//
//  FileViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 06/11/2020.
//

import AVKit
import AVFoundation
import CoreData
import Firebase
import ImageScrollView
import OrderedCollections
import PerfectMarkdown
import PINRemoteImage
import SafariServices
import Starscream
import UIKit
import WebKit

class FileViewController: UIViewController, UIGestureRecognizerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate, WebSocketDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var titleArea: UIView!
    @IBOutlet weak var publisherArea: UIView!
    @IBOutlet weak var titleAreaIconView: UIImageView!
    @IBOutlet weak var descriptionArea: UIView!
    @IBOutlet weak var descriptionDivider: UIView!
    @IBOutlet weak var detailsScrollView: UIScrollView!
    @IBOutlet weak var livestreamChatView: UIView!
    @IBOutlet weak var livestreamOfflinePlaceholder: UIImageView!
    @IBOutlet weak var livestreamOfflineMessageView: UIView!
    @IBOutlet weak var livestreamOfflineLabel: UILabel!
    @IBOutlet weak var livestreamerArea: UIView!
    
    @IBOutlet weak var mediaView: UIView!
    @IBOutlet weak var reloadStreamView: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var viewCountLabel: UILabel!
    @IBOutlet weak var timeAgoLabel: UILabel!
    
    @IBOutlet weak var publisherActionsArea: UIView!
    @IBOutlet weak var publisherImageView: UIImageView!
    @IBOutlet weak var publisherTitleLabel: UILabel!
    @IBOutlet weak var publisherNameLabel: UILabel!
    
    @IBOutlet weak var livestreamerActionsArea: UIView!
    @IBOutlet weak var livestreamerImageView: UIImageView!
    @IBOutlet weak var livestreamerTitleLabel: UILabel!
    @IBOutlet weak var livestreamerNameLabel: UILabel!
    
    @IBOutlet weak var chatInputField: UITextField!
    @IBOutlet weak var chatListView: UITableView!
    
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var followLabel: UILabel!
    @IBOutlet weak var followUnfollowIconView: UIImageView!
    @IBOutlet weak var bellView: UIView!
    @IBOutlet weak var bellIconView: UIImageView!
    
    @IBOutlet weak var streamerAreaActionsView: UIView!
    @IBOutlet weak var streamerFollowLabel: UILabel!
    @IBOutlet weak var streamerFollowUnfollowIconView: UIImageView!
    @IBOutlet weak var streamerBellView: UIView!
    @IBOutlet weak var streamerBellIconView: UIImageView!
    
    @IBOutlet weak var relatedOrPlaylistTitle: UILabel!
    @IBOutlet weak var loadingRelatedView: UIActivityIndicatorView!
    @IBOutlet weak var relatedContentListView: UITableView!
    @IBOutlet weak var relatedContentListHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var resolvingView: UIView!
    @IBOutlet weak var resolvingImageView: UIImageView!
    @IBOutlet weak var resolvingLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var resolvingLabel: UILabel!
    @IBOutlet weak var resolvingCloseButton: UIButton!

    @IBOutlet weak var noCommentsLabel: UILabel!
    @IBOutlet weak var relatedContentArea: UIView!
    @IBOutlet weak var featuredCommentView: UIView!
    @IBOutlet weak var featuredCommentThumbnail: UIImageView!
    @IBOutlet weak var featuredCommentLabel: UILabel!
    
    @IBOutlet weak var commentExpandView: UIImageView!
    @IBOutlet weak var commentsContainerView: UIView!
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var streamerAreaHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var fireReactionCountLabel: UILabel!
    @IBOutlet weak var slimeReactionCountLabel: UILabel!
    @IBOutlet weak var fireReactionImage: UIImageView!
    @IBOutlet weak var slimeReactionImage: UIImageView!
    
    @IBOutlet weak var dismissPanRecognizer: UIPanGestureRecognizer!
    
    @IBOutlet weak var closeOtherContentButton: UIButton!
    @IBOutlet weak var contentInfoView: UIView!
    @IBOutlet weak var contentInfoLoading: UIActivityIndicatorView!
    @IBOutlet weak var contentInfoDescription: UILabel!
    @IBOutlet weak var contentInfoImage: UIImageView!
    @IBOutlet weak var contentInfoViewButton: UIButton!
    @IBOutlet weak var mediaViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var webViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewer: ImageScrollView!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var dismissFileView: UIView!

    let avpc = AVPlayerViewController()
    weak var commentsVc: CommentsViewController!
    
    var commentsDisabledChecked = false
    var commentsDisabled = false
    var commentsViewPresented = false
    var commentAsPicker: UIPickerView!
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
    var otherContentWebUrl: String? = nil
    
    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var comments = OrderedSet<Comment>()
    var authorThumbnailMap = [String: URL]()

    var numLikes = 0
    var numDislikes = 0
    var likesContent = false
    var dislikesContent = false
    var reacting = false
    var playerConnected = false
    var isLivestream = false
    var isPlaylist = false
    var isLive = false
    var isTextContent = false
    var isImageContent = false
    var isOtherContent = false
    var avpcInitialised = false
    
    var loadingChannels = false
    var postingChat = false
    var messages: [Comment] = []
    var chatConnected = false
    var initialChatLoaded = false
    var chatWebsocket: WebSocket? = nil
    
    var currentPlaylistPage = 1
    var playlistLastPageReached = false
    let playlistPageSize = 50
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.toggleMiniPlayer(hidden: true)
        appDelegate.currentFileViewController = self
        
        if claim != nil && !isPlaylist {
            checkFollowing(claim!)
            checkNotificationsDisabled(claim!)
        }
    }
    
    func checkRepost() {
        if claim != nil && claim?.repostedClaim != nil {
            claim = claim?.repostedClaim
            if (claim!.name!.starts(with: "@")) {
                // reposted channel, simply dismiss the view and show a channel view controller instead
                self.navigationController?.popViewController(animated: false)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let vc = appDelegate.mainController.storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                vc.channelClaim = claim
                appDelegate.mainNavigationController?.pushViewController(vc, animated: true)

                return
            }
            
            claim = claim?.repostedClaim
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "File", AnalyticsParameterScreenClass: "FileViewController"])
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        if claim != nil {
            showClaimAndCheckFollowing()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        appDelegate.currentClaim = isTextContent || isImageContent || isOtherContent ? nil : claim
        appDelegate.mainController.updateMiniPlayer()
        
        if (appDelegate.player != nil) {
            appDelegate.mainController.toggleMiniPlayer(hidden: false)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disconnectChatSocket()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        relatedContentListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")

        registerForKeyboardNotifications()
        
        imageViewer.setup()
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        contentInfoViewButton.layer.masksToBounds = true
        contentInfoViewButton.layer.cornerRadius = 16
        
        checkRepost()
        relatedContentListView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        featuredCommentThumbnail.rounded()
        livestreamOfflineMessageView.layer.cornerRadius = 8
        
        loadChannels()
        
        // Do any additional setup after loading the view.
        if claim == nil && claimUrl != nil {
            resolveAndDisplayClaim()
        } else if let currentClaim = claim {
            if Lbryio.isClaimBlocked(currentClaim) || (currentClaim.signingChannel != nil && Lbryio.isClaimBlocked(currentClaim.signingChannel!)) {
                displayClaimBlocked()
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        bottomLayoutConstraint.constant = kbSize.height
        streamerAreaHeightConstraint.constant = 0
        livestreamerArea.isHidden = true
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        bottomLayoutConstraint.constant = 0
        streamerAreaHeightConstraint.constant = 56
        livestreamerArea.isHidden = false
    }
    
    func showClaimAndCheckFollowing() {
        if Lbryio.isClaimBlocked(claim!) || (claim!.signingChannel != nil && Lbryio.isClaimBlocked(claim!.signingChannel!)) {
            displayClaimBlocked()
        } else if let currentClaim = claim {
            displayClaim()
            if !isPlaylist {
                loadAndDisplayViewCount(currentClaim)
                loadReactions(currentClaim)
                checkFollowing(currentClaim)
                checkNotificationsDisabled(currentClaim)
            }
            loadPlaylistOrRelated()
        }
    }
    
    func resolveAndDisplayClaim() {
        displayResolving()
        
        let url = claimUrl!.description
        claim = Lbry.cachedClaim(url: url)
        if claim != nil {
            DispatchQueue.main.async {
                self.showClaimAndCheckFollowing()
            }
            return
        }
        
        Lbry.apiCall(method: Lbry.Methods.resolve,
                     params: .init(urls: [url]))
            .subscribeResult(didResolveClaim)
    }
    
    func didResolveClaim(_ result: Result<ResolveResult, Error>) {
        guard case let .success(resolve) = result, let entry = resolve.claims.first else {
            displayNothingAtLocation()
            return
        }
        
        self.claim = entry.value
        showClaimAndCheckFollowing()
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
    
    func displayClaimBlocked() {
        DispatchQueue.main.async {
            self.resolvingView.isHidden = false
            self.resolvingLoadingIndicator.isHidden = true
            self.resolvingImageView.image = UIImage.init(named: "spaceman_sad")
            self.resolvingLabel.text = String.localized("In response to a complaint we received under the US Digital Millennium Copyright Act, we have blocked access to this content from our applications.")
            self.resolvingCloseButton.isHidden = false
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == dismissPanRecognizer {
            let translation = dismissPanRecognizer.translation(in: self.view)
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
    
    func loadLivestream() {
        if !isLivestream {
            return
        }
        
        loadInitialChatMessages()
        
        let url = URL(string: String(format: "https://api.live.odysee.com/v1/odysee/live/%@", claim!.signingChannel!.claimId!))
        let session = URLSession.shared
        var req = URLRequest(url: url!)
        req.httpMethod = "GET"
        
        let task = session.dataTask(with: req, completionHandler: { data, response, error in
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
                        let headers: Dictionary<String, String> = [
                            "Referer": "https://bitwave.tv"
                        ]
                        DispatchQueue.main.async {
                            self.initializePlayerWithUrl(singleClaim: self.claim!, sourceUrl: streamUrl, headers: headers, forceInit: true)
                        }
                    }
                }
            } catch {
                self.showError(message: "The livestream could not be loaded right now. Please try again later.")
                self.isLive = false
            }
        });
        task.resume();
    }
    
    func displayLivestreamOffline() {
        DispatchQueue.main.async {
            self.livestreamOfflinePlaceholder.isHidden = false
            self.livestreamOfflineMessageView.isHidden = false
            self.livestreamOfflineLabel.text = String(format: String.localized("%@ isn't live right now. Check back later to watch the stream."), self.claim!.signingChannel!.name!)
        }
    }
    
    func checkCommentsDisabled(commentsDisabled: Bool, currentClaim: Claim) {
        DispatchQueue.main.async {
            self.commentsDisabled = commentsDisabled
            self.commentExpandView.isHidden = commentsDisabled
            self.noCommentsLabel.isHidden = !commentsDisabled
            self.noCommentsLabel.text = String.localized(commentsDisabled ? "Comments are disabled." : "There are no comments to display at this time. Be the first to post a comment!")
            self.featuredCommentView.isHidden = commentsDisabled
            
            if !self.commentsDisabled {
                self.loadComments(currentClaim)
            }
        }
    }
    
    func displaySingleClaim(_ singleClaim: Claim) {
        commentsDisabledChecked = false
        resolvingView.isHidden = true
        descriptionArea.isHidden = true
        descriptionDivider.isHidden = true
        
        var contentType: String? = nil
        if let mediaType = claim?.value?.source?.mediaType {
            isTextContent = mediaType.starts(with: "text/")
            isImageContent = mediaType.starts(with: "image/")
            isOtherContent = !isTextContent && !isImageContent && !mediaType.starts(with: "video") && !mediaType.starts(with: "audio")
            contentType = mediaType
        }
        
        otherContentWebUrl = nil
        closeOtherContentButton.isHidden = true
        contentInfoView.isHidden = true
        mediaView.isHidden = false
        mediaViewHeightConstraint.constant = 240
        
        if isTextContent || isImageContent || isOtherContent {
            dismissFileView.isHidden = true
            contentInfoView.isHidden = false
            closeOtherContentButton.isHidden = false
            contentInfoViewButton.isHidden = true
            contentInfoImage.image = nil
            
            let contentUrl = buildOtherContentUrl(singleClaim)
            if isTextContent {
                webView.isHidden = false
                contentInfoDescription.text = String.localized("Loading content...")
                contentInfoLoading.isHidden = false
                loadTextContent(url: contentUrl!, contentType: contentType)
                logFileView(url: singleClaim.permanentUrl!, timeToStart: 0)
            } else if isImageContent {
                var thumbnailDisplayUrl = contentUrl
                if !(singleClaim.value?.thumbnail?.url ?? "").isBlank {
                    thumbnailDisplayUrl = URL(string: singleClaim.value!.thumbnail!.url!)!
                }
                contentInfoImage.pin_setImage(from: thumbnailDisplayUrl)
                PINRemoteImageManager.shared().downloadImage(with: contentUrl!) { result in
                    guard let image = result.image else { return }
                    Thread.performOnMain {
                        self.imageViewer.display(image: image)
                    }
                }
                contentInfoViewButton.isHidden = false
                logFileView(url: singleClaim.permanentUrl!, timeToStart: 0)
            } else if let url = LbryUri.tryParse(url: singleClaim.permanentUrl!, requireProto: false) {
                contentInfoLoading.isHidden = true
                let messageString = NSMutableAttributedString(string: String(format: String.localized("This content cannot be viewed in the Odysee app at this time. Please open %@ in your web browser."), url.odyseeString))
                let range = messageString.mutableString.range(of: url.odyseeString)
                if range.location != NSNotFound {
                    messageString.addAttribute(.link, value: url.odyseeString, range: range)
                }
                contentInfoDescription.attributedText = messageString
                otherContentWebUrl = url.odyseeString
            }
        } else if !avpcInitialised {
            avpc.allowsPictureInPicturePlayback = true
            avpc.updatesNowPlayingInfoCenter = false
            addChild(avpc)
            
            avpc.view.frame = mediaView.bounds
            mediaView.addSubview(avpc.view)
            avpc.didMove(toParent: self)
            
            avpcInitialised = true
        }
        
        if let publisher = claim?.signingChannel {
            Lbryio.areCommentsEnabled(channelId: publisher.claimId!, channelName: publisher.name!, completion: { enabled in
                self.commentsDisabledChecked = true
                self.checkCommentsDisabled(commentsDisabled: !enabled, currentClaim: singleClaim)
            })
        }
        
        titleLabel.text = singleClaim.value?.title
        
        let releaseTime: Double = Double(singleClaim.value?.releaseTime ?? "0")!
        let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?
        
        timeAgoLabel.text = Helper.fullRelativeDateFormatter.localizedString(for: date, relativeTo: Date())
        
        // publisher
        var thumbnailUrl: URL? = nil
        publisherImageView.rounded()
        livestreamerImageView.rounded()
        if (singleClaim.signingChannel != nil) {
            if !isLivestream {
                publisherTitleLabel.text = singleClaim.signingChannel?.value?.title
                publisherNameLabel.text = singleClaim.signingChannel?.name
            } else {
                livestreamerTitleLabel.text = singleClaim.signingChannel?.value?.title
                livestreamerNameLabel.text = singleClaim.signingChannel?.name
                
            }
            if (singleClaim.signingChannel?.value != nil && singleClaim.signingChannel?.value?.thumbnail != nil) {
                thumbnailUrl = URL(string: (singleClaim.signingChannel!.value!.thumbnail!.url!))!
            }
        } else {
            publisherTitleLabel.text = String.localized("Anonymous")
            publisherActionsArea.isHidden = true
        }
        
        if thumbnailUrl != nil {
            if !isLivestream {
                publisherImageView.load(url: thumbnailUrl!)
            } else {
                livestreamerImageView.load(url: thumbnailUrl!)
            }
        } else {
            if !isLivestream {
                publisherImageView.image = UIImage.init(named: "spaceman")
                publisherImageView.backgroundColor = Helper.lightPrimaryColor
            } else {
                livestreamerImageView.image = UIImage.init(named: "spaceman")
                livestreamerImageView.backgroundColor = Helper.lightPrimaryColor
            }
        }
        
        if (singleClaim.value?.description ?? "").isBlank {
            descriptionArea.isHidden = true
            descriptionDivider.isHidden = true
            titleAreaIconView.isHidden = true
        } else {
            // details
            descriptionLabel.text = claim?.value?.description
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
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.present(vc, animated: true, completion: nil)
        }
    }
    
    func buildOtherContentUrl(_ claim: Claim) -> URL? {
        return URL(string: String(format: "https://cdn.lbryplayer.xyz/api/v4/streams/free/%@/%@/%@",
                                  claim.name!, claim.claimId!, String((claim.value!.source!.sdHash!.prefix(6)))))
    }
    
    func loadTextContent(url: URL, contentType: String?) {
        DispatchQueue.global().async {
            do {
                let contents = try String(contentsOf: url)
                if contentType == "text/md" || contentType == "text/markdown" || contentType == "text/x-markdown" {
                    guard let html = contents.markdownToHTML else {
                        self.handleContentLoadError(String(format: String.localized("Could not load URL %@"), url.absoluteString))
                        return
                    }
                    
                    let mdHtml = self.buildMarkdownHTML(html)
                    self.loadWebViewContent(mdHtml)
                } else if contentType == "text/html" {
                    self.loadWebViewContent(contents)
                } else {
                    self.loadWebViewContent(self.buildPlainTextHTML(contents))
                }
            } catch {
                self.handleContentLoadError(String(format: String.localized("Could not load URL %@"), url.absoluteString))
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
      body { font-family: sans-serif; margin: 16px; }
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
      body { font-family: sans-serif; margin: 16px; }
      img { width: 100%; }
      pre { white-space: pre-wrap; word-wrap: break-word; }
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
        isPlaylist = .collection == claim?.valueType
        isLivestream = !isPlaylist && claim?.value?.source == nil
        detailsScrollView.isHidden = isLivestream
        livestreamChatView.isHidden = !isLivestream
        reloadStreamView.isHidden = !isLivestream
        relatedOrPlaylistTitle.text = isPlaylist ? claim?.value?.title : String.localized("Related Content")
        
        displayRelatedPlaceholders()
        
        if !isPlaylist {
            // for a playlist, we need to do a claim_search for the list of claim IDs first, and then display the first result
            connectChatSocket()
            displaySingleClaim(claim!)
            if isLivestream {
                loadLivestream()
            } else if !isTextContent && !isImageContent && !isOtherContent {
                initializePlayerWithUrl(singleClaim: self.claim!, sourceUrl: getStreamingUrl(claim: claim!))
            }
        }
    }
    
    func initializePlayerWithUrl(singleClaim: Claim, sourceUrl: URL, headers: Dictionary<String, String> = [:], forceInit: Bool = false) {
        assert(Thread.isMainThread)
        
        livestreamOfflinePlaceholder.isHidden = true
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        avpc.delegate = appDelegate.mainController
        if (!forceInit && appDelegate.player != nil && appDelegate.currentClaim != nil && appDelegate.currentClaim?.claimId == singleClaim.claimId) {
            avpc.player = appDelegate.lazyPlayer
            playerConnected = true
            return
        }
        
        appDelegate.currentClaim = singleClaim
        appDelegate.player?.pause()
        
        appDelegate.playerObserverAdded = false
        
        let asset = AVURLAsset(url: sourceUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        appDelegate.player = AVPlayer(playerItem: playerItem)

        appDelegate.registerPlayerObserver()
        avpc.player = appDelegate.lazyPlayer
        playerConnected = true
        playRequestTime = Int64(Date().timeIntervalSince1970 * 1000.0)
        
        avpc.player!.play()
    }
    
    func displayRelatedPlaceholders() {
        if isLivestream {
            return
        }
        
        relatedContent = []
        for _ in 1...15 {
            let placeholder = Claim()
            placeholder.claimId = "placeholder"
            relatedContent.append(placeholder)
        }
        relatedContentListView.reloadData()
    }
    
    func checkTimeToStart() {
        if (fileViewLogged || loggingInProgress) {
            return
        }
        
        let timeToStartMs = Int64(Date().timeIntervalSince1970 * 1000.0) - playRequestTime
        let timeToStartSeconds = Int64(Double(timeToStartMs) / 1000.0)
        let url = isPlaylist ? currentPlaylistClaim().permanentUrl! : (claim != nil ? claim!.permanentUrl! : nil)
        if let claimUrl = url {
            Analytics.logEvent("play", parameters: [
                "url": claimUrl,
                "time_to_start_ms": timeToStartMs,
                "time_to_start_seconds": timeToStartSeconds
            ])
         
            logFileView(url: claimUrl, timeToStart: timeToStartMs)
        }
    }
    
    func disconnectPlayer() {
        avpc.player = nil
        playerConnected = false
    }
    
    func connectPlayer() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.player != nil {
            avpc.player = appDelegate.lazyPlayer
        }
        playerConnected = true
    }
    
    func logFileView(url: String, timeToStart: Int64) {
        if (loggingInProgress) {
            return
        }
        
        loggingInProgress = true
        
        var options = Dictionary<String, String>()
        options["uri"] = url
        options["claim_id"] = claim?.claimId!
        options["outpoint"] = String(format: "%@:%d", claim!.txid!, claim!.nout!)
        if (timeToStart > 0) {
            options["time_to_start"] = String(timeToStart)
        }
        
        do {
            try Lbryio.post(resource: "file", action: "view", options: options, completion: { data, error in
                // no need to check for errors here
                self.loggingInProgress = false
                self.fileViewLogged = true
                self.claimDailyView()
            })
        } catch {
            // pass
        }
    }
    
    func claimDailyView() -> Void {
        let defaults = UserDefaults.standard
        let receiveAddress = defaults.string(forKey: Helper.keyReceiveAddress)
        if ((receiveAddress ?? "").isBlank) {
            Lbry.apiCall(
                method: Lbry.Methods.addressUnused,
                params: .init()
            )
            .subscribeResult { result in
                guard case let .success(newAddress) = result else {
                    return
                }
                
                UserDefaults.standard.set(newAddress, forKey: Helper.keyReceiveAddress)
                Lbryio.claimReward(type: "daily_view", walletAddress: newAddress, completion: { data, error in })
            }
            
            return
        }
        
        Lbryio.claimReward(type: "daily_view", walletAddress: receiveAddress!, completion: { data, error in
            // don't do anything here
        })
    }
    
    func getStreamingUrl(claim: Claim) -> URL {
        let claimName: String = claim.name!
        let claimId: String = claim.claimId!
        let str = String(format: "https://cdn.lbryplayer.xyz/content/claims/%@/%@/stream", claimName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!, claimId)
        return URL(string: str)!
    }
    
    func loadAndDisplayViewCount(_ singleClaim: Claim) {
        if isLivestream {
            return
        }
        
        do {
            try Lbryio.get(resource: "file", action: "view_count", options: ["claim_id": singleClaim.claimId!], completion: { data, error in
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
                    self.viewCountLabel.text = String(format: viewCount == 1 ? String.localized("%@ view") : String.localized("%@ views"), formatter.string(for: viewCount)!)
                }
            })
        } catch {
            // pass
        }
    }
    
    func loadReactions(_ singleClaim: Claim) {
        if isLivestream {
            return
        }
        
        do {
            let claimId = singleClaim.claimId!
            let options: Dictionary<String, String> = ["claim_ids": claimId]
            try Lbryio.post(resource: "reaction", action: "list", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }
                DispatchQueue.main.async {
                    //let viewCount = (data as! NSArray)[0] as! Int
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
        do {
            var remove = false
            let claimId = isPlaylist ? currentPlaylistClaim().claimId! : claim!.claimId!
            var options: Dictionary<String, String> = [
                "claim_ids": claimId,
                "type": type,
                "clear_types": type == Helper.reactionTypeLike ? Helper.reactionTypeDislike : Helper.reactionTypeLike
            ]
            if (type == Helper.reactionTypeLike && likesContent) || (type == Helper.reactionTypeDislike && dislikesContent) {
                remove = true
                options["remove"] = "true"
            }
            try Lbryio.post(resource: "reaction", action: "react", options: options, completion: { data, error in
                guard let _ = data, error == nil else {
                    self.showError(error: error)
                    return
                }
                
                if type == Helper.reactionTypeLike {
                    self.likesContent = !remove
                    self.numLikes += (remove ? -1 : 1)
                    if !remove && self.dislikesContent {
                        self.numDislikes -= 1;
                        self.dislikesContent = false
                    }
                }
                if type == Helper.reactionTypeDislike {
                    self.dislikesContent = !remove
                    self.numDislikes += (remove ? -1 : 1)
                    if !remove && self.likesContent {
                        self.numLikes -= 1
                        self.likesContent = false
                    }
                }
                
                self.displayReactionCounts()
                self.checkMyReactions()
                self.reacting = false
            })
        } catch let error {
            showError(error: error)
            self.reacting = false
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
        if (loadingPlaylist || isLivestream) {
            return
        }
        
        if currentPlaylistPage == 1 && playlistItems.count == 0 {
            displayResolving()
        }
        
        loadingRelated = true
        loadingRelatedView.isHidden = false
    
        if let playlistClaims = claim?.value!.claims {
            Lbry.apiCall(method: Lbry.Methods.claimSearch,
                         params: .init(
                            claimType: [.stream],
                            page: currentPlaylistPage,
                            pageSize: playlistPageSize,
                            claimIds: playlistClaims,
                            orderBy: Helper.sortByItemValues[1]))
                .subscribeResult(didLoadPlaylistClaims)
        }
    }
    
    func didLoadPlaylistClaims(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        result.showErrorIfPresent()
        if case let .success(payload) = result {
            let oldCount = playlistItems.count
            playlistItems.append(contentsOf: payload.items.filter{ !playlistItems.contains($0) })
            if playlistItems.count != oldCount {
                relatedContentListView.reloadData()
            }
            playlistLastPageReached = payload.isLastPage
        }
        loadingRelatedView.isHidden = true
        loadingRelated = false
        
        if currentPlaylistPage == 1 {
            // first set of results, display the first claim
            let singleClaim = playlistItems[0]
            loadPlaylistItemClaim(singleClaim)
        }
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
        
        if !isTextContent && !isImageContent && !isOtherContent {
            initializePlayerWithUrl(singleClaim: singleClaim, sourceUrl: getStreamingUrl(claim: singleClaim))
        }
        loadAndDisplayViewCount(singleClaim)
        loadReactions(singleClaim)
        loadComments(singleClaim)
        
        checkFollowing(singleClaim)
        checkNotificationsDisabled(singleClaim)
    }
    
    func loadRelatedContent() {
        if (loadingRelated || isLivestream) {
            return
        }
        
        loadingRelated = true
        loadingRelatedView.isHidden = false
        let query = claim?.value?.title!
        Lighthouse.search(rawQuery: query!, size: 16, from: 0, relatedTo: claim!.claimId!, completion: { results, error in
            if (results == nil || results!.count == 0) {
                //self.checkNoResults()
                DispatchQueue.main.async {
                    self.loadingRelatedView.isHidden = true
                }
                return
            }
            
            let urls = results!.compactMap { item in
                LbryUri.tryParse(url: String(format: "%@#%@", item["name"] as! String, item["claimId"] as! String), requireProto: false)?.description
            }
            Lbry.apiCall(method: Lbry.Methods.resolve,
                         params: .init(urls: urls))
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if object as AnyObject? === appDelegate.player {
            if keyPath == "timeControlStatus" && appDelegate.player!.timeControlStatus == .playing {
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
            let claim: Claim = isPlaylist ? playlistItems[indexPath.row] : relatedContent[indexPath.row]
            cell.setClaim(claim: claim)
            return cell
        }
        
        if tableView == chatListView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "chat_message_cell", for: indexPath) as! ChatMessageTableViewCell
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
                // play the itema nd set the current index
                let index = indexPath.row
                currentPlaylistIndex = index
                loadPlaylistItemClaim(claim)
                return
            }
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = claim
            
            // dismiss the current file view before displaying the new one
            appDelegate.mainNavigationController?.popViewController(animated: false)
            appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
        
        if tableView == chatListView {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    @IBAction func closeTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func closeOtherContentTapped(_sender: UIButton) {
        if imageViewerActive {
            imageViewer.isHidden = true
            imageViewerActive = false
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func reloadTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let player = appDelegate.player {
            if player.rate != 0 && player.error == nil {
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
        commentsVc.claimId = isPlaylist ? playlistItems[currentPlaylistIndex].claimId! : claim?.claimId!
        commentsVc.commentsDisabled = commentsDisabled
        commentsVc.comments = comments.elements
        commentsVc.authorThumbnailMap = authorThumbnailMap
        
        commentsVc.willMove(toParent: self)
        commentsContainerView.addSubview(commentsVc.view)
        commentsVc.view.frame = CGRect(x: 0, y: 0, width: commentsContainerView.bounds.width, height: commentsContainerView.bounds.height)
        self.addChild(commentsVc)
        commentsVc.didMove(toParent: self)
        
        commentsContainerView.isHidden = false
        commentsViewPresented = true
    }
    
    func closeCommentsView() {
        commentsContainerView.isHidden = true
        self.view.endEditing(true)
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
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = appDelegate.mainController.storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = channelClaim
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func showUAView() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func followUnfollowTapped(_ sender: Any) {
        if (!Lbryio.isSignedIn()) {
            showUAView()
            return
        }
        
        let publisher = isPlaylist ? currentPlaylistClaim().signingChannel : claim?.signingChannel
        if let channelClaim = publisher {
            subscribeOrUnsubscribe(claim: channelClaim, notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: channelClaim), unsubscribing: Lbryio.isFollowing(claim: channelClaim))
        }
    }
    
    @IBAction func bellTapped(_ sender: Any) {
        if (!Lbryio.isSignedIn()) {
            // shouldn't be able to access this action if the user is not signed in, but just in case
            showUAView()
            return
        }
        
        let publisher = isPlaylist ? currentPlaylistClaim().signingChannel : claim?.signingChannel
        if let channelClaim = publisher {
            subscribeOrUnsubscribe(claim: channelClaim, notificationsDisabled: !Lbryio.isNotificationsDisabledForSub(claim: channelClaim), unsubscribing: false)
        }
    }
    
    func checkFollowing(_ singleClaim: Claim) {
        if singleClaim.signingChannel == nil {
            return
        }
        
        let channelClaim = singleClaim.signingChannel!
        DispatchQueue.main.async {
            if (Lbryio.isFollowing(claim: channelClaim)) {
                // show unfollow and bell icons
                self.followLabel.isHidden = true
                self.bellView.isHidden = false
                self.followUnfollowIconView.image = UIImage.init(systemName: "heart.slash.fill")
                self.followUnfollowIconView.tintColor = UIColor.label
                
                self.streamerFollowLabel.isHidden = true
                self.streamerBellView.isHidden = false
                self.streamerFollowUnfollowIconView.image = UIImage.init(systemName: "heart.slash.fill")
                self.streamerFollowUnfollowIconView.tintColor = UIColor.label
            } else {
                self.followLabel.isHidden = false
                self.bellView.isHidden = true
                self.followUnfollowIconView.image = UIImage.init(systemName: "heart")
                self.followUnfollowIconView.tintColor = UIColor.systemRed
                
                self.streamerFollowLabel.isHidden = false
                self.streamerBellView.isHidden = true
                self.streamerFollowUnfollowIconView.image = UIImage.init(systemName: "heart")
                self.streamerFollowUnfollowIconView.tintColor = UIColor.systemRed
            }
        }
    }
    
    func checkNotificationsDisabled(_ singleClaim: Claim) {
        if singleClaim.signingChannel == nil {
            return
        }
        
        let channelClaim = singleClaim.signingChannel!
        if (!Lbryio.isFollowing(claim: channelClaim)) {
            return
        }
        
        DispatchQueue.main.async {
            if (Lbryio.isNotificationsDisabledForSub(claim: channelClaim)) {
                self.bellIconView.image = UIImage.init(systemName: "bell.fill")
            } else {
                self.bellIconView.image = UIImage.init(systemName: "bell.slash.fill")
            }
        }
    }
    
    func currentPlaylistClaim() -> Claim {
        return playlistItems[currentPlaylistIndex]
    }
    
    // TODO: Refactor into a more reusable call to prevent code duplication
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
            try Lbryio.get(resource: "subscription", action: unsubscribing ? "delete" : "new", options: options, completion: { data, error in
                self.subscribeUnsubscribeInProgress = false
                guard let _ = data, error == nil else {
                    self.showError(error: error)
                    self.checkFollowing(self.isPlaylist ? self.currentPlaylistClaim() : self.claim!)
                    self.checkNotificationsDisabled(self.isPlaylist ? self.currentPlaylistClaim() : self.claim!)
                    return
                }

                if (!unsubscribing) {
                    Lbryio.addSubscription(sub: LbrySubscription.fromClaim(claim: claim!, notificationsDisabled: notificationsDisabled), url: subUrl.description)
                    self.addSubscription(url: subUrl.description, channelName: subUrl.channelName!, isNotificationsDisabled: notificationsDisabled, reloadAfter: true)
                } else {
                    Lbryio.removeSubscription(subUrl: subUrl.description)
                    self.removeSubscription(url: subUrl.description, channelName: subUrl.channelName!)
                }
                
                self.checkFollowing(self.isPlaylist ? self.currentPlaylistClaim() : self.claim!)
                self.checkNotificationsDisabled(self.isPlaylist ? self.currentPlaylistClaim() : self.claim!)
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
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    func showError(message: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    
    func showMessage(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showMessage(message: message)
    }
    
    @IBAction func dismissFileViewTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let transition = CATransition()
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = .fromBottom
        appDelegate.mainNavigationController?.view.layer.add(transition, forKey: kCATransition)
        self.navigationController?.popViewController(animated: false)
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
            let percentComplete = dismissPanRecognizer.translation(in: self.view).y / self.view.bounds.size.height
            interactiveDismiss?.update(percentComplete)
        case .cancelled:
            interactiveDismiss?.cancel()
            interactiveDismiss = nil
        case .ended:
            if (dismissPanRecognizer?.velocity(in: self.view).y ?? 0) > 0 {
                interactiveDismiss?.finish()
            } else {
                interactiveDismiss?.cancel()
            }
            interactiveDismiss = nil
        case .failed, .recognized, .possible: ()
        @unknown default: ()
        }
    }

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if interactiveDismiss != nil {
            return FileDismissAnimationController()
        }
        return nil
    }

    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactiveDismiss
    }

    @IBAction func shareActionTapped(_ sender: Any) {
        let shareClaim = isPlaylist ? currentPlaylistClaim() : self.claim!
        let url = LbryUri.tryParse(url: shareClaim.canonicalUrl!, requireProto: false)
        if (url != nil) {
            let items = [url!.odyseeString]
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            present(vc, animated: true)
        }
    }
    
    @IBAction func supportActionTapped(_ sender: Any) {
        if !Lbryio.isSignedIn() {
            showUAView()
            return
        }
        
        let vc = storyboard?.instantiateViewController(identifier: "support_vc") as! SupportViewController
        let supportClaim = isPlaylist ? currentPlaylistClaim() : self.claim!
        vc.claim = supportClaim
        vc.modalPresentationStyle = .overCurrentContext
        present(vc, animated: true)
    }
    
    @IBAction func downloadActionTapped(_ sender: Any) {
        showMessage(message: String.localized("This feature is not yet available."))
    }
    
    @IBAction func reportActionTapped(_ sender: Any) {
        if let url = URL(string: String(format: "https://lbry.com/dmca/%@", claim!.claimId!)) {
            let vc = SFSafariViewController(url: url)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func titleAreaTapped(_ sender: Any) {
        if descriptionArea.isHidden {
            descriptionArea.isHidden = (descriptionLabel.text ?? "").isBlank
            descriptionDivider.isHidden = (descriptionLabel.text ?? "").isBlank
            titleAreaIconView.image = UIImage.init(systemName: descriptionArea.isHidden ? "chevron.down" : "chevron.up")
        } else {
            descriptionArea.isHidden = true
            descriptionDivider.isHidden = true
            titleAreaIconView.image = UIImage.init(systemName: "chevron.down")
        }
    }
    
    func loadComments(_ singleClaim: Claim) {
        if commentsDisabled || commentsLoading || isLivestream {
            return
        }
        
        commentsLoading = true
        Lbry.apiCall(method: Lbry.Methods.commentList,
                     params: .init(
                        claimId: singleClaim.claimId!,
                        page: commentsCurrentPage,
                        pageSize: commentsPageSize,
                        skipValidation: true))
            .subscribeResult(didLoadComments)
    }
    
    func didLoadComments(_ result: Result<Page<Comment>, Error>) {
        assert(Thread.isMainThread)

        commentsLoading = false
        guard case let .success(page) = result else {
            assertionFailure()
            return
        }
        
        commentsLastPageReached = page.items.count < page.pageSize
        let oldCount = comments.count
        comments.append(contentsOf: page.items)
        let newComments = comments.suffix(from: oldCount)
        
        if !comments.isEmpty {
            resolveCommentAuthors(urls: newComments.map { $0.channelUrl! })
        }
        checkNoComments()
        checkFeaturedComment()
    }

    func checkFeaturedComment() {
        if self.comments.count > 0 {
            self.featuredCommentLabel.text = self.comments[0].comment
            if let thumbUrl = self.authorThumbnailMap[self.comments[0].channelUrl!] {
                self.featuredCommentThumbnail.backgroundColor = UIColor.clear
                self.featuredCommentThumbnail.load(url: thumbUrl)
            } else {
                self.featuredCommentThumbnail.image = UIImage.init(named: "spaceman")
                self.featuredCommentThumbnail.backgroundColor = Helper.lightPrimaryColor
            }
        }
    }
    
    func resolveCommentAuthors(urls: [String]) {
        Lbry.apiCall(method: Lbry.Methods.resolve,
                     params: .init(urls: urls))
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
        self.noCommentsLabel.isHidden = self.comments.count > 0
        self.featuredCommentView.isHidden = self.comments.count == 0
    }
    
    func loadChannels() {
        if loadingChannels {
            return
        }
        
        loadingChannels = true
        Lbry.apiCall(method: Lbry.Methods.claimList,
                     params: .init(
                        claimType: [.channel],
                        page: 1,
                        pageSize: 999,
                        resolve: true))
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
    }

    func connectChatSocket() {
        if isLivestream {
            let url = URL(string: String(format: "%@%@", Lbryio.wsCommmentBaseUrl, claim!.claimId!))
            chatWebsocket = WebSocket(request: URLRequest(url: url!))
            chatWebsocket!.delegate = self
            chatWebsocket?.connect()
        }
    }
    
    func loadInitialChatMessages() {
        if initialChatLoaded {
            return
        }
        
        Lbry.apiCall(method: Lbry.Methods.commentList,
                     params: .init(
                        claimId: claim!.claimId!,
                        page: 1,
                        pageSize: 75,
                        skipValidation: true))
            .subscribeResult(didLoadInitialChatMessages)
    }
    
    func didLoadInitialChatMessages(_ result: Result<Page<Comment>, Error>) {
        assert(Thread.isMainThread)

        initialChatLoaded = true
        guard case let .success(page) = result else {
            assertionFailure()
            return
        }
        
        if messages.count == 0 {
            // only append initial items if the list is empty
            messages.append(contentsOf: page.items)
            messages.sort(by: { $1.timestamp ?? 0 > $0.timestamp ?? 0 })
            chatListView.reloadData()
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            chatListView.scrollToRow(at: indexPath, at: .bottom, animated: true)
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
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch (event) {
        case .connected(_):
            chatConnected = true
            break
        case .disconnected(_, _):
            chatConnected = false
            break
        case .text(let string):
            do {
                if let jsonData = string.data(using: .utf8, allowLossyConversion: false) {
                    if let response = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                        if response["type"] as? String == "delta" {
                            if let data = response["data"] as? [String: Any] {
                                if let commentData = data["comment"] as? [String: Any] {
                                    self.handleChatMessageReceived(data: commentData)
                                }
                            }
                        }
                    }
                }
            } catch {
                // pass
            }
            break
        case .binary(_):
            break
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            chatConnected = false
            break
        case .error(_):
            chatConnected = false
            break
        }
    }
    
    func disconnectChatSocket() {
        if chatWebsocket != nil && chatConnected {
            chatWebsocket?.disconnect()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, error) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
                    self.webViewHeightConstraint.constant = height as! CGFloat
                    webView.scrollView.isScrollEnabled = false
                    
                    self.mediaView.isHidden = true
                    self.mediaViewHeightConstraint.constant = 0
                    self.contentInfoLoading.isHidden = true
                    self.contentInfoView.isHidden = true
                })
            }
        })
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == chatInputField {
            textField.resignFirstResponder()
            if postingChat {
                return false
            }
            
            let text = textField.text
            if (text ?? "").isBlank {
                showError(message: String.localized("Please enter a chat message"))
                return false
            }
            
            if loadingChannels {
                showError(message: String.localized("Please wait while we load your channels"))
                return false
            }
            if channels.count == 0 {
                showError(message: String.localized("Please create a channel before sending chat messages"))
                return false
            }
            
            let commentAsChannel = channels[0]
            DispatchQueue.main.async {
                self.chatInputField.isEnabled = false
            }
            
            let params: Dictionary<String, Any> = [
                "claim_id": claim!.claimId!,
                "channel_id": commentAsChannel.claimId!,
                "comment": chatInputField.text!
            ]
            Lbry.apiCall(method: Lbry.methodCommentCreate, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
                guard let _ = data, error == nil else {
                    self.showError(error: error)
                    self.postingChat = false
                    DispatchQueue.main.async {
                        self.chatInputField.isEnabled = true
                    }
                    return
                }
                
                // comment post successful
                self.postingChat = false
                DispatchQueue.main.async {
                    self.chatInputField.text = ""
                    self.chatInputField.isEnabled = true
                }
            })
            
            return true
        }
        return false
    }
}
