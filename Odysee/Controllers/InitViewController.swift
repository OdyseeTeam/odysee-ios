//
//  InitViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import AVKit
import CoreData
import FirebaseAnalytics
import FirebaseCrashlytics
import UIKit

class InitViewController: UIViewController {
    @IBOutlet var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    var initErrorState = false

    // Init process flow
    // 1. loadExchangeRate
    // 2. loadAndCacheRemoteSubscriptions
    // 3. authenticateAndRegisterInstall
    func runInit() async {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Helper.keyHasRunAfterInstall) == nil {
            await AuthToken.reset()
            defaults.set(true, forKey: Helper.keyHasRunAfterInstall)
        }

        Lbry.installationId = defaults.string(forKey: Lbry.keyInstallationId)
        if Lbry.installationId.isBlank {
            Lbry.installationId = Lbry.generateId()
            defaults.set(Lbry.installationId, forKey: Lbry.keyInstallationId)
        }

        // Run singleton init side effects
        _ = await AuthToken.token

        Lbryio.loadExchangeRate(completion: { _, _ in
            // don't bother with error checks here, simply proceed to authenticate
            self.loadCategories()
        })
    }

    func loadCategories() {
        ContentSources.loadCategories(completion: { error in
            guard error == nil else {
                // Categories have to be properly loaded for the home page
                // If they are not properly loaded, display the startup error
                self.showError(error: error)
                return
            }

            self.loadAndCacheSubscriptions()
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await runInit() }

        errorView.layer.cornerRadius = 16
    }

    func authenticateAndRegisterInstall() {
        do {
            try Lbryio.fetchCurrentUser(completion: { user, error in
                if error != nil || user == nil {
                    if let error = error as? LbryioResponseError,
                       case let LbryioResponseError.error(_, code) = error,
                       code == 403
                    {
                        // invalidated auth token, get a new one
                        Lbryio.Defaults.reset()
                        Task { await AuthToken.reset() }
                        self.authenticateAndRegisterInstall()
                        return
                    }

                    // show a startup error message
                    self.initErrorState = true
                    self.showError(error: error) // TODO: Show more meaningful errors for /user/me failures?
                    return
                }

                if user != nil {
                    self.registerInstall()
                }
            })
        } catch {
            // user/me failed
            // show eror message
            initErrorState = true
            showError(error: error)
        }
    }

    func registerInstall() {
        Lbryio.newInstall(completion: { error in
            if error != nil {
                // show error
                self.initErrorState = true
                self.showError(error: error)
                return
            }

            // successful authentication and install registration
            // open the main application interface
            DispatchQueue.main.async {
                let main = self.storyboard?.instantiateViewController(identifier: "main_vc")
                if let window = self.view.window {
                    window.rootViewController = main
                    UIView.transition(
                        with: window,
                        duration: 0.2,
                        options: .transitionCrossDissolve,
                        animations: nil
                    )
                }
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

                if (data as? NSNull) != nil {
                    self.authenticateAndRegisterInstall()
                    return
                }

                if let subs = data as? [[String: Any]] {
                    for sub in subs {
                        do {
                            let jsonData = try JSONSerialization.data(
                                withJSONObject: sub,
                                options: [.prettyPrinted, .sortedKeys]
                            )
                            let subscription: LbrySubscription? = try JSONDecoder()
                                .decode(LbrySubscription.self, from: jsonData)
                            if let subscription,
                               let channelName = subscription.channelName,
                               let claimId = subscription.claimId,
                               let subUrl = LbryUri.tryParse(
                                   url: "\(channelName)#\(claimId)",
                                   requireProto: false
                               )
                            {
                                Lbryio.addSubscription(sub: subscription, url: subUrl.description)
                            }
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
        let fetchRequest = NSFetchRequest<Subscription>(entityName: "Subscription")
        fetchRequest.returnsObjectsAsFaults = false

        DispatchQueue.main.async {
            AppDelegate.shared.persistentContainer.performBackgroundTask { context in
                do {
                    let subs = try context.fetch(fetchRequest)
                    for sub in subs {
                        let cacheSub = LbrySubscription.fromLocalSubscription(subscription: sub)
                        if !cacheSub.claimId.isBlank {
                            Lbryio.addSubscription(sub: cacheSub, url: sub.url)
                        }
                    }
                } catch {
                    // pass
                }
            }
        }
    }

    func showLoading() {
        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = false
            self.errorView.isHidden = true
        }
    }

    func showError(error: Error?) {
        Crashlytics.crashlytics().recordImmediate(
            error: GenericError(""),
            userInfo: ["MESSAGE_KEY": error?.localizedDescription ?? ""]
        )

        DispatchQueue.main.async {
            self.loadingIndicator.isHidden = true
            self.errorView.isHidden = false
        }
    }

    @IBAction func retryTapped(_ sender: UIButton) {
        showLoading()
        initErrorState = false
        Lbryio.loadExchangeRate(completion: { _, _ in
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
