//
//  RewardsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/12/2020.
//

import FirebaseAnalytics
import SafariServices
import StoreKit
import SwiftUI
import UIKit

class RewardsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var frDelegate: FirstRunDelegate?
    var firstRunFlow = false

    @IBOutlet var closeVerificationButton: UIButton!

    @IBOutlet var mainRewardsView: UIView!
    @IBOutlet var rewardsList: UITableView!
    @IBOutlet var rewardsSegment: UISegmentedControl!

    @IBOutlet var noRewardsView: UIView!
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var rewardEligibleView: UIView!

    lazy var rewardVerification = {
        let rootView = RewardVerificationView(close: { self.closeTapped(nil) })
        let vc = UIHostingController(rootView: rootView)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()

    var claimInProgress = false
    var currentTag = 0
    var allRewards: [Reward] = []
    var rewards: [Reward] = []

    override func viewWillAppear(_ animated: Bool) {
        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())

        if Lbryio.isSignedIn() {
            if !(Lbryio.currentUser?.isRewardApproved ?? false) {
                fetchUserAndCheckRewardStatus()
            } else {
                // showRewardEligibleView()
                showRewardsList()
                frDelegate?.requestFinished(showSkip: false, showContinue: true)
            }
        }
    }

    func fetchUserAndCheckRewardStatus() {
        // check reward approved status first
        do {
            try Lbryio.fetchCurrentUser(completion: { user, _ in
                if user == nil || !(user?.isRewardApproved ?? false) {
                    self.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                    self.showVerification()
                } else {
                    self.frDelegate?.requestFinished(showSkip: false, showContinue: true)
                    // self.showRewardEligibleView()
                    self.showRewardsList()
                }
            })
        } catch {
            // pass
            frDelegate?.requestFinished(showSkip: true, showContinue: false)
            showVerification()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Rewards",
                AnalyticsParameterScreenClass: "RewardsViewController",
            ]
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        closeVerificationButton.isHidden = firstRunFlow
        loadingContainer.layer.cornerRadius = 20
        rewardsList.tableFooterView = UIView()

        addChild(rewardVerification)
        view.insertSubview(rewardVerification.view, belowSubview: closeVerificationButton)
        rewardVerification.didMove(toParent: self)
        NSLayoutConstraint.activate([
            rewardVerification.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            rewardVerification.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            rewardVerification.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rewardVerification.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    func showVerification() {
        DispatchQueue.main.async {
            if !self.firstRunFlow {
                AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
            }

            self.rewardVerification.view.isHidden = false
            self.closeVerificationButton.isHidden = self.firstRunFlow

            // don't show the purchase option for now
            // self.skipQueueOptionButton.isHidden = true

            self.rewardEligibleView.isHidden = true
            self.mainRewardsView.isHidden = true
        }
    }

    func showRewardEligibleView() {
        DispatchQueue.main.async {
            if !self.firstRunFlow {
                AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
            }

            self.rewardVerification.view.isHidden = true
            self.mainRewardsView.isHidden = true
            self.rewardEligibleView.isHidden = false
        }
    }

    func showRewardsList() {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)

            self.rewardVerification.view.isHidden = true
            self.closeVerificationButton.isHidden = true
            self.mainRewardsView.isHidden = false
        }

        // load the rewards list
        loadRewards()
    }

    func resetRewards() {
        allRewards = []
        rewards = []
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
            try Lbryio.get(
                resource: "reward",
                action: "list",
                options: ["multiple_rewards_per_type": "true"],
                completion: { data, error in
                    guard let data = data, error == nil else {
                        DispatchQueue.main.async {
                            self.loadingContainer.isHidden = true
                        }
                        self.showError(error: error)
                        return
                    }

                    if let items = data as? [[String: Any]] {
                        for item in items {
                            do {
                                let data = try JSONSerialization.data(
                                    withJSONObject: item,
                                    options: [.prettyPrinted, .sortedKeys]
                                )
                                let reward: Reward? = try JSONDecoder().decode(Reward.self, from: data)
                                if let reward, reward.rewardType != Reward.typeNewMobile {
                                    self.allRewards.append(reward)
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
                }
            )
        } catch {
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
                // swiftformat:disable:next preferKeyPath
                self.rewards = self.allRewards.filter { $0.claimed }
            }

            self.noRewardsView.isHidden = self.rewards.count > 0
            self.rewardsList.isHidden = self.rewards.count == 0
            self.rewardsList.reloadData()
        }
    }

    @IBAction func closeTapped(_ sender: UIButton?) {
        navigationController?.popViewController(animated: true)
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

        if reward.claimed, let transactionId = reward.transactionId, !transactionId.isBlank {
            // open the transaction view
            if let url = URL(string: "\(Helper.txLinkPrefix)/\(transactionId)") {
                let vc = SFSafariViewController(url: url)
                AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
            }
        } else if !reward.claimed {
            // attemptRewardClaim(reward: reward)
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
        if let receiveAddress = defaults.string(forKey: Helper.keyReceiveAddress), !receiveAddress.isBlank {
            claimReward(reward, walletAddress: receiveAddress)
        } else {
            Lbry.apiCall(method: Lbry.Methods.addressUnused, params: .init()).subscribeResult { result in
                guard case let .success(newAddress) = result else {
                    self.claimRewardFinished()
                    self.showError(
                        message: String.localized("Could not obtain the wallet address for receiving rewards.")
                    )
                    return
                }
                UserDefaults.standard.set(newAddress, forKey: Helper.keyReceiveAddress)
                self.claimReward(reward, walletAddress: newAddress)
            }
        }
    }

    func claimReward(_ reward: Reward, walletAddress: String) {
        if reward.rewardType == Reward.typeFirstPublish || reward.rewardType == Reward.typeFirstChannel {
            Lbry.apiCall(
                method: Lbry.Methods.claimList,
                params: .init(
                    claimType: [reward.rewardType == Reward.typeFirstPublish ? .stream : .channel],
                    page: 1,
                    pageSize: 1,
                    resolve: true
                )
            )
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
            showError(
                message: String
                    .localized("The eligible transaction for claiming the reward could not be retrieved.")
            )
            return
        }

        doClaimReward(reward, walletAddress: walletAddress, transactionId: claim.txid)
    }

    func doClaimReward(_ reward: Reward, walletAddress: String, transactionId: String?) {
        var options: [String: String] = ["wallet_address": walletAddress]
        if let rewardType = reward.rewardType {
            options["reward_type"] = rewardType
        }
        if reward.rewardType == Reward.typeCustom, let rewardCode = reward.rewardCode, !rewardCode.isBlank {
            options["reward_code"] = rewardCode
        }
        if let transactionId, !transactionId.isBlank {
            options["transaction_id"] = transactionId
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
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: data as Any,
                        options: [.prettyPrinted, .sortedKeys]
                    )
                    let reward: Reward? = try JSONDecoder().decode(Reward.self, from: jsonData)
                    if let notification = reward?.rewardNotification {
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
                self
                    .showError(
                        message: String
                            .localized("An error occurred while trying to claim the reward. Please try again later.")
                    )
            })
        } catch {
            claimRewardFinished()
            showError(error: error)
        }
    }

    func claimRewardFinished() {
        claimInProgress = false
        DispatchQueue.main.async {
            self.rewardsSegment.isEnabled = true
            self.loadingContainer.isHidden = true
        }
    }

    @IBAction func backTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
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
