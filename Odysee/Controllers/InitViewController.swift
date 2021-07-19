//
//  InitViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import AVKit
import CoreData
import UIKit

class InitViewController: UIViewController {

    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    var initErrorState = false
    
    // Init process flow
    // 1. loadExchangeRate
    // 2. loadAndCacheRemoteSubscriptions
    // 3. authenticateAndRegisterInstall
    func runInit() {
        let defaults = UserDefaults.standard
        Lbry.installationId = defaults.string(forKey: Lbry.keyInstallationId)
        if ((Lbry.installationId ?? "").isBlank) {
            Lbry.installationId = Lbry.generateId()
            defaults.set(Lbry.installationId, forKey: Lbry.keyInstallationId)
        }
        
        Lbryio.authToken = Lbryio.Defaults.authToken
        
        Lbryio.loadExchangeRate(completion: { rate, error in
            // don't bother with error checks here, simply proceed to authenticate
            self.loadAndCacheSubscriptions()
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.runInit()
        
        errorView.layer.cornerRadius = 16
    }
    
    func authenticateAndRegisterInstall() {
        do {
            try Lbryio.fetchCurrentUser(completion: { user, error in
                if (error != nil || user == nil) {
                    // show a startup error message
                    self.initErrorState = true
                    self.showError() // TODO: Show more meaningful errors for /user/me failures?
                    return
                }
                
                if (user != nil) {
                    self.registerInstall()
                }
            })
        } catch {
            // user/me failed
            // show eror message
            initErrorState = true
            showError()
        }
    }
    
    func registerInstall() {
        Lbryio.newInstall(completion: { error in
            if (error != nil) {
                // show error
                self.initErrorState = true
                self.showError()
                return
            }
            
            // successful authentication and install registration
            // open the main application interface
            DispatchQueue.main.async {
                let main = self.storyboard!.instantiateViewController(identifier: "main_vc")
                let window = self.view.window!
                window.rootViewController = main
                UIView.transition(with: window, duration: 0.2,
                                  options: .transitionCrossDissolve, animations: nil)
            }
        })
    }
    
    // we only want to cache the URLs for followed channels (both local and remote) here
    func loadAndCacheSubscriptions() {
        do {
            // load local subscriptions
            loadLocalSubscriptions()
            
            // check if there are remote subscriptions and load them too
            try Lbryio.get(resource: "subscription", action: "list", completion: { data, error in
                guard let data = data, error == nil else {
                    self.authenticateAndRegisterInstall()
                    return
                }
                
                if ((data as? NSNull) != nil) {
                    self.authenticateAndRegisterInstall()
                    return
                }
                
                if let subs = data as? [[String: Any]] {
                    for sub in subs {
                        let jsonData = try! JSONSerialization.data(withJSONObject: sub, options: [.prettyPrinted, .sortedKeys])
                        do {
                            let subscription: LbrySubscription? = try JSONDecoder().decode(LbrySubscription.self, from: jsonData)
                            let channelName = subscription!.channelName!
                            let subUrl = LbryUri.tryParse(url: String(format: "%@#%@", channelName, subscription!.claimId!), requireProto: false)
                            Lbryio.addSubscription(sub: subscription!, url: subUrl!.description)
                        } catch {
                            // skip the sub if it failed to parse
                        }
                    }
                }
                
                self.authenticateAndRegisterInstall()
            })
        } catch {
            // simply continue if it fails
            authenticateAndRegisterInstall()
        }
    }
    
    func loadLocalSubscriptions() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Subscription")
        fetchRequest.returnsObjectsAsFaults = false
        let asyncFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { asyncFetchResult in
            guard let subscriptions = asyncFetchResult.finalResult as? [Subscription] else { return }
            for sub in subscriptions {
                let cacheSub = LbrySubscription.fromLocalSubscription(subscription: sub)
                if !(cacheSub.claimId ?? "").isBlank {
                    Lbryio.addSubscription(sub: cacheSub, url: sub.url)
                }
            }
        }
        
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.newBackgroundContext()
            do {
                try context.execute(asyncFetchRequest)
            } catch {
                // pass
            }
        }
    }
    
    func showLoading() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = false
            self.errorView.isHidden = true
        }
    }
    
    func showError() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
            self.errorView.isHidden = false
        }
    }
    
    @IBAction func retryTapped(_ sender: UIButton) {
        showLoading()
        initErrorState = false
        Lbryio.loadExchangeRate(completion: { rate, error in
            // don't bother with error checks here, simply proceed to authenticate
            self.loadAndCacheSubscriptions()
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

}
