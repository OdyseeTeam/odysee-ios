//
//  WalletSyncViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 04/12/2020.
//


import UIKit

// initial wallet sync processing after sign in / sign up
class WalletSyncViewController: UIViewController {

    var currentWalletSync: WalletSync? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.toggleMiniPlayer(hidden: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (appDelegate.player != nil) {
            appDelegate.mainController.toggleMiniPlayer(hidden: false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        checkWalletStatusForSync()
    }
    
    func checkWalletStatusForSync() {
        Lbry.apiCall(method: Lbry.methodWalletStatus, params: Dictionary<String, Any>(), connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            
            guard let data = data, error == nil else {
                print(error)
                return
            }
            
            var result = data["result"] as! [String: Any]
            let walletIsLocked = result["is_locked"] as! Bool
            if (walletIsLocked) {
                self.unlockWalletForSync()
            } else {
                self.obtainHashForSync()
            }
        })
    }
    
    func unlockWalletForSync() {
        var params = Dictionary<String, Any>()
        params["password"] = ""
        Lbry.apiCall(method: Lbry.methodWalletUnlock, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                print(error)
                return
            }
            
            var unlocked = data["result"] as! Bool
            if (unlocked) {
                print("unlocked wallet")
                self.obtainHashForSync()
            } else {
                // error
                print("failed woefully!")
            }
        })
    }
    
    func obtainHashForSync() {
        // start by calling sync_hash to get hash and data
        Lbry.apiCall(method: Lbry.methodSyncHash, params: Dictionary<String, Any>(), connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                print(error)
                return
            }
            
            let hash = data["result"] as! String
            Lbry.localWalletHash = hash
            self.startSync(hash: hash)
        })
    }
    
    func startSync(hash: String) {
        Lbryio.syncGet(hash: hash, completion: { walletSync, needsNewWallet, error in
            if error != nil {
                print(error)
                return
            }
            
            if (needsNewWallet ?? false) {
                print("processing new wallet")
                self.processNewWallet()
                return
            }
            
            Lbry.remoteWalletHash = walletSync?.hash
            self.currentWalletSync = walletSync
            self.processExistingWallet(password: "", walletSync: walletSync)
            return
        })
    }
    

    func processExistingWallet(password: String, walletSync: WalletSync?) {
        // first attempt at sync_apply to check if a password is required
        var params = Dictionary<String, Any>()
        params["password"] = password
        params["data"] = walletSync?.data
        params["blocking"] = true

        // start by calling sync_hash to get hash and data
        Lbry.apiCall(method: Lbry.methodSyncApply, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                // sync apply wasn't successful, ask the user to enter a password to unlock
                self.requestSyncApplyWithPassword()
                return
            }
            
            // sync apply was successful, so we can finish up
            self.closeWalletSync()
        })
    }
    
    func closeWalletSync() {
        DispatchQueue.main.async {
            // sync_apply was successful, we can proceed
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.startWalletBalanceTimer()
            
            let vcs = self.navigationController?.viewControllers;
            let targetVc = vcs![max(0, vcs!.count - 3)];
            self.navigationController?.popToViewController(targetVc, animated: true)
        }
    }
    
    func requestSyncApplyWithPassword() {
        print("i need to show password field")
    }
    
    
    func processNewWallet() {
        var params = Dictionary<String, Any>()
        params["password"] = ""
            
        // start by calling sync_hash to get hash and data
        Lbry.apiCall(method: Lbry.methodSyncApply, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                print(error)
                return
            }
            
            let result = data["result"] as! [String: Any]
            let hash = result["hash"] as! String
            let walletData = result["data"] as! String
            Lbryio.syncSet(oldHash: "", newHash: hash, data: walletData, completion: { remoteHash, error in
                guard let remoteHash = remoteHash, error == nil else {
                    print(error)
                    return
                }
                
                Lbry.remoteWalletHash = remoteHash
                
                // we successfully created a new wallet record, wrap up
                self.closeWalletSync()
            })
        })
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func handleSyncProcessError() {
        
    }
}
