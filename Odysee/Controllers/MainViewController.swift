//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/11/2020.
//

import AVFoundation
import AVKit
import CoreData
import FirebaseCrashlytics
import MediaPlayer
import MessageUI
import UIKit

class MainViewController: UIViewController, AVPlayerViewControllerDelegate, MFMailComposeViewControllerDelegate {
    @IBOutlet var headerArea: UIView!
    @IBOutlet var headerAreaHeightConstraint: NSLayoutConstraint!
    @IBOutlet var miniPlayerBottomConstraint: NSLayoutConstraint!

    @IBOutlet var miniPlayerView: UIView!
    @IBOutlet var miniPlayerMediaView: UIView!
    @IBOutlet var miniPlayerTitleLabel: UILabel!
    @IBOutlet var miniPlayerPublisherLabel: UILabel!
    @IBOutlet var miniPlayerPlayPauseButton: UIImageView!

    @IBOutlet var mainBalanceLabel: UILabel!

    @IBOutlet var notificationBadgeView: UIView!
    @IBOutlet var notificationBadgeCountLabel: UILabel!
    @IBOutlet var notificationBadgeIcon: UIImageView!

    @IBOutlet var uploadButtonView: UIView!

    var loadingNotifications = false
    var notificationsViewActive = false
    var channels: [Claim] = []
    var customBlockRulesMap: [String: [CustomBlockRule]] = [:]
    var currentLocale: OdyseeLocale?

    var mainNavigationController: UINavigationController!
    var walletObservers = [String: WalletBalanceObserver]()
    var walletSyncObservers = [String: WalletSyncObserver]()

    var walletBalanceTimer = Timer()
    var walletSyncTimer = Timer()

    var balanceTimerScheduled = false
    var syncTimerScheduled = false

    let balanceTimerInterval: Double = 5 // 5 seconds
    let syncTimerInterval: Double = 300 // 5 minutes

    let snackbar = Snackbar()

    var blockChannelObservers = [String: BlockChannelStatusObserver?]()
    var fetchContext: NSManagedObjectContext?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        snackbar.sbLength = .long
        checkAndShowFirstRun()
        checkUploadButton()

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let pendingOpenUrl = appDelegate.pendingOpenUrl {
            if handleSpecialUrl(url: pendingOpenUrl) {
                return
            }

            if let lbryUrl = LbryUri.tryParse(url: pendingOpenUrl, requireProto: false) {
                if lbryUrl.isChannel {
                    let vc = storyboard?
                        .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    appDelegate.mainNavigationController?.view.layer.add(
                        Helper.buildFileViewTransition(),
                        forKey: kCATransition
                    )
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            // enable audio in silent mode
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            showError(error: error)
        }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController = self

        notificationBadgeView.layer.cornerRadius = 6

        // Load blocked channels
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "BlockedChannel")
        fetchRequest.returnsObjectsAsFaults = false
        let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { asyncFetchResult in
            guard let blockedChannels = asyncFetchResult.finalResult as? [BlockedChannel] else { return }
            Lbry.blockedChannels = blockedChannels
            DispatchQueue.main.async {
                // notify observers, if any
                self.notifyBlockChannelObservers()
            }
        }

        fetchContext = appDelegate.persistentContainer.newBackgroundContext()
        do {
            try fetchContext?.execute(asyncFetchRequest)
        } catch {
            print("NSAsynchronousFetchRequest error: \(error)")
        }

        // Do any additional setup after loading the view
        startWalletBalanceTimer()
        startWalletSyncTimer()
        loadNotifications()
        loadAppleFilteredClaimIds()
        loadBlockedOutpoints()
        loadFilteredOutpoints()
        loadLocaleAndCustomBlockedRules()

        if Lbryio.isSignedIn() {
            // check if the user is pending_delete
            if let pendingDeletion = Lbryio.currentUser?.pendingDeletion, pendingDeletion {
                stopAllTimers()
                resetUserAndViews()
                return
            }

            checkAndClaimEmailReward(completion: {})
            checkAndShowYouTubeSync()
            loadChannels()
        }
    }

    func addBlockChannelObserver(name: String, observer: BlockChannelStatusObserver) {
        blockChannelObservers[name] = observer
    }

    func removeBlockChannelObserver(name: String) {
        if let _ = blockChannelObservers[name] {
            blockChannelObservers.removeValue(forKey: name)
        }
    }

