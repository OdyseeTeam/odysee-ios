//
//  UserAccountViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import Firebase
import UIKit

class UserAccountViewController: UIViewController {

    @IBOutlet weak var uaScrollView: UIScrollView!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var defaultActionButton: UIButton!
    @IBOutlet weak var controlsStackView: UIStackView!
    
    @IBOutlet weak var verificationLabel: UILabel!
    @IBOutlet weak var agreementLabel: UILabel!
    @IBOutlet weak var haveAccountLabel: UILabel!
    
    @IBOutlet weak var magicLinkButton: UIButton!
    @IBOutlet weak var verificationActionsView: UIView!
    
    var signInMode = false
    var waitingForVerification = false
    var currentEmail: String? = nil
    var emailVerified = false
    var emailSignInChecked = false
    var emailVerificationTimer: Timer = Timer()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        let window = UIApplication.shared.windows.filter{ $0.isKeyWindow }.first!
        let safeAreaFrame = window.safeAreaLayoutGuide.layoutFrame
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: window.frame.maxY - safeAreaFrame.maxY + 2)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "UserAccount", AnalyticsParameterScreenClass: "UserAccountViewController"])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        registerForKeyboardNotifications()
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
        uaScrollView.contentInset = contentInsets
        uaScrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        uaScrollView.contentInset = contentInsets
        uaScrollView.scrollIndicatorInsets = contentInsets
    }
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        let vcs = self.navigationController?.viewControllers;
        let targetVc = vcs![max(0, vcs!.count - 2)];
        if let tabVc =  targetVc as? AppTabBarController {
            tabVc.selectedIndex = 0
        }
        self.navigationController?.popToViewController(targetVc, animated: true)
    }
    
    @IBAction func actionButtonTapped(_ sender: UIButton) {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        if (!signInMode) {
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
        // check email and password fields are valid
        let email = emailField.text
        let password = passwordField.text
        
        if (email ?? "").isBlank || (password ?? "").isBlank {
            // show validation error
            self.showError(message: String.localized("Please enter an email address and a password"))
            return
        }
        
        // disable the button
        defaultActionButton.isEnabled = false
        
        do {
            var options = Dictionary<String, String>()
            options["email"] = email
            options["password"] = password
            try Lbryio.call(resource: "user", action: "signup", options: options, method: Lbryio.methodPost, completion: { data, error in
                DispatchQueue.main.async {
                    self.defaultActionButton.isEnabled = true
                }
                
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    return
                }
                
                if let stringData = data as? String {
                    if "ok" == stringData.lowercased() {
                        self.currentEmail = email
                        Analytics.logEvent("email_added", parameters: ["email": self.currentEmail!])
                        
                        // display waiting for email verification view
                        self.waitForVerification()
                        return
                    }
                }
                
                // possible invalid state
                self.showError(message: String.localized("An unknown error occurred. Please try again."))
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    @IBAction func switchMode(_ sender: Any) {
        if (signInMode) {
            enableSignUpMode()
        } else {
            enableSignInMode()
        }
    }
    
    func enableSignInMode() {
        haveAccountLabel.text = String.localized("Don't have an account? Sign Up.")
        titleLabel.text = String.localized("Log In to Odysee")
        defaultActionButton.setTitle(String.localized("Continue"), for: .normal)
        
        passwordField.isHidden = true
        agreementLabel.isHidden = true
        signInMode = true
    }
    
    func enableSignUpMode() {
        haveAccountLabel.text = String.localized("Already have an account? Log In.")
        titleLabel.text = String.localized("Join Odysee")
        defaultActionButton.setTitle(String.localized("Sign Up"), for: .normal)
        
        passwordField.isHidden = false
        agreementLabel.isHidden = false
        signInMode = false
    }
    
    func waitForVerification() {
        DispatchQueue.main.async { [self] in
            self.waitingForVerification = true
            
            self.controlsStackView.isHidden = true
            self.haveAccountLabel.isHidden = true
            self.closeButton.isHidden = true
            self.verificationLabel.isHidden = false
            self.verificationActionsView.isHidden = false
            
            // start timer to periodically check if the user is verified
            self.emailVerificationTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.checkEmailVerification), userInfo: nil, repeats: true)
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
                
                if (user.hasVerifiedEmail!) {
                    // stop the timer
                    self.emailVerificationTimer.invalidate()
                    
                    // close the view
                    DispatchQueue.main.async {
                        Analytics.logEvent("email_verified", parameters: ["email": self.currentEmail!])
                        
                        // after email verification, finish with wallet sync
                        self.finishWithWalletSync()
                    }
                }
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    func showError(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(message: message)
        }
    }
    
    func showError(error: Error?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showError(error: error)
        }
    }
    
    func handleUserSignIn() {
        let email = emailField.text
        
        if (email ?? "").isBlank {
            // show validation error
            self.showError(message: String.localized("Please enter your email address"))
            return
        }
        
        if (!emailSignInChecked) {
            do {
                var options = Dictionary<String, String>()
                options["email"] = email
                try Lbryio.call(resource: "user", action: "exists", options: options, method: Lbryio.methodPost, completion: { data, error in
                    guard let data = data, error == nil else {
                        if let responseError = error as? LbryioResponseError {
                            print(responseError.code)
                            if responseError.code == 412 {
                                // old email verification flow
                                self.currentEmail = email
                                self.handleUserSignInWithoutPassword(email: email)
                                Analytics.logEvent("email_added", parameters: ["email": self.currentEmail!])
                            } else {
                                DispatchQueue.main.async {
                                    self.defaultActionButton.isEnabled = true
                                }
                                self.showError(error: error)
                            }
                        }
                        return
                    }
                    
                    self.currentEmail = email
                    Analytics.logEvent("email_added", parameters: ["email": self.currentEmail!])
                    
                    self.emailSignInChecked = true
                    let respData = data as? [String: Any]
                    let hasPassword = respData!["has_password"] as! Bool
                    if (!hasPassword) {
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
                    }
                })
            } catch let error {
                self.showError(error: error)
            }
            
            return
        }
        
        // password entry flow
        if (passwordField.text ?? "").isBlank {
            self.showError(message: String.localized("Please enter your password"))
            return
        }
        
        var options = Dictionary<String, String>()
        options["email"] = email
        options["password"] = passwordField.text!
        do {
            try Lbryio.call(resource: "user", action: "signin", options: options, method: Lbryio.methodPost, completion: { data, error in
                DispatchQueue.main.async {
                    self.defaultActionButton.isEnabled = true
                }
                
                guard let data = data, error == nil else {
                    if let responseError = error as? LbryioResponseError {
                        if responseError.code == 409 {
                            self.handleEmailVerificationFlow(email: email)
                            return
                        }
                    }
                    
                    self.showError(error: error)
                    return
                }
                
                do {
                    let jsonData = try! JSONSerialization.data(withJSONObject: data as Any, options: [.prettyPrinted, .sortedKeys])
                    let user: User? = try JSONDecoder().decode(User.self, from: jsonData)
                    if (user != nil) {
                        Lbryio.currentUser = user
                        Analytics.setDefaultEventParameters([
                            "user_id": user!.id!,
                            "user_email": user!.primaryEmail ?? ""
                        ])
                        self.finishWithWalletSync()
                        return
                    }
                } catch {
                    // pass
                }
                
                // possible invalid state
                self.showError(message: String.localized("An unknown error occurred. Please try again."))
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    func handleEmailVerificationFlow(email: String?) {
        do {
            var options = Dictionary<String, String>()
            options["email"] = email
            options["only_if_expired"] = "true"
            try Lbryio.call(resource: "user_email", action: "resend_token", options: options, method: Lbryio.methodPost, completion: { data, error in
                guard let _ = data, error == nil else {
                    self.showError(error: error)
                    return
                }
                
                self.waitForVerification()
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    func handleUserSignInWithoutPassword(email: String?) {
        do {
            var options = Dictionary<String, String>()
            options["email"] = email
            options["send_verification_email"] = "true"
            try Lbryio.call(resource: "user_email", action: "new", options: options, method: Lbryio.methodPost, completion: { data, error in
                guard let _ = data, error == nil else {
                    if let responseError = error as? LbryioResponseError {
                        if responseError.code == 409 {
                            self.handleEmailVerificationFlow(email: email)
                        } else {
                            self.showError(error: error)
                        }
                    }
                    return
                }
                
                self.waitForVerification()
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    @IBAction func resendEmailTapped(_ sender: UIButton) {
        handleEmailVerificationFlow(email: currentEmail)
    }
    @IBAction func startOverTapped(_ sender: UIButton) {
        emailVerificationTimer.invalidate()
        currentEmail = nil
        waitingForVerification = false
        
        emailField.text = ""
        passwordField.text = ""
        
        controlsStackView.isHidden = false
        haveAccountLabel.isHidden = false
        closeButton.isHidden = false
        verificationLabel.isHidden = true
        verificationActionsView.isHidden = true
        
        magicLinkButton.isHidden = true
        magicLinkButton.isEnabled = true
    }
    
    func finishWithWalletSync() {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = self.storyboard?.instantiateViewController(identifier: "wallet_sync_vc") as! WalletSyncViewController
            appDelegate.mainNavigationController?.popViewController(animated: false)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
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
