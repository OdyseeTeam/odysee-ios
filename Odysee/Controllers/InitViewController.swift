//
//  InitViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import UIKit

class InitViewController: UIViewController {

    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    // Init process flow
    // 1. loadExchangeRate
    // 2. loadAndCacheRemoteSubscriptions
    // 3. authenticateAndRegisterInstall
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let defaults = UserDefaults.standard
        Lbry.installationId = defaults.string(forKey: Lbry.keyInstallationId)
        if ((Lbry.installationId ?? "").isBlank) {
            Lbry.installationId = Lbry.generateId()
            defaults.set(Lbry.installationId, forKey: Lbry.keyInstallationId)
        }
        
        Lbryio.authToken = defaults.string(forKey: Lbryio.keyAuthToken)
        if (Lbryio.authToken == nil) {
            print("******** No AuthToken in UserDefaults.standard")
        } else {
            print("********" + Lbryio.authToken!)
        }
        
        Lbryio.loadExchangeRate(completion: { rate, error in
            // don't bother with error checks here, simply proceed to authenticate
            self.loadAndCacheSubscriptions()
        })
    }
    
    func authenticateAndRegisterInstall() {
        do {
            try Lbryio.fetchCurrentUser(completion: { user, error in
                if (error != nil || user == nil) {
                    // show a startup error message
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
            showError()
        }
    }
    
    func registerInstall() {
        Lbryio.newInstall(completion: { error in
            if (error != nil) {
                // show error
                print(error!)
                self.showError()
                return
            }
            
            // successful authentication and install registration
            // open the main application interface
            DispatchQueue.main.async {
                let main = self.storyboard?.instantiateViewController(identifier: "main_vc") as! UIViewController
                main.modalPresentationStyle = .currentContext
                self.present(main, animated: true)
            }
        })
    }
    
    // we only want to cache the URLs for followed channels (both local and remote) here
    func loadAndCacheSubscriptions() {
        do {
            try Lbryio.call(resource: "subscription", action: "list", options: nil, method: Lbryio.methodGet, completion: { data, error in
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
    
    func showError() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
            self.errorLabel.isHidden = false
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
