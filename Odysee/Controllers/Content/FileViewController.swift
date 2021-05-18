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
import SafariServices
import Starscream
import UIKit

class FileViewController: UIViewController, UIGestureRecognizerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UITextFieldDelegate, WebSocketDelegate {
    
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

    var avpc: AVPlayerViewController!
    
    var commentsDisabled = false
    var commentsViewPresented = false  
    var commentAsPicker: UIPickerView!
    var claim: Claim?
    var claimUrl: LbryUri?
    var subscribeUnsubscribeInProgress = false
    var relatedContent: [Claim] = []
    var channels: [Claim] = []
    var loadingRelated = false
    var fileViewLogged = false
    var loggingInProgress = false
    var playRequestTime: Int64 = 0
    var playerObserverAdded: Bool = false
    
    var commentsPageSize: Int = 50
    var commentsCurrentPage: Int = 1
    var commentsLastPageReached: Bool = false
    var commentsLoading: Bool = false
    var comments: [Comment] = []
    var authorThumbnailMap: Dictionary<String, String> = [:]
    
    var numLikes = 0
    var numDislikes = 0
    var likesContent = false
    var dislikesContent = false
    var reacting = false
    var playerConnected = false
    var isLivestream = false
    var isLive = false
    
    var loadingChannels = false
    var postingChat = false
    var messages: [Comment] = []
    var chatConnected = false
    var chatWebsocket: WebSocket? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.toggleMiniPlayer(hidden: true)
        appDelegate.currentFileViewController = self
        
