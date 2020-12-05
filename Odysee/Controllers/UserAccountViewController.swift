//
//  UserAccountViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import UIKit

class UserAccountViewController: UIViewController {

    @IBOutlet weak var uaScrollView: UIScrollView!
    @IBOutlet weak var closeView: UIView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var defaultActionButton: UIButton!
    @IBOutlet weak var controlsStackView: UIStackView!
    
    @IBOutlet weak var verificationLabel: UILabel!
    @IBOutlet weak var agreementLabel: UILabel!
    @IBOutlet weak var haveAccountLabel: UILabel!
    
    @IBOutlet weak var verificationActionsView: UIView!
    @IBOutlet weak var resendEmailButton: UIButton!
    @IBOutlet weak var startOverButton: UIButton!
    
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
    
    @IBAction func closeUAView(_ sender: Any) {
        let vcs = self.navigationController?.viewControllers;
        let targetVc = vcs![max(0, vcs!.count - 2)];
        if let tabVc =  targetVc as? AppTabBarController {
            tabVc.selectedIndex = 0
        }
        self.navigationController?.popToViewController(targetVc, animated: true)
    }
    
    @IBAction func actionButtonTapped(_ sender: UIButton) {
        if (!signInMode) {
            handleUserSignUp()
            return
        }
        
        handleUserSignIn()
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
                    var message = error?.localizedDescription
                    if let responseError = error as? LbryioResponseError {
                        message = responseError.message
                    }
                    self.showError(message: message)
                    return
                }
                
                if let stringData = data as? String {
                    if "ok" == stringData.lowercased() {
                        // display waiting for email verification view
                        self.waitForVerification()
                        return
                    }
                }
                
                // possible invalid state
                self.showError(message: String.localized("An unknown error occurred. Please try again."))
            })
        } catch let error {
            print(error)
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
            self.closeView.isHidden = true
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
                    self.showError(message: error?.localizedDescription)
                    return
                }
                
                if (user.hasVerifiedEmail!) {
                    // stop the timer
                    self.emailVerificationTimer.invalidate()
                    
                    // close the view
                    DispatchQueue.main.async {
                        // after email verification, finish with wallet sync
                        self.finishWithWalletSync()
                    }
                }
            })
        } catch let error {
            self.showError(message: error.localizedDescription)
        }
    }
    
    func showError(message: String?) {
        DispatchQueue.main.async {
            let sb = Snackbar()
            sb.sbLength = .long
            sb.backgroundColor = UIColor.red
            sb.textColor = UIColor.white
            sb.createWithText(message ?? "")
            sb.show()
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
                            } else {
                                DispatchQueue.main.async {
                                    self.defaultActionButton.isEnabled = true
                                }
                                self.showError(message: error?.localizedDescription)
                            }
                        }
                        return
                    }
                    
                    self.currentEmail = email
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
                    }
                })
            } catch let error {
                self.showError(message: error.localizedDescription)
            }
            
            return
        }
        
        // password entry flow
        if (passwordField.text ?? "").isBlank {
            self.showError(message: String.localized("Please enter your password"))
            return
        }
    }
    
    func handleEmailExistsFlow(email: String?) {
        do {
            var options = Dictionary<String, String>()
            options["email"] = email
            options["only_if_expired"] = "true"
            try Lbryio.call(resource: "user_email", action: "resend_token", options: options, method: Lbryio.methodPost, completion: { data, error in
                guard let _ = data, error == nil else {
                    self.showError(message: error?.localizedDescription)
                    return
                }
                
                self.waitForVerification()
            })
        } catch let error {
            self.showError(message: error.localizedDescription)
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
                            self.handleEmailExistsFlow(email: email)
                        } else {
                            self.showError(message: error?.localizedDescription)
                        }
                    }
                    return
                }
                
                self.waitForVerification()
            })
        } catch let error {
            self.showError(message: error.localizedDescription)
        }
    }
    
    @IBAction func resendEmailTapped(_ sender: UIButton) {
        handleEmailExistsFlow(email: currentEmail)
    }
    @IBAction func startOverTapped(_ sender: UIButton) {
        emailVerificationTimer.invalidate()
        currentEmail = nil
        waitingForVerification = false
        
        emailField.text = ""
        passwordField.text = ""
        
        controlsStackView.isHidden = false
        haveAccountLabel.isHidden = false
        closeView.isHidden = false
        verificationLabel.isHidden = true
        verificationActionsView.isHidden = true
    }
    
    func finishWithWalletSync() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "wallet_sync_vc") as! WalletSyncViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
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
