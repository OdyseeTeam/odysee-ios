//
//  YouTubeSyncStatusViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/02/2021.
//

import Firebase
import UIKit

class YouTubeSyncStatusViewController: UIViewController {

    @IBOutlet weak var cmStatusClaimYourHandle: UIImageView!
    @IBOutlet weak var cmStatusAgreeToSync: UIImageView!
    @IBOutlet weak var cmStatusWaitForVideos: UIImageView!
    @IBOutlet weak var cmStatusClaimYourChannel: UIImageView!
    
    @IBOutlet weak var claimChannelButton: UIButton!
    @IBOutlet weak var exploreOdyseeButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var claimHandleLabel: UILabel!
    @IBOutlet weak var syncVideoStat: UILabel!
    
    @IBOutlet weak var statusInfoLabel: UILabel!
    @IBOutlet weak var preTransferView: UIView!
    @IBOutlet weak var readyForTransferView: UIView!
    
    @IBOutlet weak var ytChannelNameLabel: UILabel!
    @IBOutlet weak var channelNameUploadsLabel: UILabel!
    
    var timer: Timer = Timer()
    var currentChannel: String? = nil
    let timerInterval: Double = 60 // 1 minute
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "YouTube Sync Status", AnalyticsParameterScreenClass: "YouTubeSyncStatusViewController"])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        claimChannelButton.setTitleColor(UIColor.systemGray5, for: .disabled)
        
        fetchSyncStatus()
        timer = Timer.scheduledTimer(timeInterval: timerInterval, target: self, selector: #selector(self.fetchSyncStatus), userInfo: nil, repeats: true)
    }
    
    func restoreButtons() {
        DispatchQueue.main.async {
            self.claimChannelButton.isEnabled = true
            self.claimChannelButton.isHidden = false
            self.exploreOdyseeButton.isHidden = false
            self.loadingIndicator.isHidden = true
        }
    }
    
    @IBAction func claimChannelTapped(_ sender: UIButton) {
        sender.isEnabled = false
        sender.isHidden = true
        exploreOdyseeButton.isHidden = true
        loadingIndicator.isHidden = false
        
        Lbry.apiCall(method: "address_list", params: [:], connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                self.restoreButtons()
                return
            }
            
            if let result = data["result"] as? [String: Any] {
                if let items = result["items"] as? [[String: Any]] {
                    if items.count > 0 {
                        let address = items[0]["address"] as! String
                        let publicKey = items[0]["pubkey"] as! String
                        self.transferChannel(address: address, publicKey: publicKey)
                        return
                    }
                }
            }
            
            self.showError(message: "The channel could not be claimed. Please email help@odysee.com for support.")
            self.restoreButtons()
        })
    }
    
    func transferChannel(address: String, publicKey: String) {
        do {
            let options = ["address": address, "public_key": publicKey]
            try Lbryio.call(resource: "yt", action: "transfer", options: options, method: Lbryio.methodPost, completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    self.restoreButtons()
                    return
                }
                if let channelList = data as? [[String: Any]] {
                    if channelList.count > 0 {
                        for item in channelList {
                            if let channelData = item["channel"] as? [String: Any] {
                                if channelData["lbry_channel_name"] as? String == self.currentChannel {
                                    if let channelCert = channelData["channel_certificate"] as? String {
                                        self.importChannel(channelCert)
                                        return
                                    }
                                }
                            }
                        }
                    }
                }
                
                self.showError(message: "The channel could not be claimed at this time. Please email help@odysee.com for support.")
                self.restoreButtons()
            })
        } catch let error {
            self.showError(error: error)
            self.restoreButtons()
        }
    }
    
    func importChannel(_ channelCert: String) {
        Lbry.apiCall(method: "channel_import", params: ["channel_data": channelCert], connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                self.showError(error: error)
                self.restoreButtons()
                return
            }
            
            self.finishClaimChannel()
        })
    }
    
    func finishClaimChannel() {
        DispatchQueue.main.async {
            self.showMessage(message: "You have successfully claimed your YouTube channel")
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainNavigationController?.popViewController(animated: true)
        }
    }
    @IBAction func exploreOdyseeTapped(_ sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainNavigationController?.popViewController(animated: true)
    }
    
    @objc func fetchSyncStatus() {
        do {
            claimChannelButton.isHidden = true
            exploreOdyseeButton.isHidden = true
            loadingIndicator.isHidden = false
            try Lbryio.call(resource: "yt", action: "transfer", options: [:], method: Lbryio.methodPost, completion: { data, error in
                guard let data = data, error == nil else {
                    //self.showError(error: error)
                    self.restoreButtons()
                    return
                }
                
                if let syncList = data as? [[String: Any]] {
                    if syncList.count > 0 {
                        let channel = syncList[0]
                        if let channelData = channel["channel"] as? [String: Any] {
                            self.updateSyncStatus(channelData)
                        }
                    }
                }
                self.restoreButtons()
            })
        } catch let error {
            self.showError(error: error)
            self.restoreButtons()
        }
    }
    
    func updateSyncStatus(_ channelData: [String: Any]) {
        DispatchQueue.main.async {
            let ytChannelName = channelData["yt_channel_name"] as? String
            let lbryChannelName = channelData["lbry_channel_name"] as? String
            let totalSubs = channelData["total_subs"] as? Int
            let totalVideos = channelData["total_videos"] as? Int
            let transferState = channelData["transfer_state"] as? String
            let transferable = channelData["transferable"] as? Bool
            let syncStatus = channelData["sync_status"] as? String
            
            self.preTransferView.isHidden = transferable ?? false
            self.readyForTransferView.isHidden = !(transferable ?? false)
            
            self.ytChannelNameLabel.text = ytChannelName
            self.channelNameUploadsLabel.text = String(format: String.localized(totalVideos == 1 ? "%@  %d upload" : "%@  %d uploads"), lbryChannelName!, totalVideos ?? 0)
            
            self.currentChannel = lbryChannelName
            self.claimHandleLabel.text = String(format: String.localized("Claim your handle %@"), lbryChannelName ?? "")
            self.syncVideoStat.text = String(format: String.localized("Syncing %d video(s) from your channel with %d subscription(s)."),
                                        totalVideos ?? 0, totalSubs ?? 0)
            self.cmStatusClaimYourHandle.image = UIImage.init(systemName: "checkmark.circle")
            self.cmStatusAgreeToSync.image = UIImage.init(systemName: "checkmark.circle")
            if syncStatus == "synced" {
                self.cmStatusWaitForVideos.image = UIImage.init(systemName: "checkmark.circle")
                if transferable ?? false && transferState != "transferred" {
                    self.claimChannelButton.isEnabled = true
                }
            }
            
            if transferable ?? false {
                self.statusInfoLabel.text = String.localized("Your videos are ready to be transferred.")
            }
            
            if transferState == "transferred" {
                self.cmStatusClaimYourChannel.image = UIImage.init(systemName: "checkmark.circle")
            }
        }
    }
    
    func showError(error: Error?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
        }
    }
    
    func showError(message: String) {
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
