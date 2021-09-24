//
//  AccountViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/03/2021.
//

import UIKit

class FirstRunViewController: UIViewController, FirstRunDelegate {

    @IBOutlet weak var viewContainer: UIView!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    var currentVc: UIViewController!
    var firstChannelVc: CreateChannelViewController!
    var creatingChannel: Bool = false
    
    let keyFirstRunStep = "firstRunStep"
    
    static let stepUserAccount = 1
    static let stepCreateChannel = 2
    static let stepRewardVerification = 3
    
    // Steps
    // 1 - Sign up / sign in nudge and email verification
    // 2 - Create channel
    // 3 - Rewards verification
    var currentStep: Int = stepUserAccount
    var firstChannelName: String?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        registerForKeyboardNotifications()
        
        let defaults = UserDefaults.standard
        //defaults.setValue(1, forKey: keyFirstRunStep)
        currentStep = defaults.value(forKey: keyFirstRunStep) as? Int ?? FirstRunViewController.stepUserAccount
        pageControl.currentPage = currentStep - 1
        
        switch currentStep {
            case FirstRunViewController.stepUserAccount: showUserAccountView()
            case FirstRunViewController.stepCreateChannel: showCreateChannelView()
            case FirstRunViewController.stepRewardVerification: showRewardVerificationView()
            default: showUserAccountView()
        }
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        bottomConstraint.constant = -kbSize.height
        currentVc.view.frame = CGRect(x: 0, y: 0, width: viewContainer.bounds.width, height: viewContainer.bounds.height)
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        bottomConstraint.constant = 0
        currentVc.view.frame = CGRect(x: 0, y: 0, width: viewContainer.bounds.width, height: viewContainer.bounds.height)
    }
    
    func showUserAccountView() {
        if Lbryio.isSignedIn() && currentStep == FirstRunViewController.stepUserAccount {
            nextStep()
            return
        }
        
        let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
        vc.frDelegate = self
        vc.firstRunFlow = true
        showViewController(vc)
    }
    
    func showCreateChannelView() {
        firstChannelVc = (storyboard?.instantiateViewController(identifier: "first_channel_vc") as! CreateChannelViewController)
        firstChannelVc.frDelegate = self
        firstChannelVc.firstRunFlow = true
        showViewController(firstChannelVc)
    }
    
    func showRewardVerificationView() {
        let vc = storyboard?.instantiateViewController(identifier: "rewards_vc") as! RewardsViewController
        vc.frDelegate = self
        vc.firstRunFlow = true
        showViewController(vc)
    }
    
    func showViewController(_ vc: UIViewController) {
        viewContainer.subviews.forEach({
            $0.removeFromSuperview()
        })
        
        vc.willMove(toParent: self)
        viewContainer.addSubview(vc.view)
        vc.view.frame = CGRect(x: 0, y: 0, width: viewContainer.bounds.width, height: viewContainer.bounds.height)
        self.addChild(vc)
        vc.didMove(toParent: self)
        
        currentVc = vc
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    

    @IBAction func skipTapped(_ sender: UIButton) {
        self.view.endEditing(true)
        
        if currentStep == FirstRunViewController.stepUserAccount || currentStep == FirstRunViewController.stepRewardVerification {
            // user skipped sign in, so skip all other steps (or we're at the final step)
            AppDelegate.completeFirstRun()
            AppDelegate.shared.mainNavigationController?.popViewController(animated: true)
            return
        }
        
        if currentStep == FirstRunViewController.stepCreateChannel {
            // skip create channel, so we go to reward verification
            nextStep()
        }
    }
    
    @IBAction func continueTapped(_ sender: UIButton) {
        self.view.endEditing(true)
        continueProcess()
    }
    
    func continueProcess() {
        if currentStep == FirstRunViewController.stepCreateChannel {
            // handle chnanel creation
            handleCreateFirstChannel()
        } else if currentStep == FirstRunViewController.stepRewardVerification {
            // final step. Finish first run
            AppDelegate.completeFirstRun()
            AppDelegate.shared.mainNavigationController?.popViewController(animated: true)
        }
    }
    
    func handleCreateFirstChannel() {
        if creatingChannel {
            return
        }
        
        var name = firstChannelName
        let deposit = Helper.minimumDeposit
        
        if name != nil && !name!.starts(with: "@") {
            name = String(format: "@%@", name!)
        }
        
        // Why are Swift substrings so complicated?! name[1:] / name.substring(1), maybe?
        if name == nil || !LbryUri.isNameValid(String(name!.suffix(from: name!.index(name!.firstIndex(of: "@")!, offsetBy: 1)))) {
            showError(message: String.localized("Please enter a valid name for the channel"))
            return
        }
        if Lbry.walletBalance == nil || deposit > Lbry.walletBalance!.available! {
            showError(message: "Your channel cannot be created at this time. Please try again later.")
            return
        }
        
        if firstChannelVc != nil {
            firstChannelVc.startLoading()
        }
        
        creatingChannel = true
        self.requestStarted()
        
        var options: Dictionary<String, Any> = [:]
        options["name"] = name
        options["bid"] = Helper.sdkAmountFormatter.string(from: deposit as NSDecimalNumber)!
        options["blocking"] = true
        Lbry.apiCall(method: Lbry.methodChannelCreate, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                self.creatingChannel = false
                self.requestFinished(showSkip: true, showContinue: true)
                if self.firstChannelVc != nil {
                    self.firstChannelVc.finishLoading()
                }
                return
            }
            
            self.creatingChannel = false
            let result = data["result"] as? [String: Any]
            let outputs = result?["outputs"] as? [[String: Any]]
            if (outputs != nil) {
                outputs?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claimResult: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claimResult != nil) {
                            Lbryio.logPublishEvent(claimResult!)
                        }
                    } catch {
                        // pass
                    }
                }
                
                self.nextStep()
                return
            }
            
            self.showError(message: String.localized("An unknown error occurred. Please try again."))
            self.requestFinished(showSkip: true, showContinue: true)
            self.firstChannelVc.finishLoading()
        })
    }
    
    func nextStep() {
        DispatchQueue.main.async {
            let defaults = UserDefaults.standard
            if self.currentStep == FirstRunViewController.stepUserAccount {
                // step 2 (channel creation)
                defaults.setValue(FirstRunViewController.stepCreateChannel, forKey: self.keyFirstRunStep)
                self.currentStep = FirstRunViewController.stepCreateChannel
                self.continueButton.isHidden = false
                self.showCreateChannelView()
            } else if self.currentStep == FirstRunViewController.stepCreateChannel {
                // step 3 (reward verification)
                defaults.setValue(FirstRunViewController.stepRewardVerification, forKey: self.keyFirstRunStep)
                self.currentStep = FirstRunViewController.stepRewardVerification
                self.continueButton.setTitle(String.localized("Use Odysee"), for: .normal)
                self.showRewardVerificationView()
            }
            
            self.pageControl.currentPage = self.currentStep - 1
        }
    }
    
    func updateFirstChannelName(_ name: String) {
        self.firstChannelName = name
    }
    
    func requestStarted() {
        DispatchQueue.main.async {
            self.skipButton.isHidden = true
            self.continueButton.isHidden = true
        }
    }
    
    func requestFinished(showSkip: Bool, showContinue: Bool) {
        DispatchQueue.main.async {
            self.skipButton.isHidden = !showSkip
            self.continueButton.isHidden = !showContinue
        }
    }
    
    func finalPageReached() {
        DispatchQueue.main.async {
            self.skipButton.isHidden = true
            self.continueButton.isHidden = false
            self.continueButton.setTitle(String.localized("Use Odysee"), for: .normal)
        }
    }
    
    func showMessage(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }
    func showError(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }
    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }
}
