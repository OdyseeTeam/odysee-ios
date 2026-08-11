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

    /// Init process flow
    /// 1. Load/Generate installationId
    /// 2. loadCategories
    /// 3. Load/Generate auth token
    /// 4. Authenticate (may regenerate invalidated auth token)
    /// 5. Register install (Lbryio analytics, FCM token)
    /// 6. Switch to MainViewController
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

        do {
            try await ContentSources.loadCategories()
        } catch {
            // Just log this error, but proceed with placeholder discover category
            logError(error: error)
        }

        do {
            // Singleton init loads/generates auth token
            _ = await AuthToken.token

            try await authenticate()

            try await registerInstall()

            // Singleton init loads Wallet and SharedPreference data
            _ = Wallet.shared

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

    /// fetchCurrentUser (through `AccountMethods/.../call`) will generate an AuthToken if none is stored
    func authenticate() async throws {
        do {
            // Sets Analytics user_id
            _ = try await Lbryio.fetchCurrentUser()
        } catch LbryioResponseError.error(_, 403) {
            // invalidated auth token, get a new one
            Lbryio.Defaults.reset()
            await AuthToken.reset()

            try await authenticate()
        }
    }

    func registerInstall() async throws {
        guard let installationId = Lbry.installationId, !installationId.isBlank else {
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
            appId: installationId,
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
