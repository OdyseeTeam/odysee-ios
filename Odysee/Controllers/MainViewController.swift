//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 11/11/2020.
//

import AVFoundation
import OAuthSwift
import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var headerArea: UIView!
    @IBOutlet weak var headerAreaHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var miniPlayerBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var miniPlayerView: UIView!
    @IBOutlet weak var miniPlayerMediaView: UIView!
    @IBOutlet weak var miniPlayerTitleLabel: UILabel!
    @IBOutlet weak var miniPlayerPublisherLabel: UILabel!
    
    @IBOutlet weak var mainBalanceLabel: UILabel!
    
    @IBOutlet weak var notificationBadgeView: UIView!
    @IBOutlet weak var notificationBadgeCountLabel: UILabel!
    @IBOutlet weak var notificationBadgeIcon: UIImageView!
    
    var loadingNotifications = false
    var notificationsViewActive = false
    
    var mainNavigationController: UINavigationController!
    var walletObservers: Dictionary<String, WalletBalanceObserver> = Dictionary<String, WalletBalanceObserver>()
    var walletSyncObservers: Dictionary<String, WalletSyncObserver> = Dictionary<String, WalletSyncObserver>()
    
    var walletBalanceTimer: Timer = Timer()
    var walletSyncTimer: Timer = Timer()
    
    var balanceTimerScheduled = false
    var syncTimerScheduled = false
    
    let balanceTimerInterval: Double = 5 // 5 seconds
    let syncTimerInterval: Double = 300 // 5 minutes
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.pendingOpenUrl != nil {
            if handleSpecialUrl(url: appDelegate.pendingOpenUrl!) {
                return
            }
            
            let lbryUrl = LbryUri.tryParse(url: appDelegate.pendingOpenUrl!, requireProto: false)
            if lbryUrl != nil {
                if lbryUrl!.isChannelUrl() {
                    let vc = storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainViewController = self
        
        notificationBadgeView.layer.cornerRadius = 6
        
        // Do any additional setup after loading the view.
        startWalletBalanceTimer()
        startWalletSyncTimer()
        loadNotifications()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "main_nav" {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.mainNavigationController = segue.destination as? UINavigationController
            appDelegate.mainNavigationController = self.mainNavigationController
        }
    }
    
    // Experimental
    func toggleHeaderVisibility(hidden: Bool) {
        headerArea.isHidden = hidden
        headerAreaHeightConstraint.constant = hidden ? 0 : 52
        view!.layoutIfNeeded()
    }
    
    func adjustMiniPlayerBottom(bottom: CGFloat) {
        miniPlayerBottomConstraint.constant = bottom
    }
    
    @IBAction func closeMiniPlayerTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.player != nil) {
            appDelegate.player?.pause()
            appDelegate.player = nil
        }
        toggleMiniPlayer(hidden: true)
        miniPlayerTitleLabel.text = ""
        miniPlayerPublisherLabel.text = ""
        appDelegate.currentClaim = nil
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
        present(vc, animated: true)
    }
    
    @IBAction func openCurrentClaim(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.currentClaim != nil) {
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = appDelegate.currentClaim
            
            appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func loadNotifications() {
        if loadingNotifications {
            return
        }
        do {
            try Lbryio.call(resource: "notification", action: "list", options: [:], method: Lbryio.methodPost, completion: { data, error in
                guard let data = data, error == nil else {
                    return
                }
                
                if let items = data as? [[String: Any]] {
                    var loadedNotifications: [LbryNotification] = []
                    items.forEach { item in
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: item as Any, options: [.prettyPrinted, .sortedKeys])
                            let notification: LbryNotification? = try JSONDecoder().decode(LbryNotification.self, from: jsonData)
                            if notification != nil {
                                loadedNotifications.append(notification!)
                            }
                        } catch {
                            // pass
                        }
                    }
                    Lbryio.cachedNotifications.append(contentsOf: loadedNotifications)
                    Lbryio.cachedNotifications.sort(by: { ($0.createdAt ?? "") > ($1.createdAt ?? "")! })
                }
                
                self.loadingNotifications = false
                self.updateUnseenCount()
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    func updateUnseenCount() {
        let unseenCount = Lbryio.cachedNotifications.reduce(0) { $0 + ($1.isSeen! ? 0 : 1) }
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
        if (appDelegate.currentClaim != nil && appDelegate.player != nil) {
            miniPlayerTitleLabel.text = appDelegate.currentClaim?.value?.title
            miniPlayerPublisherLabel.text = appDelegate.currentClaim?.signingChannel?.value?.title
            
            let mediaViewLayer: CALayer = miniPlayerMediaView.layer
            let playerLayer: AVPlayerLayer = AVPlayerLayer(player: appDelegate.player)
            playerLayer.frame = mediaViewLayer.bounds
            playerLayer.videoGravity = .resizeAspectFill
            let _ = mediaViewLayer.sublayers?.popLast()
            mediaViewLayer.addSublayer(playerLayer)
        }
    }
    
    func toggleMiniPlayer(hidden: Bool) {
        miniPlayerView.isHidden = hidden
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
        let sb = Snackbar()
            sb.sbLength = .long
            sb.createWithText(message ?? "")
            sb.show()
        }
    }
    
    func showError(message: String?) {
        DispatchQueue.main.async {
            let sb = Snackbar()
            sb.sbLength = .long
            sb.backgroundColor = UIColor.red
            sb.textColor = UIColor.white
            sb.createWithText(message ?? "")
            sb.show()
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
        if (Lbryio.isSignedIn() && !balanceTimerScheduled) {
            walletBalanceTimer = Timer.scheduledTimer(timeInterval: balanceTimerInterval, target: self, selector: #selector(self.fetchWalletBalance), userInfo: nil, repeats: true)
            balanceTimerScheduled = true
        }
    }
    
    func startWalletSyncTimer() {
        if (Lbryio.isSignedIn() && !syncTimerScheduled) {
            walletSync()
            walletSyncTimer = Timer.scheduledTimer(timeInterval: syncTimerInterval, target: self, selector: #selector(self.walletSync), userInfo: nil, repeats: true)
            syncTimerScheduled = true
        }
    }
    
    @objc func walletSync() {
        Lbry.pullSyncWallet(completion: { changesApplied in
            if changesApplied {
                // notify observers
                DispatchQueue.main.async {
                    self.walletSyncObservers.values.forEach{ observer in
                        observer.syncCompleted()
                    }
                }
            }
        })
    }
    
    @objc func fetchWalletBalance() {
        Lbry.apiCall(method: Lbry.methodWalletBalance, params: Dictionary<String, Any>(), connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                return
            }
            
            let result = data["result"] as! [String: Any]
            
            var balance = WalletBalance()
            balance.available = Decimal(string: result["available"] as! String)
            balance.reserved = Decimal(string: result["reserved"] as! String)
            balance.total = Decimal(string: result["total"] as! String)
            
            let reservedSubtotals = data["reserved_subtotals"] as? [String: Any]
            if (reservedSubtotals != nil) {
                balance.claims = Decimal(string: reservedSubtotals!["claims"] as! String)
                balance.supports = Decimal(string: reservedSubtotals!["supports"] as! String)
                balance.tips = Decimal(string: reservedSubtotals!["tips"] as! String)
            }
            
            Lbry.walletBalance = balance
            DispatchQueue.main.async {
                self.mainBalanceLabel.text = Helper.shortCurrencyFormat(value: balance.available)
                self.walletObservers.values.forEach{ observer in
                    observer.balanceUpdated(balance: balance)
                }
            }
        })
    }
    
    func handleSpecialUrl(url: String) -> Bool {
        if url.starts(with: "lbry://?") {
            let destination = String(url.suffix(from: url.index(url.firstIndex(of: "?")!, offsetBy: 1)))
            
            if destination.starts(with: "oauthcb") {
                OAuthSwift.handle(url: URL(string: url)!)
                return true
            }
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            if destination == "subscriptions" || destination == "subscription" || destination == "following" {
                appDelegate.mainTabViewController?.selectedIndex = 1
            } else if destination == "rewards" {
                let vc = self.storyboard?.instantiateViewController(identifier: "rewards_vc") as! RewardsViewController
                appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
            } else if destination == "wallet" {
                appDelegate.mainTabViewController?.selectedIndex = 2
            }
            
            // TODO: invite | invites | discover | channels | library
            
            return true
        }
        
        return false
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