        if claim != nil {
            checkFollowing()
            checkNotificationsDisabled()
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
        appDelegate.currentClaim = claim
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
        registerForKeyboardNotifications()
        
        checkRepost()
        relatedContentListView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        featuredCommentThumbnail.rounded()
        livestreamOfflineMessageView.layer.cornerRadius = 8
        
        loadChannels()
        
        // Do any additional setup after loading the view.
        if claim == nil && claimUrl != nil {
            resolveAndDisplayClaim()
        } else if claim != nil {
            if Lbryio.isClaimBlocked(claim!) || (claim!.signingChannel != nil && Lbryio.isClaimBlocked(claim!.signingChannel!)) {
                displayClaimBlocked()
            } else {
                displayClaim()
                loadAndDisplayViewCount()
                loadReactions()
                loadRelatedContent()
                loadComments()
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
        } else {
            displayClaim()
            loadAndDisplayViewCount()
            loadReactions()
            loadRelatedContent()
            loadComments()
            
            checkFollowing()
            checkNotificationsDisabled()
        }
    }
    
    func resolveAndDisplayClaim() {
        displayResolving()
        
        let url = claimUrl!.description
        if Lbry.claimCacheByUrl[url] != nil {
            self.claim = Lbry.claimCacheByUrl[url]
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
                        self.claim = claim
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
        
        let url = URL(string: String(format: "https://api.bitwave.tv/v1/odysee/live/%@", claim!.signingChannel!.claimId!))
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
                    
                    if let streamUrl = livestreamData["url"] as? String {
                        let headers: Dictionary<String, String> = [
                            "Referer": "https://bitwave.tv"
                        ]
                        self.initializePlayerWithUrl(sourceUrl: streamUrl, headers: headers)
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
    
    func displayClaim() {
        isLivestream = claim?.value?.source == nil
        detailsScrollView.isHidden = isLivestream
        livestreamChatView.isHidden = !isLivestream
        
        resolvingView.isHidden = true
        descriptionArea.isHidden = true
        descriptionDivider.isHidden = true
        displayRelatedPlaceholders()
        
        connectChatSocket()
        
        commentsDisabled = Helper.claimContainsTag(claim: claim!, tag: Helper.tagDisableComments) ||
            (claim?.signingChannel != nil && Helper.claimContainsTag(claim: claim!.signingChannel!, tag: Helper.tagDisableComments))
        if commentsDisabled {
            commentExpandView.isHidden = true
            noCommentsLabel.isHidden = false
            noCommentsLabel.text = String.localized("Comments are disabled.")
            featuredCommentView.isHidden = true
        }
        
        titleLabel.text = claim?.value?.title
        
        let releaseTime: Double = Double(claim?.value?.releaseTime ?? "0")!
        let date: Date = NSDate(timeIntervalSince1970: releaseTime) as Date // TODO: Timezone check / conversion?
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        timeAgoLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        
        // publisher
        var thumbnailUrl: URL? = nil
        publisherImageView.rounded()
        livestreamerImageView.rounded()
        if (claim?.signingChannel != nil) {
            if !isLivestream {
                publisherTitleLabel.text = claim?.signingChannel?.value?.title
                publisherNameLabel.text = claim?.signingChannel?.name
            } else {
                livestreamerTitleLabel.text = claim?.signingChannel?.value?.title
                livestreamerNameLabel.text = claim?.signingChannel?.name
                
            }
            if (claim?.signingChannel?.value != nil && claim?.signingChannel?.value?.thumbnail != nil) {
                thumbnailUrl = URL(string: (claim!.signingChannel!.value!.thumbnail!.url!))!
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
        
        if (claim?.value?.description ?? "").isBlank {
            descriptionArea.isHidden = true
            descriptionDivider.isHidden = true
        } else {
            // details
            descriptionLabel.text = claim?.value?.description
        }
        
        if isLivestream {
            loadLivestream()
        } else {
            initializePlayerWithUrl(sourceUrl: getStreamingUrl(claim: claim!))
        }
    }
    
    func initializePlayerWithUrl(sourceUrl: String, headers: Dictionary<String, String> = [:]) {
        DispatchQueue.main.async {
            self.livestreamOfflinePlaceholder.isHidden = true
            
            self.avpc = AVPlayerViewController()
            self.avpc.allowsPictureInPicturePlayback = true
            self.avpc.updatesNowPlayingInfoCenter = false
            
            self.addChild(self.avpc)
            self.avpc.view.frame = self.mediaView.bounds
            self.mediaView.addSubview(self.avpc.view)
            self.avpc.didMove(toParent: self)
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.avpc.delegate = appDelegate.mainController
            if (appDelegate.player != nil && appDelegate.currentClaim != nil && appDelegate.currentClaim?.claimId == self.claim?.claimId) {
                self.avpc.player = appDelegate.player
                self.playerConnected = true
                return
            }
            
            appDelegate.currentClaim = self.claim
            if (appDelegate.player != nil) {
                appDelegate.player!.pause()
            }
        
            let videoUrl = URL(string: sourceUrl)
            if (videoUrl == nil) {
                self.showError(message: String(format: "The streaming url could not be loaded: %@", sourceUrl))
                return
            }
            
            appDelegate.playerObserverAdded = false
            
            if headers.keys.count > 0 {
                let asset = AVURLAsset(url: videoUrl!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                let playerItem = AVPlayerItem(asset: asset)
                appDelegate.player = AVPlayer(playerItem: playerItem)
            } else {
                appDelegate.player = AVPlayer(url: videoUrl!)
            }
            appDelegate.registerPlayerObserver()
            self.avpc.player = appDelegate.player
            self.playerConnected = true
            self.playRequestTime = Int64(Date().timeIntervalSince1970 * 1000.0)
            
            self.avpc.player!.play()
        }
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
        let url = claim!.permanentUrl!
        
        Analytics.logEvent("play", parameters: [
            "url": url,
            "time_to_start_ms": timeToStartMs,
            "time_to_start_seconds": timeToStartSeconds
        ])
     
        logFileView(url: url, timeToStart: timeToStartMs)
    }
    
    func disconnectPlayer() {
        avpc.player = nil
        playerConnected = false
    }
    
    func connectPlayer() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.player != nil {
            avpc.player = appDelegate.player
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
            try Lbryio.call(resource: "file", action: "view", options: options, method: Lbryio.methodPost, completion: { data, error in
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
            Lbry.apiCall(method: Lbry.methodAddressUnused, params: Dictionary<String, Any>(), connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }
                
                let newAddress = data["result"] as! String
                DispatchQueue.main.async {
                    let defaults = UserDefaults.standard
                    defaults.setValue(newAddress, forKey: Helper.keyReceiveAddress)
                }
                
                Lbryio.claimReward(type: "daily_view", walletAddress: newAddress, completion: { data, error in })
            })
            
            return
        }
        
        Lbryio.claimReward(type: "daily_view", walletAddress: receiveAddress!, completion: { data, error in
            // don't do anything here
        })
    }
    
    func getStreamingUrl(claim: Claim) -> String {
        let claimName: String = claim.name!
        let claimId: String = claim.claimId!
        return String(format: "https://cdn.lbryplayer.xyz/content/claims/%@/%@/stream", claimName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!, claimId);
    }
    
    func loadAndDisplayViewCount() {
        if isLivestream {
            return
        }
        
        do {
            let options: Dictionary<String, String> = ["claim_id": claim!.claimId!]
            try Lbryio.call(resource: "file", action: "view_count", options: options, method: Lbryio.methodGet, completion: { data, error in
                guard let data = data, error == nil else {
                    // couldn't load the view count for display
                    DispatchQueue.main.async {
                        self.viewCountLabel.isHidden = true
                    }
                    return
                }
                DispatchQueue.main.async {
                    let formatter = NumberFormatter()
                    formatter.usesGroupingSeparator = true
                    formatter.locale = Locale.current
                    formatter.numberStyle = .decimal
                    
                    let viewCount = (data as! NSArray)[0] as! Int
                    self.viewCountLabel.isHidden = false
                    self.viewCountLabel.text = String(format: viewCount == 1 ? String.localized("%@ view") : String.localized("%@ views"), formatter.string(for: viewCount)!)
                }
            })
        } catch {
            // pass
        }
    }
    
    func loadReactions() {
        if isLivestream {
            return
        }
        
        do {
            let claimId = claim!.claimId!
            let options: Dictionary<String, String> = ["claim_ids": claimId]
            try Lbryio.call(resource: "reaction", action: "list", options: options, method: Lbryio.methodPost, completion: { data, error in
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
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
    
        DispatchQueue.main.async {
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
            let claimId = claim!.claimId!
            var options: Dictionary<String, String> = [
                "claim_ids": claimId,
                "type": type,
                "clear_types": type == Helper.reactionTypeLike ? Helper.reactionTypeDislike : Helper.reactionTypeLike
            ]
            if (type == Helper.reactionTypeLike && likesContent) || (type == Helper.reactionTypeDislike && dislikesContent) {
                remove = true
                options["remove"] = "true"
            }
            try Lbryio.call(resource: "reaction", action: "react", options: options, method: Lbryio.methodPost, completion: { data, error in
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
                self.loadingRelatedView.isHidden = true
                return
            }
            
            var resolveUrls: [String] = []
            for item in results! {
                let lbryUri = LbryUri.tryParse(url: String(format: "%@#%@", item["name"] as! String, item["claimId"] as! String), requireProto: false)
                if (lbryUri != nil) {
                    resolveUrls.append(lbryUri!.description)
                }
            }
            
            self.resolveAndDisplayRelatedContent(urls: resolveUrls)
        })
    }
    
    func resolveAndDisplayRelatedContent(urls: [String]) {
        var params: Dictionary<String, Any> = Dictionary<String, Any>()
        params["urls"] = urls
        
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                // display no results
                self.loadingRelatedView.isHidden = true
                //self.checkNoResults()
                return
            }
            
            var claimResults: [Claim] = []
            let result = data["result"] as! NSDictionary
            self.relatedContent = []
            for (_, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if (claim != nil && !(claim?.claimId ?? "").isBlank && self.claim!.claimId != claim!.claimId &&
                            !self.relatedContent.contains(where: { $0.claimId == claim?.claimId })) {
                        Lbry.addClaimToCache(claim: claim)
                        claimResults.append(claim!)
                    }
                } catch {
                    // pass
                }
            }
            self.relatedContent.append(contentsOf: claimResults)
            self.loadingRelated = false
            
            DispatchQueue.main.async {
                self.loadingRelatedView.isHidden = true
                self.relatedContentListView.reloadData()
            }
        })
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
            return relatedContent.count
        }
        
        if tableView == chatListView {
            return messages.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == relatedContentListView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
            let claim: Claim = relatedContent[indexPath.row]
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
            let claim: Claim = relatedContent[indexPath.row]
            if claim.claimId == "placeholder" {
                return
            }
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = claim
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
    
    @IBAction func commentAreaTapped(_ sender: Any) {
        if commentsDisabled {
            return
        }
        
        if commentsViewPresented {
            commentsContainerView.isHidden = false
            return
        }
        
        let vc = storyboard?.instantiateViewController(identifier: "comments_vc") as! CommentsViewController
        vc.claimId = claim?.claimId!
        vc.commentsDisabled = commentsDisabled
        vc.comments = comments
        vc.commentsLastPageReached = commentsLastPageReached
        vc.authorThumbnailMap = authorThumbnailMap
        
        vc.willMove(toParent: self)
        commentsContainerView.addSubview(vc.view)
        vc.view.frame = CGRect(x: 0, y: 0, width: commentsContainerView.bounds.width, height: commentsContainerView.bounds.height)
        self.addChild(vc)
        vc.didMove(toParent: self)
        
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
        if claim!.signingChannel != nil {
            let channelClaim = claim!.signingChannel!
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
        
        if claim?.signingChannel == nil {
            return
        }
        let channelClaim = claim!.signingChannel!
        subscribeOrUnsubscribe(claim: channelClaim, notificationsDisabled: Lbryio.isNotificationsDisabledForSub(claim: channelClaim), unsubscribing: Lbryio.isFollowing(claim: channelClaim))
    }
    
    @IBAction func bellTapped(_ sender: Any) {
        if (!Lbryio.isSignedIn()) {
            // shouldn't be able to access this action if the user is not signed in, but just in case
            showUAView()
            return
        }
        
        if claim?.signingChannel == nil {
            return
        }
        let channelClaim = claim!.signingChannel!
        subscribeOrUnsubscribe(claim: channelClaim, notificationsDisabled: !Lbryio.isNotificationsDisabledForSub(claim: channelClaim), unsubscribing: false)
    }
    
    func checkFollowing() {
        if claim?.signingChannel == nil {
            return
        }
        
        let channelClaim = claim!.signingChannel!
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
    
    func checkNotificationsDisabled() {
        if claim?.signingChannel == nil {
            return
        }
        
        let channelClaim = claim!.signingChannel!
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
            try Lbryio.call(resource: "subscription", action: unsubscribing ? "delete" : "new", options: options, method: Lbryio.methodGet, completion: { data, error in
                self.subscribeUnsubscribeInProgress = false
                guard let _ = data, error == nil else {
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
        let url = LbryUri.tryParse(url: claim!.shortUrl!, requireProto: false)
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
        vc.claim = claim!
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
            descriptionArea.isHidden = false
            descriptionDivider.isHidden = false
            titleAreaIconView.image = UIImage.init(systemName: "chevron.up")
        } else {
            descriptionArea.isHidden = true
            descriptionDivider.isHidden = true
            titleAreaIconView.image = UIImage.init(systemName: "chevron.down")
        }
    }
    
    func loadComments() {
        if commentsDisabled || commentsLoading || isLivestream {
            return
        }
        
        commentsLoading = true
        let params: Dictionary<String, Any> = [
            "claim_id": claim!.claimId!,
            "page": commentsCurrentPage,
            "page_size": commentsPageSize,
            "skip_validation": true,
            "include_replies": false
        ]
        
        Lbry.apiCall(method: Lbry.methodCommentList, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                print(error!)
                return
            }
            
            let result = data["result"] as? [String: Any]
            if let items = result?["items"] as? [[String: Any]] {
                if items.count < self.commentsPageSize {
                    self.commentsLastPageReached = true
                }
                var loadedComments: [Comment] = []
                items.forEach { item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let comment: Comment? = try JSONDecoder().decode(Comment.self, from: data)
                        if (comment != nil && !self.comments.contains(where: { $0.commentId == comment?.commentId })) {
                            loadedComments.append(comment!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.comments.append(contentsOf: loadedComments)
                // resolve author map
                if self.comments.count > 0 {
                    self.resolveCommentAuthors(urls: loadedComments.map { $0.channelUrl! })
                }
                
            }
            
            self.commentsLoading = false
            DispatchQueue.main.async {
                self.checkNoComments()
                self.checkFeaturedComment()
            }
        })
    }
    
    func checkFeaturedComment() {
        DispatchQueue.main.async {
            if self.comments.count > 0 {
                self.featuredCommentLabel.text = self.comments[0].comment
                if let thumbUrlStr = self.authorThumbnailMap[self.comments[0].channelUrl!] {
                    self.featuredCommentThumbnail.backgroundColor = UIColor.clear
                    self.featuredCommentThumbnail.load(url: URL(string: thumbUrlStr)!)
                } else {
                    self.featuredCommentThumbnail.image = UIImage.init(named: "spaceman")
                    self.featuredCommentThumbnail.backgroundColor = Helper.lightPrimaryColor
                }
            }
        }
    }
    
    func resolveCommentAuthors(urls: [String]) {
        let params = ["urls": urls]
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { [self] data, error in
            guard let data = data, error == nil else {
                return
            }
            
            let result = data["result"] as! NSDictionary
            for (url, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if claim != nil && !(claim!.claimId ?? "").isBlank {
                        if claim!.value != nil && claim!.value!.thumbnail != nil && !(claim!.value!.thumbnail!.url ?? "").isBlank {
                            self.authorThumbnailMap[url as! String] = claim!.value!.thumbnail!.url!
                        }
                    }
                } catch {
                    // pass
                }
            }
            self.checkFeaturedComment()
        })
    }
    
    func checkNoComments() {
        DispatchQueue.main.async {
            self.noCommentsLabel.isHidden = self.comments.count > 0
            self.featuredCommentView.isHidden = self.comments.count == 0
        }
    }
    
    func loadChannels() {
        if loadingChannels {
            return
        }
        
        loadingChannels = true
        let options: Dictionary<String, Any> = ["claim_type": "channel", "page": 1, "page_size": 999, "resolve": true]
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
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
                        if (claim != nil) {
                            loadedClaims.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.channels.removeAll()
                self.channels.append(contentsOf: loadedClaims)
                Lbry.ownChannels = self.channels.filter { $0.claimId != "anonymous" }
            }
            
            self.loadingChannels = false
        })
    }
    
    func connectChatSocket() {
        if isLivestream {
            let url = URL(string: String(format: "%@%@", Lbryio.wsCommmentBaseUrl, claim!.claimId!))
            chatWebsocket = WebSocket(request: URLRequest(url: url!))
            chatWebsocket!.delegate = self
            chatWebsocket?.connect()
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
