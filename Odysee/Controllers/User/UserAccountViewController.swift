//
//  UserAccountViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import FirebaseAnalytics
import UIKit

class UserAccountViewController: UIViewController {
    @IBOutlet var uaScrollView: UIScrollView!
    @IBOutlet var closeButton: UIButton!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var emailField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet var defaultActionButton: UIButton!
    @IBOutlet var controlsStackView: UIStackView!
    @IBOutlet var switchModeButton: UIButton!

    @IBOutlet var verificationLabel: UILabel!
    @IBOutlet var agreementLabel: UILabel!
    @IBOutlet var haveAccountLabel: UILabel!

    @IBOutlet var magicLinkButton: UIButton!
    @IBOutlet var verificationActionsView: UIView!

    var frDelegate: FirstRunDelegate?
    var firstRunFlow = false
    var signInMode = false
    var waitingForVerification = false
    var currentEmail: String?
    var emailVerified = false
    var emailSignInChecked = false
    var finishWalletSyncStarted = false
    var emailVerificationTimer = Timer()
    var requestInProgress: Bool = false

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
                AnalyticsParameterScreenName: "UserAccount",
                AnalyticsParameterScreenClass: "UserAccountViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        registerForKeyboardNotifications()
        emailField.layer.cornerRadius = 16
        emailField.layer.masksToBounds = true
        passwordField.layer.cornerRadius = 16
        passwordField.layer.masksToBounds = true

        defaultActionButton.layer.masksToBounds = true
        defaultActionButton.layer.cornerRadius = 16

