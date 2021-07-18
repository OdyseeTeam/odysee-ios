//
//  RewardsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/12/2020.
//

import Firebase
import OAuthSwift
import SafariServices
import StoreKit
import UIKit

class RewardsViewController: UIViewController, SFSafariViewControllerDelegate, SKProductsRequestDelegate, SKPaymentTransactionObserver,
                             UITableViewDelegate, UITableViewDataSource {
    let discordLink = "https://discordapp.com/invite/Z3bERWA"
    var lbrySkipProduct: SKProduct?
    
    var frDelegate: FirstRunDelegate?
    var firstRunFlow = false
    
    @IBOutlet weak var closeVerificationButton: UIButton!
    @IBOutlet weak var twitterOptionButton: UIButton!
    @IBOutlet weak var skipQueueOptionButton: UIButton!
    @IBOutlet weak var manualOptionButton: UIButton!
    @IBOutlet weak var pathOptionsView: UIView!
    @IBOutlet weak var optionsScrollView: UIScrollView!
    @IBOutlet weak var processingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var rewardVerificationPathsView: UIView!
    @IBOutlet weak var mainRewardsView: UIView!
    @IBOutlet weak var rewardsList: UITableView!
    @IBOutlet weak var rewardsSegment: UISegmentedControl!
    
    @IBOutlet weak var noRewardsView: UIView!
    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var rewardEligibleView: UIView!
    
    var claimInProgress = false
    var currentTag = 0
    var allRewards: [Reward] = []
    var rewards: [Reward] = []
    
    // verification paths
    // 1 - phone verification?
    // 2 - twitter
    // 3 - iap
    // 4 - manual
    var verificationPath = 0
    var oauthSwift: OAuth1Swift?
    
    override func viewWillAppear(_ animated: Bool) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
        
        if Lbryio.isSignedIn() {
            if !Lbryio.currentUser!.isRewardApproved! {
                fetchUserAndCheckRewardStatus()
            } else {
                //showRewardEligibleView()
                showRewardsList()
                self.frDelegate?.requestFinished(showSkip: false, showContinue: true)
            }
        }
    }
    
    func fetchUserAndCheckRewardStatus() {
        // check reward approved status first
        do {
            try Lbryio.fetchCurrentUser(completion: { user, error in
                if user == nil || !user!.isRewardApproved! {
                    self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                    self.showVerificationPaths()
                    self.fetchIAPProduct()
                } else {
                    self.frDelegate?.requestFinished(showSkip: false, showContinue: true)
                    //self.showRewardEligibleView()
                    self.showRewardsList()
                }
            })
        } catch {
            // pass
            self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
            self.showVerificationPaths()
            self.fetchIAPProduct()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Rewards", AnalyticsParameterScreenClass: "RewardsViewController"])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        closeVerificationButton.isHidden = self.firstRunFlow
        loadingContainer.layer.cornerRadius = 20
        rewardsList.tableFooterView = UIView()
    }
    
    func fetchIAPProduct() {
        startProcessing()
        
        let req = SKProductsRequest(productIdentifiers: ["lbryskip"])
        req.delegate = self
        req.start()
    }
    
    func showVerificationPaths() {
        DispatchQueue.main.async {
            if !self.firstRunFlow {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.toggleHeaderVisibility(hidden: true)
            }
        
            self.rewardVerificationPathsView.isHidden = false
            self.closeVerificationButton.isHidden = self.firstRunFlow
            
            // don't show the purchase option for now
            //self.skipQueueOptionButton.isHidden = true
            
            self.rewardEligibleView.isHidden = true
            self.mainRewardsView.isHidden = true
        }
    }
    
    func showRewardEligibleView() {
        DispatchQueue.main.async {
            if !self.firstRunFlow {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.toggleHeaderVisibility(hidden: true)
            }
            
            self.rewardVerificationPathsView.isHidden = true
            self.mainRewardsView.isHidden = true
            self.rewardEligibleView.isHidden = false
        }
    }
    
    func showRewardsList() {
        DispatchQueue.main.async {
            if !self.firstRunFlow {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.toggleHeaderVisibility(hidden: false)
            }
                
            self.rewardVerificationPathsView.isHidden = true
            self.closeVerificationButton.isHidden = true
            self.mainRewardsView.isHidden = false
        }
        
        // load the rewards list
        loadRewards()
    }
    
    func resetRewards() {
        self.allRewards = []
        self.rewards = []
        DispatchQueue.main.async {
            self.rewardsList.reloadData()
        }
    }
    
    func loadRewards() {
        resetRewards()
        DispatchQueue.main.async {
            self.loadingContainer.isHidden = false
        }
        
        do {
            try Lbryio.get(resource: "reward", action: "list", options: ["multiple_rewards_per_type": "true"], completion: { data, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        self.loadingContainer.isHidden = true
                    }
                    self.showError(error: error)
                    return
                }
                
                if let items = data as? [[String: Any]] {
                    items.forEach{ item in
                        let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                        do {
                            let reward: Reward? = try JSONDecoder().decode(Reward.self, from: data)
                            if (reward != nil && reward?.rewardType != Reward.typeNewMobile) {
                                self.allRewards.append(reward!)
                            }
                        } catch {
                            // pass
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.loadingContainer.isHidden = true
                    }
                    self.updateRewardsList()
                }
            })
        } catch let error {
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
            }
            showError(error: error)
        }
    }
    
    func updateRewardsList() {
        DispatchQueue.main.async {
            let index = self.rewardsSegment.selectedSegmentIndex
            if index == 0 {
                // All
                self.rewards = self.allRewards
            } else if index == 1 {
                // Unclaimed
                self.rewards = self.allRewards.filter { !$0.claimed }
            } else {
                // Claimed
                self.rewards = self.allRewards.filter { $0.claimed }
            }
        
            self.noRewardsView.isHidden = self.rewards.count > 0
            self.rewardsList.isHidden = self.rewards.count == 0
            self.rewardsList.reloadData()
        }
    }
    
    @IBAction func optionButtonTapped(_ sender: UIButton!) {
        let currentTag = sender.tag
        let page = sender.tag - 100
        let optionButtons = [twitterOptionButton, skipQueueOptionButton, manualOptionButton]
        for button in optionButtons {
            button!.setTitleColor(UIColor.link, for: .normal)
        }
        if currentTag == sender.tag {
            sender.setTitleColor(Helper.primaryColor, for: .normal)
        }
        
        var frame: CGRect = optionsScrollView.frame
        frame.origin.x = frame.size.width * CGFloat(page)
        frame.origin.y = 0
        optionsScrollView.scrollRectToVisible(frame, animated: true)
    }
    
    @IBAction func twitterActionTapped(_sender: UIButton) {
        startVerifyWithTwitter()
    }
    
    @IBAction func purchaseActionTapped(_ sender: UIButton) {
        guard let lbrySkipProduct = lbrySkipProduct else {
            showError(message: String.localized("The product could not be retrieved. Please try again later."))
            return
        }
        
        if SKPaymentQueue.canMakePayments() {
            startProcessing()
            let payment = SKPayment(product: lbrySkipProduct)
            SKPaymentQueue.default().add(self)
            SKPaymentQueue.default().add(payment)
            return
        }
        
        showError(message: String.localized("You cannot make purchases at this time."))
    }
    
    @IBAction func manualActionTapped(_sender: UIButton) {
        if let url = URL(string: discordLink) {
            let vc = SFSafariViewController(url: url)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.navigationController!.popViewController(animated: false)
            appDelegate.mainController.present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func closeTapped(_sender: UIButton) {
        self.navigationController!.popViewController(animated: true)
    }
    
    func startProcessing() {
        DispatchQueue.main.async {
            self.pathOptionsView.isHidden = true
            self.optionsScrollView.isHidden = true
            self.closeVerificationButton.isHidden = true
            self.processingIndicator.isHidden = false
        }
    }
    
    func stopProcessing() {
        DispatchQueue.main.async {
            self.pathOptionsView.isHidden = false
            self.optionsScrollView.isHidden = false
            self.closeVerificationButton.isHidden = self.firstRunFlow
            self.processingIndicator.isHidden = true
        }
    }
    
    func startVerifyWithTwitter() {
        var secrets: NSDictionary?
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist") {
            secrets = NSDictionary(contentsOfFile: path)
        }
        
        startProcessing()
        if !(Lbryio.cachedTwitterOauthToken ?? "").isBlank && !(Lbryio.cachedTwitterOauthTokenSecret ?? "").isBlank {
            self.twitterVerifyWithOauthToken(oauthToken: Lbryio.cachedTwitterOauthToken!, oauthTokenSecret: Lbryio.cachedTwitterOauthTokenSecret!)
            return
        }
            
        // request for sign in url
        oauthSwift = OAuth1Swift(
            consumerKey: secrets?.value(forKey: "TwitterConsumerKey") as! String,
            consumerSecret: secrets?.value(forKey: "TwitterConsumerSecret") as! String,
            requestTokenUrl: "https://api.twitter.com/oauth/request_token",
            authorizeUrl: "https://api.twitter.com/oauth/authorize",
            accessTokenUrl: "https://api.twitter.com/oauth/access_token"
        )
        let oauthAuthorizeHandler = SafariURLHandler(viewController: self, oauthSwift: oauthSwift!)
        oauthAuthorizeHandler.delegate = self
        oauthSwift!.authorizeURLHandler = oauthAuthorizeHandler
        
        let _ = oauthSwift!.authorize(withCallbackURL: "lbry://?oauthcb") { result in
            switch result {
                case .success(let (credential, _, _)):
                    // send twitter_verify request
                    Lbryio.cachedTwitterOauthToken = credential.oauthToken
                    Lbryio.cachedTwitterOauthTokenSecret = credential.oauthTokenSecret
                    self.twitterVerifyWithOauthToken(oauthToken: credential.oauthToken, oauthTokenSecret: credential.oauthTokenSecret)
                    break
                case .failure(let error):
                    self.stopProcessing()
                    self.showError(message: String(format: "An error occurred while processing the Twitter verification request: %@", error.localizedDescription))
                    break
            }
        }
    }
    
    func twitterVerifyWithOauthToken(oauthToken: String, oauthTokenSecret: String) {
        let options: Dictionary<String, String> = [
            "oauth_token": oauthToken,
            "oauth_token_secret": oauthTokenSecret,
            "domain": "odysee.com"
        ]
        do {
            try Lbryio.post(resource: "verification", action: "twitter_verify", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    self.stopProcessing()
                    self.showError(error: error)
                    return
                }
                
                do {
                    let jsonData = try! JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
                    let rewardVerified = try JSONDecoder().decode(RewardVerified.self, from: jsonData)
                    if rewardVerified.isRewardApproved ?? false {
                        // successful reward verification, show the rewards page
                        DispatchQueue.main.async {
                            //self.showRewardEligibleView()
                            self.stopProcessing()
                            self.showRewardsList()
                            return
                        }
                    }
                } catch let error {
                    self.stopProcessing()
                    self.showError(error: error)
                }
                
                // error state
                self.stopProcessing()
                self.showError(message: "You could not be verified for rewards at this time. Please try again later.")
            })
        } catch let error {
            self.stopProcessing()
            self.showError(error: error)
        }
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        stopProcessing()
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        self.stopProcessing()
        
        if lbrySkipProduct == nil {
            // IAP not available
            DispatchQueue.main.async {
                self.skipQueueOptionButton.isHidden = true
            }
            return
        }
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.stopProcessing()
        
        if let product = response.products.first {
            lbrySkipProduct = product
            return
        }
        
        // product not available
        DispatchQueue.main.async {
            self.skipQueueOptionButton.isHidden = true
        }
    }
    
    func checkReceipt(completion: @escaping (Bool?, Error?) -> Void) {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                let base64ReceiptString = receiptData.base64EncodedString(options: [])
             
                let options: Dictionary<String, String> = ["receipt": base64ReceiptString]
                try Lbryio.post(resource: "verification", action: "ios_purchase", options: options, completion: { data, error in
                    guard let data = data, error == nil else {
                        completion(nil, error)
                        return
                    }
                    
                    do {
                        let jsonData = try! JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
                        let rewardVerified = try JSONDecoder().decode(RewardVerified.self, from: jsonData)
                        if let isRewardApproved = rewardVerified.isRewardApproved {
                            completion(isRewardApproved, nil)
                            return
                        }
                    } catch let error {
                        completion(nil, error)
                        return
                    }
                    
                    // error state
                    completion(nil, GenericError("You could not be verified for rewards at this time. Please try again later."))
                })
            } catch {
                completion(nil, GenericError("Your payment could not be verified at this time. Please try again later."))
            }
            
            return
        }
        
        completion(nil, GenericError("Invalid transaction state. Please try again."))
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
                case .purchasing:
                    break
                case .purchased, .restored:
                    // TODO: Send transactionIdentifier to server for remote validation
                    SKPaymentQueue.default().finishTransaction(transaction)
                    SKPaymentQueue.default().remove(self)
                    
                    checkReceipt(completion: { rewardVerified, error in
                        guard let rewardVerified = rewardVerified, error == nil else {
                            self.showError(error: error)
                            self.stopProcessing()
                            return
                        }
                        
                        self.stopProcessing()
                        if rewardVerified {
                            //self.showRewardEligibleView()
                            self.showRewardsList()
                        } else {
                            self.showError(message: "Your transaction could not be verified at this time. Please try again later.")
                        }
                    })
                    break
                case .failed, .deferred:
                
                    stopProcessing()
                    SKPaymentQueue.default().finishTransaction(transaction)
                    SKPaymentQueue.default().remove(self)
                    break
                default:
                    break
            }
        }
    }
    
    func showMessage(message: String?) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.mainController.showMessage(message: message)
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
    
    @IBAction func segmentValueChanged(_ sender: UISegmentedControl) {
        updateRewardsList()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rewards.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reward_cell", for: indexPath) as! RewardTableViewCell
        
        let reward: Reward = rewards[indexPath.row]
        cell.setReward(reward: reward)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let reward: Reward = rewards[indexPath.row]
        
        if reward.claimed && !(reward.transactionId ?? "").isBlank {
            // open the transaction view
            if let url = URL(string: String(format: "%@/%@", Helper.txLinkPrefix, reward.transactionId!)) {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
        } else if !reward.claimed {
            //attemptRewardClaim(reward: reward)
        }
    }
    
    func attemptRewardClaim(reward: Reward) {
        if claimInProgress {
            showError(message: "Please wait for the pending reward claim request to finish.")
            return
        }
        
        claimInProgress = true
        rewardsSegment.isEnabled = false
        loadingContainer.isHidden = false
        
        // check if there's already a wallet address
        let defaults = UserDefaults.standard
        let receiveAddress = defaults.string(forKey: Helper.keyReceiveAddress)
        if ((receiveAddress ?? "").isBlank) {
            Lbry.apiCall(method: Lbry.Methods.addressUnused, params: .init()).subscribeResult { result in
                guard case let .success(newAddress) = result else {
                    self.claimRewardFinished()
                    self.showError(message: String.localized("Could not obtain the wallet address for receiving rewards."))
                    return
                }
                UserDefaults.standard.set(newAddress, forKey: Helper.keyReceiveAddress)
                self.claimReward(reward, walletAddress: newAddress)
            }
            return
        } else {
            claimReward(reward, walletAddress: receiveAddress!)
        }
    }
    
    func claimReward(_ reward: Reward, walletAddress: String) {
        if reward.rewardType == Reward.typeFirstPublish || reward.rewardType == Reward.typeFirstChannel {
            Lbry.apiCall(method: Lbry.Methods.claimList,
                         params: .init(
                            claimType: [reward.rewardType == Reward.typeFirstPublish ? .stream : .channel],
                            page: 1,
                            pageSize: 1,
                            resolve: true))
                .subscribeResult {
                    self.didResolveRewardClaim($0, reward: reward, walletAddress: walletAddress)
                }
        } else {
            doClaimReward(reward, walletAddress: walletAddress, transactionId: nil)
        }
    }
    
    func didResolveRewardClaim(_ result: Result<Page<Claim>, Error>, reward: Reward, walletAddress: String) {
        guard case let .success(page) = result else {
            claimRewardFinished()
            result.showErrorIfPresent()
            return
        }
        guard let claim = page.items.first else {
            claimRewardFinished()
            showError(message: String.localized("The eligible transaction for claiming the reward could not be retrieved."))
            return
        }
        
        doClaimReward(reward, walletAddress: walletAddress, transactionId: claim.txid)
    }

    func doClaimReward(_ reward: Reward, walletAddress: String, transactionId: String?) {
        var options: Dictionary<String, String> = ["reward_type": reward.rewardType!, "wallet_address": walletAddress]
        if reward.rewardType == Reward.typeCustom && !(reward.rewardCode ?? "").isBlank {
            options["reward_code"] = reward.rewardCode!
        }
        if !(transactionId ?? "").isBlank {
            options["transaction_id"] = transactionId!
        }
        
        do {
            try Lbryio.post(resource: "reward", action: "claim", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    self.claimRewardFinished()
                    self.showError(error: error)
                    return
                }
                
                self.claimRewardFinished()
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data as Any, options: [.prettyPrinted, .sortedKeys])
                    let reward: Reward? = try JSONDecoder().decode(Reward.self, from: jsonData)
                    if let notification = reward!.rewardNotification {
                        self.showMessage(message: notification)
                    } else {
                        self.showMessage(message: String.localized("You successfully claimed a reward!"))
                    }
                    
                    self.resetRewards()
                    self.loadRewards()
                    return
                } catch {
                    // pass
                }
                
                // error state
                self.showError(message: String.localized("An error occurred while trying to claim the reward. Please try again later."))
            })
        } catch let error {
            self.claimRewardFinished()
            self.showError(error: error)
        }
    }
    
    func claimRewardFinished() {
        self.claimInProgress = false
        DispatchQueue.main.async {
            self.rewardsSegment.isEnabled = true
            self.loadingContainer.isHidden = true
        }
    }
    
    @IBAction func backTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
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
