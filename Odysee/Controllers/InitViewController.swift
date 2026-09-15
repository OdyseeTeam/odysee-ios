//
//  InitViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/11/2020.
//

import AVKit
import FirebaseCrashlytics
import FirebaseMessaging
import UIKit

class InitViewController: UIViewController {
    @IBOutlet var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

    // FIXME: Doc
    /// Init process flow
    /// 1. Load/Generate installationId
    /// 2. loadCategories
    /// 3. Load/Generate auth token
    /// 4. Authenticate (may regenerate invalidated auth token)
    /// 5. Register install (Lbryio analytics, FCM token)
    /// 6. Switch to MainViewController
    func runInit() async {
        do {
            try await ContentSources.loadCategories()

            // FIXME: If fails to load, fail open or closed?
            // At the moment is fail open (all content allowed) and will just log error
            // FIXME: Combine with loading categories?
            try await ClaimFiltering.shared.loadAll()
        } catch {
            // Just log this error, but proceed with placeholder discover category
            logError(error: error)
        }

        do {
            while true {
                // Singleton init loads/generates auth token
                _ = await AuthToken.token

                do {
                    // Load current user; which loads Globals, starts wallet balance loop, and Wallet sync
                    try await Account.shared.loadCurrentUser()

                    break
                } catch LbryioResponseError.error(_, 403) {
                    // invalidated auth token, get a new one
                    Lbryio.Defaults.reset()
                    await AuthToken.reset()
                }
            }

            try await registerInstall()

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
        } catch {
            // Errors in this flow need to be retried, the app can't be used without an auth token
            showError(error: error)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await runInit() }

        errorView.layer.cornerRadius = 16
    }

    func registerInstall() async throws {
        guard let appId = UserDefaults.standard.string(forKey: AuthToken.keyAppId), !appId.isBlank else {
            throw LbryioRequestError.runtimeError("The installation ID is not set")
        }

        var token: String? = nil
        do {
            token = try await Messaging.messaging().token()
        } catch {
            // no need to fail on error here
            logError(error: error)
        }

        _ = try await AccountMethods.installNew.call(params: .init(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            appId: appId,
            firebaseToken: token
        ))
    }

    func showLoading() {
        loadingIndicator.isHidden = false
        errorView.isHidden = true
    }

    func showError(error: Error) {
        logError(error: error)

        errorLabel.text = error.localizedDescription

        loadingIndicator.isHidden = true
        errorView.isHidden = false
    }

    func logError(error: Error) {
        Crashlytics.crashlytics().recordImmediate(
            error: error,
            userInfo: ["MESSAGE_KEY": error.localizedDescription]
        )
    }

    @IBAction func retryTapped(_ sender: UIButton) {
        showLoading()
        Task { await runInit() }
    }
}