        if firstRunFlow {
            closeButton.isHidden = true
        }
    }

    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        let height = UIScreen.main.bounds.height
        let width = UIScreen.main.bounds.width
        uaScrollView.contentSize = CGSize(width: width, height: height)
        haveAccountLabel.isHidden = true
        switchModeButton.isHidden = true
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        uaScrollView.contentInset = contentInsets
        uaScrollView.scrollIndicatorInsets = contentInsets

        haveAccountLabel.isHidden = false
        switchModeButton.isHidden = false
    }

    @IBAction func closeButtonTapped(_ sender: Any) {
        guard let navigationController else {
            showError(message: "Couldn't get navigation controller")
            return
        }
        let vcs = navigationController.viewControllers
        let index = max(0, vcs.count - 2)
        var targetVc = vcs[index]
        if targetVc == self {
            targetVc = vcs[index - 1]
        }
        if targetVc is NotificationsViewController {
            targetVc = vcs[index - 1]
        }
        if let tabVc = targetVc as? AppTabBarController {
            tabVc.selectedIndex = 0
        }
        navigationController.popToViewController(targetVc, animated: true)
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()

        if !signInMode {
            handleUserSignUp()
            return
        }

        handleUserSignIn()
    }

    @IBAction func magicLinkButtonTapped(_ sender: UIButton) {
        if currentEmail == nil {
            return
        }
        magicLinkButton.isEnabled = false
        handleEmailVerificationFlow(email: currentEmail)
    }

    func handleUserSignUp() {
        if requestInProgress {
            return
        }

        // check email and password fields are valid
        let email = emailField.text
        let password = passwordField.text

        if email.isBlank || password.isBlank {
            // show validation error
            showErrorAlert(message: String.localized("Please enter an email address and a password"))
            return
        }

        // disable the button
        defaultActionButton.isEnabled = false
        requestInProgress = true
        frDelegate?.requestStarted()

        do {
            var options = [String: String]()
            options["email"] = email
            options["password"] = password
            try Lbryio.post(resource: "user", action: "signup", options: options, completion: { data, error in
                DispatchQueue.main.async {
                    self.defaultActionButton.isEnabled = true
                }

                guard let data = data, error == nil else {
                    self.showError(error: error)
                    self.requestInProgress = false
                    self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                    return
                }

                if let stringData = data as? String {
                    if stringData.lowercased() == "ok" {
                        self.currentEmail = email

                        // display waiting for email verification view
                        self.waitForVerification()
                        self.requestInProgress = false
                        return
                    }
                }

                // possible invalid state
                self.requestInProgress = false
                self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                self.showErrorAlert(message: String.localized("An unknown error occurred. Please try again."))
            })
        } catch {
            requestInProgress = false
            frDelegate?.requestFinished(showSkip: true, showContinue: false)
            showError(error: error)
        }
    }

    @IBAction func switchMode(_ sender: Any) {
        if signInMode {
            enableSignUpMode()
        } else {
            enableSignInMode()
        }
    }

    func enableSignInMode() {
        haveAccountLabel.text = String.localized("Don't have an account?")
        switchModeButton.setTitle(String.localized("Sign Up"), for: .normal)
        titleLabel.text = String.localized("Log In to Odysee")
        defaultActionButton.setTitle(String.localized("Continue"), for: .normal)

        passwordField.textContentType = .password
        passwordField.isHidden = true
        agreementLabel.isHidden = true
        signInMode = true
    }

    func enableSignUpMode() {
        haveAccountLabel.text = String.localized("Already have an account?")
        switchModeButton.setTitle(String.localized("Log In"), for: .normal)
        titleLabel.text = String.localized("Join Odysee")
        defaultActionButton.setTitle(String.localized("Sign Up"), for: .normal)

        passwordField.textContentType = .newPassword
        passwordField.isHidden = false
        agreementLabel.isHidden = false
        signInMode = false
    }

    func waitForVerification() {
        DispatchQueue.main.async { [self] in
            waitingForVerification = true
            frDelegate?.requestStarted()

            controlsStackView.isHidden = true
            haveAccountLabel.isHidden = true
            closeButton.isHidden = true
            verificationLabel.isHidden = false
            verificationActionsView.isHidden = false

            // start timer to periodically check if the user is verified
            emailVerificationTimer = Timer.scheduledTimer(
                timeInterval: 5,
                target: self,
                selector: #selector(checkEmailVerification),
                userInfo: nil,
                repeats: true
            )
        }
    }

    @objc func checkEmailVerification() {
        do {
            try Lbryio.fetchCurrentUser(completion: { user, error in
                guard let user = user, error == nil else {
                    // user verification failed
                    self.showError(error: error)
                    return
                }

                if user.hasVerifiedEmail ?? false {
                    // stop the timer
                    self.emailVerificationTimer.invalidate()

                    // close the view
                    DispatchQueue.main.async {
                        AppDelegate.shared.mainController.checkUploadButton()

                        // after email verification, finish with wallet sync
                        self.finishWithWalletSync()
                    }
                }
            })
        } catch {
            showError(error: error)
        }
    }

    func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showErrorAlert(message: message)
        }
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }

    func handleUserSignIn() {
        if requestInProgress {
            return
        }

        let email = emailField.text

        if email.isBlank {
            // show validation error
            showErrorAlert(message: String.localized("Please enter your email address"))
            return
        }

        if !emailSignInChecked {
            do {
                requestInProgress = true
                frDelegate?.requestStarted()
                var options = [String: String]()
                options["email"] = email
                try Lbryio.post(resource: "user", action: "exists", options: options, completion: { data, error in
                    guard let data = data, error == nil else {
                        if let error = error as? LbryioResponseError,
                           case let LbryioResponseError.error(_, code) = error
                        {
                            if code == 412 {
                                // old email verification flow
                                self.currentEmail = email
                                self.handleUserSignInWithoutPassword(email: email)
                            } else {
                                DispatchQueue.main.async {
                                    self.defaultActionButton.isEnabled = true
                                }
                                self.showError(error: error)
                            }
                        }
                        self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                        self.requestInProgress = false
                        return
                    }

                    self.currentEmail = email

                    self.emailSignInChecked = true
                    guard let respData = data as? [String: Any],
                          let hasPassword = respData["has_password"] as? Bool,
                          hasPassword
                    else {
                        self.handleUserSignInWithoutPassword(email: email)
                        return
                    }

                    // email exists, and we can use sign in flow, show the password field
                    DispatchQueue.main.async {
                        self.defaultActionButton.isEnabled = true
                        self.defaultActionButton.setTitle(String.localized("Sign In"), for: .normal)
                        self.passwordField.isHidden = false
                        self.magicLinkButton.isHidden = false

                        self.emailField.resignFirstResponder()
                        self.passwordField.resignFirstResponder()
                        self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                        self.requestInProgress = false
                    }
                })
            } catch {
                requestInProgress = false
                frDelegate?.requestFinished(showSkip: true, showContinue: false)
                showError(error: error)
            }

            return
        }

        // password entry flow
        guard let passwordValue = passwordField.text, !passwordValue.isBlank else {
            showErrorAlert(message: String.localized("Please enter your password"))
            return
        }

        var options = [String: String]()
        options["email"] = email
        options["password"] = passwordValue
        do {
            requestInProgress = true
            frDelegate?.requestStarted()
            try Lbryio.post(resource: "user", action: "signin", options: options, completion: { data, error in
                DispatchQueue.main.async {
                    self.defaultActionButton.isEnabled = true
                }

                guard let data = data, error == nil else {
                    if let error = error as? LbryioResponseError,
                       case let LbryioResponseError.error(_, code) = error
                    {
                        self.requestInProgress = false
                        if code == 409 {
                            self.handleEmailVerificationFlow(email: email)
                            return
                        }
                    }

                    self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                    self.requestInProgress = false
                    self.showError(error: error)
                    return
                }

                do {
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: data as Any,
                        options: [.prettyPrinted, .sortedKeys]
                    )
                    let user: User? = try JSONDecoder().decode(User.self, from: jsonData)
                    if let user {
                        Lbryio.currentUser = user
                        if let id = user.id {
                            Analytics.setDefaultEventParameters(["user_id": id])
                        }

                        self.requestInProgress = false
                        self.finishWithWalletSync()
                        return
                    }
                } catch {
                    self.showError(error: error)
                }

                // possible invalid state
                self.requestInProgress = false
                self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                self.showErrorAlert(message: String.localized("An unknown error occurred. Please try again."))
            })
        } catch {
            requestInProgress = false
            frDelegate?.requestFinished(showSkip: true, showContinue: false)
            showError(error: error)
        }
    }

    func handleEmailVerificationFlow(email: String?) {
        do {
            var options = [String: String]()
            options["email"] = email
            options["only_if_expired"] = "true"
            try Lbryio.post(
                resource: "user_email",
                action: "resend_token",
                options: options,
                completion: { data, error in
                    guard data != nil, error == nil else {
                        self.showError(error: error)
                        return
                    }

                    self.waitForVerification()
                }
            )
        } catch {
            showError(error: error)
        }
    }

    func handleUserSignInWithoutPassword(email: String?) {
        do {
            var options = [String: String]()
            options["email"] = email
            options["send_verification_email"] = "true"
            try Lbryio.post(resource: "user_email", action: "new", options: options, completion: { data, error in
                guard data != nil, error == nil else {
                    if let error = error as? LbryioResponseError,
                       case let LbryioResponseError.error(_, code) = error
                    {
                        if code == 409 {
                            self.handleEmailVerificationFlow(email: email)
                        } else {
                            self.showError(error: error)
                        }
                    }
                    return
                }

                self.waitForVerification()
            })
        } catch {
            showError(error: error)
        }
    }

    @IBAction func resendEmailTapped(_ sender: UIButton) {
        handleEmailVerificationFlow(email: currentEmail)
    }

    @IBAction func startOverTapped(_ sender: UIButton) {
        emailVerificationTimer.invalidate()
        currentEmail = nil
        waitingForVerification = false
        frDelegate?.requestFinished(showSkip: true, showContinue: false)

        emailField.text = ""
        passwordField.text = ""

        Lbryio.Defaults.reset()
        Task { await AuthToken.reset() }

        UserDefaults.standard.removeObject(forKey: Helper.keyReceiveAddress)

        controlsStackView.isHidden = false
        haveAccountLabel.isHidden = false
        closeButton.isHidden = firstRunFlow
        verificationLabel.isHidden = true
        verificationActionsView.isHidden = true

        magicLinkButton.isHidden = true
        magicLinkButton.isEnabled = true
    }

    func finishWithWalletSync() {
        if finishWalletSyncStarted {
            return
        }

        finishWalletSyncStarted = true

        Task { await Wallet.shared.startSync() }

        DispatchQueue.main.async {
            AppDelegate.shared.mainController.checkUploadButton()
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

    // dismiss soft keyboard when anywhere in the view (outside of text fields) is tapped
    @IBAction func anywhereTapped(_ sender: Any) {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
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
