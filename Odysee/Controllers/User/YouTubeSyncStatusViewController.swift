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
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var claimHandleLabel: UILabel!
    @IBOutlet weak var syncVideoStat: UILabel!
    
    var timer: Timer = Timer()
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
    
    @IBAction func claimChannelTapped(_ sender: UIButton) {
        
    }
    
    @IBAction func exploreOdyseeTapped(_ sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainNavigationController?.popViewController(animated: true)
    }
    
    @objc func fetchSyncStatus() {
        do {
            try Lbryio.call(resource: "yt", action: "transfer", options: [:], method: Lbryio.methodPost, completion: { data, error in
                guard let data = data, error == nil else {
                    //self.showError(error: error)
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
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    func updateSyncStatus(_ channelData: [String: Any]) {
        DispatchQueue.main.async {
            //let ytChannelName = channelData["yt_channel_name"] as? String
            let lbryChannelName = channelData["lbry_channel_name"] as? String
            let totalSubs = channelData["total_subs"] as? Int
            let totalVideos = channelData["total_videos"] as? Int
            let transferState = channelData["transfer_state"] as? String
            let transferable = channelData["transferable"] as? Bool
            let syncStatus = channelData["sync_status"] as? String
            
            self.claimHandleLabel.text = String(format: String.localized("Claim your handle %@"), lbryChannelName ?? "")
            self.syncVideoStat.text = String(format: String.localized("Syncing %d video(s) from your channel with %d subscription(s)."),
                                        totalVideos ?? 0, totalSubs ?? 0)
            self.cmStatusClaimYourHandle.image = UIImage.init(systemName: "checkmark.circle")
            self.cmStatusAgreeToSync.image = UIImage.init(systemName: "checkmark.circle")
            if syncStatus == "done" {
                self.cmStatusWaitForVideos.image = UIImage.init(systemName: "checkmark.circle")
                if transferable ?? false && transferState != "transferred" {
                    self.claimChannelButton.isEnabled = true
                }
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