    func checkAndClaimEmailReward(completion: @escaping (() -> Void)) {
        if !Lbryio.Defaults.isEmailRewardClaimed {
            let receiveAddress = UserDefaults.standard.string(forKey: Helper.keyReceiveAddress)
            if let receiveAddress, !receiveAddress.isBlank {
                claimEmailReward(walletAddress: receiveAddress, completion: completion)
            } else {
                Lbry.apiCall(method: Lbry.Methods.addressUnused, params: .init()).subscribeResult { result in
                    guard case let .success(newAddress) = result else {
                        return
                    }
                    UserDefaults.standard.set(newAddress, forKey: Helper.keyReceiveAddress)
                    self.claimEmailReward(walletAddress: newAddress, completion: completion)
                }

                return
            }
        } else {
            completion()
        }
    }

    func claimEmailReward(walletAddress: String, completion: @escaping (() -> Void)) {
        Lbryio.claimReward(type: "email_provided", walletAddress: walletAddress, completion: { data, error in
            guard let _ = data, error == nil else {
                // self.showError(error: error)
                completion()
                return
            }
            DispatchQueue.main.async {
                Lbryio.Defaults.isEmailRewardClaimed = true
            }
            completion()
        })
    }

    func checkAndShowFirstRun() {
        if !AppDelegate.hasCompletedFirstRun() {
            Lbryio.deleteAuthToken()
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "fr_vc") as! FirstRunViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    func checkAndShowYouTubeSync() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        guard !Lbryio.Defaults.isYouTubeSyncDone else {
            return
        }
        let vc = storyboard?.instantiateViewController(identifier: "yt_sync_vc") as! YouTubeSyncViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }

    func stopAllTimers() {
        walletBalanceTimer.invalidate()
        walletSyncTimer.invalidate()
    }

    func resetUserAndViews() {
        Lbryio.cachedSubscriptions = [:]
        Lbryio.cachedNotifications = []
        Lbry.walletBalance = WalletBalance()

        mainBalanceLabel.text = "0"
        notificationBadgeView.isHidden = true
        notificationBadgeCountLabel.text = ""

        // remove the auth token so that a new one will be generated upon the next init
        Lbryio.authToken = nil
        Lbryio.Defaults.reset()

        // clear the wallet address if it exists
        UserDefaults.standard.removeObject(forKey: Helper.keyReceiveAddress)

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainNavigationController?.popToRootViewController(animated: false)
        if let initvc = presentingViewController as? InitViewController {
            initvc.dismiss(animated: true, completion: {
                initvc.runInit()
            })
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "main_nav" {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            mainNavigationController = segue.destination as? UINavigationController
            appDelegate.mainNavigationController = mainNavigationController
        }
    }

    // Experimental
    func toggleHeaderVisibility(hidden: Bool) {
        headerArea.isHidden = hidden
        headerAreaHeightConstraint.constant = hidden ? 0 : 52
        view.layoutIfNeeded()
    }

    func adjustMiniPlayerBottom(bottom: CGFloat) {
        miniPlayerBottomConstraint.constant = bottom
    }

    @IBAction func closeMiniPlayerTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.lazyPlayer != nil {
            appDelegate.lazyPlayer?.pause()
            appDelegate.lazyPlayer?.allowsExternalPlayback = false
            appDelegate.playerObservers = nil
            appDelegate.lazyPlayer = nil

            appDelegate.resetPlayerObserver()
            appDelegate.removeRemoteTransportControls()
        }

        miniPlayerTitleLabel.text = ""
        miniPlayerPublisherLabel.text = ""
        appDelegate.currentClaim = nil

        toggleMiniPlayer(hidden: true)
    }

