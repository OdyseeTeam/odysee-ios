//
//  WalletSyncViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/12/2020.
//

import FirebaseAnalytics
import UIKit

// initial wallet sync processing after sign in / sign up
class WalletSyncViewController: UIViewController {
    var firstRunFlow = false
    var currentWalletSync: SyncGetResult? // FIXME:
    var frDelegate: FirstRunDelegate?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
        AppDelegate.shared.mainController.toggleMiniPlayer(hidden: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        if AppDelegate.shared.lazyPlayer != nil {
            AppDelegate.shared.mainController.toggleMiniPlayer(hidden: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "WalletSync",
                AnalyticsParameterScreenClass: "WalletSyncViewController",
            ]
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        checkWalletStatusForSync()
    }

    func checkWalletStatusForSync() {
        Lbry.apiCall(
            method: Lbry.methodWalletStatus,
            params: [String: Any](),
            url: Lbry.lbrytvURL,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    return
                }

                if let result = data["result"] as? [String: Any],
                   let walletIsLocked = result["is_locked"] as? Bool,
                   walletIsLocked
                {
                    self.unlockWalletForSync()
                } else {
                    self.obtainHashForSync()
                }
            }
        )
    }

    func unlockWalletForSync() {
        var params = [String: Any]()
        params["password"] = ""
        Lbry.apiCall(
            method: Lbry.methodWalletUnlock,
            params: params,
            url: Lbry.lbrytvURL,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    return
                }

                if let unlocked = data["result"] as? Bool, unlocked {
                    self.obtainHashForSync()
                } else {
                    // error
                }
            }
        )
    }

    func obtainHashForSync() {
        // start by calling sync_hash to get hash and data
        Lbry.apiCall(
            method: Lbry.methodSyncHash,
            params: [String: Any](),
            url: Lbry.lbrytvURL,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    return
                }

                if let hash = data["result"] as? String {
                    Lbry.localWalletHash = hash
                    self.startSync(hash: hash)
                }
            }
        )
    }

    func startSync(hash: String) {
        Lbryio.syncGet(hash: hash, completion: { walletSync, needsNewWallet, error in
            if error != nil {
                self.showError(error: error)
                return
            }

            if needsNewWallet ?? false {
                self.processNewWallet()
                return
            }

            Lbry.remoteWalletHash = walletSync?.hash
            self.currentWalletSync = walletSync

            if walletSync?.data != nil, (walletSync?.changed ?? true) || Lbry.localWalletHash != Lbry.remoteWalletHash {
                self.processExistingWallet(password: "", walletSync: walletSync)
            } else {
                self.closeWalletSync()
            }
        })
    }

    func processExistingWallet(password: String, walletSync: SyncGetResult?) {
        // first attempt at sync_apply to check if a password is required
        var params = [String: Any]()
        params["password"] = password
        params["data"] = walletSync?.data
        params["blocking"] = true

        // start by calling sync_hash to get hash and data
        Lbry.apiCall(
            method: Lbry.methodSyncApply,
            params: params,
            url: Lbry.lbrytvURL,
            completion: { data, error in
                guard data != nil, error == nil else {
                    // sync apply wasn't successful, ask the user to enter a password to unlock
                    self.requestSyncApplyWithPassword()
                    return
                }

                // sync apply was successful, so we can finish up
                self.closeWalletSync()
            }
        )
    }

    func closeWalletSync() {
        DispatchQueue.main.async {
            // sync_apply was successful, we can proceed
            AppDelegate.shared.mainController.startWalletBalanceTimer()
            AppDelegate.shared.mainController.checkAndClaimEmailReward(completion: {})

            if self.firstRunFlow {
                self.frDelegate?.requestFinished(showSkip: true, showContinue: true)
                self.frDelegate?.nextStep()
            } else {
                if let vcs = self.navigationController?.viewControllers {
                    let index = max(0, vcs.count - 2)
                    var targetVc = vcs[index]
                    if targetVc == self {
                        targetVc = vcs[index - 1]
                    }
                    self.navigationController?.popToViewController(targetVc, animated: true)
                    self.checkAndShowYouTubeSync(popViewController: false)
                } else {
                    self.checkAndShowYouTubeSync(popViewController: true)
                }
            }
        }
    }

    func checkAndShowYouTubeSync(popViewController: Bool) {
        if popViewController {
            AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
        }
        guard !Lbryio.Defaults.isYouTubeSyncDone else {
            return
        }
        let vc = storyboard?.instantiateViewController(identifier: "yt_sync_vc") as! YouTubeSyncViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    func requestSyncApplyWithPassword() {}

    func processNewWallet() {
        var params = [String: Any]()
        params["password"] = ""

        // start by calling sync_hash to get hash and data
        Lbry.apiCall(
            method: Lbry.methodSyncApply,
            params: params,
            url: Lbry.lbrytvURL,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    return
                }

                if let result = data["result"] as? [String: Any] {
                    if let hash = result["hash"] as? String, let walletData = result["data"] as? String {
                        Lbryio.syncSet(oldHash: "", newHash: hash, data: walletData, completion: { remoteHash, error in
                            guard let remoteHash = remoteHash, error == nil else {
                                self.showError(error: error)
                                return
                            }

                            Lbry.remoteWalletHash = remoteHash

                            // we successfully created a new wallet record, wrap up
                            self.closeWalletSync()
                        })
                    }
                }
            }
        )
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
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

    func handleSyncProcessError() {}
}