    @IBAction func playPauseMiniPlayerTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if let lazyPlayer = appDelegate.lazyPlayer {
            if lazyPlayer.rate == 0 {
                lazyPlayer.play()
                miniPlayerPlayPauseButton.image = UIImage(systemName: "pause.fill")
            } else {
                lazyPlayer.pause()
                miniPlayerPlayPauseButton.image = UIImage(systemName: "play.fill")
            }
        }
    }

    @IBAction func uploadTapped(_ sender: Any) {
        if UIApplication.currentViewController() as? PublishViewController != nil {
            return
        }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func walletBalanceActionTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainTabViewController?.selectedIndex = 2
        if notificationsViewActive {
            appDelegate.mainNavigationController?.popViewController(animated: true)
        }
    }

    @IBAction func searchActionTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "search_vc") as! SearchViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func notificationsActionTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if notificationsViewActive {
            appDelegate.mainNavigationController?.popViewController(animated: true)
            return
        }

        let vc = storyboard?.instantiateViewController(identifier: "notifications_vc") as! NotificationsViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func accountActionTapped(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(identifier: "ua_menu_vc") as! UserAccountMenuViewController
        vc.modalPresentationStyle = .overCurrentContext
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @IBAction func openCurrentClaim(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        if appDelegate.mainNavigationController?.topViewController == appDelegate.currentFileViewController {
            appDelegate.mainNavigationController?.popViewController(animated: false)
        } else if let fileVc = appDelegate.currentFileViewController,
                  fileVc.claim == appDelegate.currentClaim
        {
            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(fileVc, animated: false)
            return
        }

        if appDelegate.currentClaim != nil {
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = appDelegate.currentClaim

            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }

    func checkUploadButton() {
        uploadButtonView.isHidden = !Lbryio.isSignedIn()
    }

    func loadFilteredOutpoints() {
        do {
            try Lbryio.get(
                resource: "file",
                action: "list_filtered",
                options: [:],
                authTokenOverride: "",
                completion: { data, error in
                    guard let data = data, error == nil else {
                        return
                    }

                    if let result = data as? [String: Any],
                       let outpointStrings = result["outpoints"] as? [String]
                    {
                        let outpoints = Set(outpointStrings.compactMap(Outpoint.parse))
                        Lbryio.setFilteredOutpoints(outpoints)
                    }
                }
            )
        } catch {
            // pass
        }
    }

    func loadAppleFilteredClaimIds() {
        do {
            var options: [String: String] = [:]
            options["platform"] = "ios"
            options["with_claim_id"] = "true"
            try Lbryio.get(
                resource: "file",
                action: "list_blocked",
                options: options,
                authTokenOverride: "",
                completion: { data, error in
                    guard let data = data, error == nil else {
                        return
                    }

                    if let result = data as? [[String: Any]] {
                        for item in result {
                            Lbryio.addAppleFilteredClaim(
                                claimId: item["claim_id"] as? String,
                                tag: item["tag_name"] as? String
                            )
                        }
                        Lbryio.updateAppleFilteredClaimIds()
                    }
                }
            )
        } catch {
            // pass
        }
    }

    func loadBlockedOutpoints() {
        do {
            try Lbryio.get(
                resource: "file",
                action: "list_blocked",
                options: [:],
                authTokenOverride: "",
                completion: { data, error in
                    guard let data = data, error == nil else {
                        return
                    }

                    if let result = data as? [String: Any],
                       let outpointStrings = result["outpoints"] as? [String]
                    {
                        let outpoints = Set(outpointStrings.compactMap(Outpoint.parse))
                        Lbryio.setBlockedOutpoints(outpoints)
                    }
                }
            )
        } catch {
            // pass
        }
    }

    func loadLocaleAndCustomBlockedRules() {
        do {
            try Lbryio.get(resource: "locale", action: "get", options: [:], completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }
                if let result = data as? [String: Any] {
                    self.currentLocale = OdyseeLocale()
                    self.currentLocale?.continent = result["continent"] as? String
                    self.currentLocale?.country = result["country"] as? String
                    self.currentLocale?.isEUMember = result["is_eu_member"] as? Bool

                    self.loadCustomBlockedRules()
                }
            })
        } catch {
            // pass
        }
    }

    func loadCustomBlockedRules() {
        do {
            try Lbryio.get(resource: "geo", action: "blocked_list", options: [:], completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }

                if let result = data as? [String: Any] {
                    if let livestreams = result["livestreams"] as? [String: Any] {
                        // parse block rules for livestreams
                        for (claimId, value) in livestreams {
                            var cbRules: [CustomBlockRule] = []
                            if let rules = value as? [String: [Any]] {
                                cbRules += self.parseCustomBlockRules(
                                    rules: rules["countries"],
                                    type: CustomBlockContentType.livestreams,
                                    scope: CustomBlockScope.country
                                )
                                cbRules += self.parseCustomBlockRules(
                                    rules: rules["continents"],
                                    type: CustomBlockContentType.livestreams,
                                    scope: CustomBlockScope.continent
                                )
                                cbRules += self.parseCustomBlockRules(
                                    rules: rules["specials"],
                                    type: CustomBlockContentType.livestreams,
                                    scope: CustomBlockScope.special
                                )
                            }

                            self.customBlockRulesMap[claimId] = cbRules
                        }
                    }

                    if let videos = result["videos"] as? [String: Any] {
                        for (claimId, value) in videos {
                            var cbRules: [CustomBlockRule] = if let cbRules = self.customBlockRulesMap[claimId] {
                                cbRules
                            } else {
                                []
                            }
                            if let rules = value as? [String: [Any]] {
                                cbRules += self.parseCustomBlockRules(
                                    rules: rules["countries"],
                                    type: CustomBlockContentType.videos,
                                    scope: CustomBlockScope.country
                                )
                                cbRules += self.parseCustomBlockRules(
                                    rules: rules["continents"],
                                    type: CustomBlockContentType.videos,
                                    scope: CustomBlockScope.continent
                                )
                                cbRules += self.parseCustomBlockRules(
                                    rules: rules["specials"],
                                    type: CustomBlockContentType.videos,
                                    scope: CustomBlockScope.special
                                )
                            }

                            self.customBlockRulesMap[claimId] = cbRules
                        }
                    }
                }
            })
        } catch {
            // pass
        }
    }

    func parseCustomBlockRules(
        rules: [Any]?,
        type: CustomBlockContentType,
        scope: CustomBlockScope
    ) -> [CustomBlockRule] {
        guard let rules else {
            return []
        }

        var cbRules: [CustomBlockRule] = []
        for rule in rules {
            if let indvRule = rule as? [String: Any] {
                var cbRule = CustomBlockRule()
                cbRule.type = type
                cbRule.scope = scope
                cbRule.id = indvRule["id"] as? String
                cbRule.trigger = indvRule["trigger"] as? String
                cbRule.message = indvRule["message"] as? String
                cbRule.reason = indvRule["reason"] as? String
                cbRules.append(cbRule)
            }
        }

        return cbRules
    }

    func loadNotifications() {
        if loadingNotifications {
            return
        }
        do {
            var options: [String: String] = [:]
            if Lbryio.latestNotificationId > 0 {
                options["since_id"] = String(Lbryio.latestNotificationId)
            }

            try Lbryio.post(resource: "notification", action: "list", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }

                if let items = data as? [[String: Any]] {
                    var loadedNotifications: [LbryNotification] = []
                    for item in items {
                        do {
                            let jsonData = try JSONSerialization.data(
                                withJSONObject: item as Any,
                                options: [.prettyPrinted, .sortedKeys]
                            )
                            let notification: LbryNotification? = try JSONDecoder()
                                .decode(LbryNotification.self, from: jsonData)
                            if let notification {
                                loadedNotifications.append(notification)
                            }
                        } catch {
                            // pass
                        }
                    }
                    Lbryio.cachedNotifications.append(contentsOf: loadedNotifications)
                    Lbryio.cachedNotifications.sort(by: { ($0.createdAt ?? "") > ($1.createdAt ?? "") })
                    Lbryio.latestNotificationId = Lbryio.cachedNotifications.compactMap(\.id).max() ?? 0
                }

                self.loadingNotifications = false
                self.updateUnseenCount()
            })
        } catch {
            showError(error: error)
        }
    }

    func updateUnseenCount() {
        let unseenCount = Lbryio.cachedNotifications.reduce(0) { $0 + ($1.isSeen ?? false ? 0 : 1) }
        DispatchQueue.main.async {
            if unseenCount > 0 {
                self.notificationBadgeView.isHidden = false
                self.notificationBadgeCountLabel.text = unseenCount < 100 ? String(unseenCount) : "99+"
            } else {
                self.notificationBadgeView.isHidden = true
                self.notificationBadgeCountLabel.text = ""
            }
        }
    }

    func updateMiniPlayer() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.currentClaim != nil, appDelegate.lazyPlayer != nil {
            miniPlayerTitleLabel.text = appDelegate.currentClaim?.value?.title
            miniPlayerPublisherLabel.text = appDelegate.currentClaim?.signingChannel?.value?.title

            let mediaViewLayer: CALayer = miniPlayerMediaView.layer
            let playerLayer = AVPlayerLayer(player: appDelegate.lazyPlayer)
            playerLayer.frame = mediaViewLayer.bounds
            playerLayer.videoGravity = .resizeAspectFill
            _ = mediaViewLayer.sublayers?.popLast()
            mediaViewLayer.addSublayer(playerLayer)
        }
    }

    func toggleMiniPlayer(hidden: Bool) {
        miniPlayerView.isHidden = hidden
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            self.snackbar.backgroundColor = .darkGray
            self.snackbar.createWithText(message ?? "")
        }
    }

    func showErrorAlert(title: String? = nil, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default))
        present(alert, animated: true)
    }

    func showError(message: String?) {
        // Going back and forth with GenericError,
        // in the case where we come from showError(error:)
        Crashlytics.crashlytics().recordImmediate(error: GenericError(""), userInfo: ["MESSAGE_KEY": message ?? ""])

        DispatchQueue.main.async {
            self.snackbar.backgroundColor = .red
            self.snackbar.createWithText(message ?? "")
        }
    }

    func showError(error: Error?) {
        if let responseError = error as? LbryioResponseError {
            showError(message: responseError.localizedDescription)
            return
        }
        if let apiError = error as? LbryApiResponseError {
            showError(message: apiError.localizedDescription)
            return
        }
        if let genericError = error as? GenericError {
            showError(message: genericError.localizedDescription)
            return
        }

        showError(message: error?.localizedDescription)
    }

    func addWalletObserver(key: String, observer: WalletBalanceObserver) {
        walletObservers[key] = observer
    }

    func removeWalletObserver(key: String) {
        walletObservers.removeValue(forKey: key)
    }

    func addWalletSyncObserver(key: String, observer: WalletSyncObserver) {
        walletSyncObservers[key] = observer
    }

    func removeWalletSyncObserver(key: String) {
        walletSyncObservers.removeValue(forKey: key)
    }

    func startWalletBalanceTimer() {
        if Lbryio.isSignedIn(), !balanceTimerScheduled {
            walletBalanceTimer = Timer.scheduledTimer(
                timeInterval: balanceTimerInterval,
                target: self,
                selector: #selector(fetchWalletBalance),
                userInfo: nil,
                repeats: true
            )
            balanceTimerScheduled = true
        }
    }

    func startWalletSyncTimer() {
        if Lbryio.isSignedIn(), !syncTimerScheduled {
            walletSync()
            walletSyncTimer = Timer.scheduledTimer(
                timeInterval: syncTimerInterval,
                target: self,
                selector: #selector(walletSync),
                userInfo: nil,
                repeats: true
            )
            syncTimerScheduled = true
        }
    }

    @objc func walletSync() {
        Lbry.pullSyncWallet(completion: { changesApplied in
            if changesApplied {
                // notify observers
                DispatchQueue.main.async {
                    for observer in self.walletSyncObservers.values {
                        observer.syncCompleted()
                    }
                }
            }
        })
    }

    @objc func fetchWalletBalance() {
        Lbry.apiCall(
            method: Lbry.methodWalletBalance,
            params: [String: Any](),
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }

                let result = data["result"] as! [String: Any]

                var balance = WalletBalance()
                balance.available = Decimal(string: result["available"] as? String ?? "0")
                balance.reserved = Decimal(string: result["reserved"] as? String ?? "0")
                balance.total = Decimal(string: result["total"] as? String ?? "0")

                if let reservedSubtotals = result["reserved_subtotals"] as? [String: Any] {
                    balance.claims = Decimal(string: reservedSubtotals["claims"] as? String ?? "0")
                    balance.supports = Decimal(string: reservedSubtotals["supports"] as? String ?? "0")
                    balance.tips = Decimal(string: reservedSubtotals["tips"] as? String ?? "0")
                } else {
                    balance.claims = Decimal(0)
                    balance.supports = Decimal(0)
                    balance.tips = Decimal(0)
                }
                Lbry.walletBalance = balance
                DispatchQueue.main.async {
                    self.mainBalanceLabel.text = Helper.shortCurrencyFormat(value: balance.total)
                    for observer in self.walletObservers.values {
                        observer.balanceUpdated(balance: balance)
                    }
                }
            }
        )
    }

    func handleSpecialUrl(url: String) -> Bool {
        if url.starts(with: "lbry://?") {
            let destination = String(url.suffix(from: url.index(url.firstIndex(of: "?")!, offsetBy: 1)))

            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            if destination == "subscriptions" || destination == "subscription" || destination == "following" {
                appDelegate.mainTabViewController?.selectedIndex = 1
            } else if destination == "rewards" {
                let vc = storyboard?.instantiateViewController(identifier: "rewards_vc") as! RewardsViewController
                appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
            } else if destination == "wallet" {
                appDelegate.mainTabViewController?.selectedIndex = 2
            }

            // TODO: invite | invites | discover | channels | library

            return true
        }

        return false
    }

    func loadChannels() {
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
        Lbry.ownChannels = channels
        if !channels.isEmpty {
            oneTimeChannelsAssociation(channels)
        }
    }

    func oneTimeChannelsAssociation(_ channels: [Claim]) {
        guard !Lbryio.Defaults.isChannelsAssociated else {
            return
        }
        for channel in channels {
            Lbryio.logPublishEvent(channel)
        }
        Lbryio.Defaults.isChannelsAssociated = true
    }

    @IBAction func brandTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if notificationsViewActive {
            appDelegate.mainNavigationController?.popViewController(animated: true)
            return
        }
        if appDelegate.mainTabViewController != nil, appDelegate.mainTabViewController?.selectedIndex != 0 {
            appDelegate.mainTabViewController?.selectedIndex = 0
        }
    }

    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
        _ playerViewController: AVPlayerViewController
    )
        -> Bool
    {
        return false
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.pictureInPicturePlayingClaim = appDelegate.currentClaim
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        if appDelegate.mainNavigationController?.topViewController == appDelegate.currentFileViewController {
            if appDelegate.currentFileViewController?.claim == appDelegate.pictureInPicturePlayingClaim {
                completionHandler(true)
                return
            }

            appDelegate.mainNavigationController?.popViewController(animated: false)
        } else if let fileVc = appDelegate.currentFileViewController,
                  fileVc.claim == appDelegate.pictureInPicturePlayingClaim
        {
            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(fileVc, animated: false)
            completionHandler(true)
            return
        }

        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = appDelegate.pictureInPicturePlayingClaim

        appDelegate.mainNavigationController?.view.layer.add(
            Helper.buildFileViewTransition(),
            forKey: kCATransition
        )
        appDelegate.mainNavigationController?.pushViewController(vc, animated: false)

        completionHandler(true)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil) { _ in
            // Player pauses when returning from full screen
            playerViewController.player?.play()
        }
    }

    func notifyBlockChannelObservers() {
        for observer in blockChannelObservers.values {
            if let observer = observer, Lbry.blockedChannels.count > 0 {
                // use the first claim ID to trigger (this will be used after initial load or sync get)
                observer.blockChannelStatusChanged(claimId: Lbry.blockedChannels[0].claimId ?? "", isBlocked: true)
            }
        }
    }

    func addBlockedChannel(claimId: String, channelName: String, notifyAfter: Bool = false) {
        // persist the subscription to CoreData
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context: NSManagedObjectContext = appDelegate.persistentContainer.viewContext
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let entity = BlockedChannel(context: context)
            entity.claimId = claimId
            entity.name = channelName

            if !Lbry.blockedChannels.contains(entity) {
                Lbry.blockedChannels.append(entity)
            }

            appDelegate.saveContext()

            // notify the observers
            if notifyAfter {
                for observer in self.blockChannelObservers.values {
                    if let observer = observer {
                        observer.blockChannelStatusChanged(claimId: claimId, isBlocked: true)
                    }
                }

                // NOTE: notifyAfter is set to false for loadSharedUserState, so we save state here (and avoid an infinite call loop)
                // run a wallet sync operation to update "blocked"
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
        }
    }

    func removeBlockedChannel(claimId: String) {
        // remove the subscription from CoreData
        DispatchQueue.main.async {
            do {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let context: NSManagedObjectContext = appDelegate.persistentContainer.viewContext
                let fetchRequest: NSFetchRequest<BlockedChannel> = BlockedChannel.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "claimId == %@", claimId)
                let entities = try context.fetch(fetchRequest)

                if entities.count > 0 {
                    let entityToDelete = entities[0]
                    context.delete(entityToDelete)
                    Lbry.blockedChannels = Lbry.blockedChannels.filter { $0.claimId != entityToDelete.claimId }
                }

                try context.save()

                for observer in self.blockChannelObservers.values {
                    if let observer = observer {
                        observer.blockChannelStatusChanged(claimId: claimId, isBlocked: false)
                    }
                }

                // run a wallet sync operation
                Lbry.saveSharedUserState(completion: { success, err in
                    guard err == nil else {
                        self.showError(error: err)
                        return
                    }
                    if success {
                        // run wallet sync
                        Lbry.pushSyncWallet()
                    }
                })
            } catch {
                self.showError(error: error)
            }
        }
    }

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true, completion: nil)
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

protocol WalletBalanceObserver {
    func balanceUpdated(balance: WalletBalance)
}

protocol WalletSyncObserver {
    func syncCompleted()
}
