//
//  UserAccountViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import FirebaseAnalytics
import SwiftUI

class UserAccountViewController: UIViewController {
    lazy var signInUp = {
        let rootView = SignInUpScreen(
            showClose: !firstRunFlow,
            close: { [weak self] in
                self?.closeButtonTapped()
            },
            model: .init(
                finish: { [weak self] in
                    Task { await self?.finishWithWalletSync() }
                },
                frRequestStarted: { [weak self] in
                    self?.frDelegate?.requestStarted()
                },
                frRequestFinished: { [weak self] in
                    self?.frDelegate?.requestFinished(showSkip: true, showContinue: false)
                }
            )
        )
        let vc = UIHostingController(rootView: rootView)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()

    var frDelegate: FirstRunDelegate?
    var firstRunFlow = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true, fullscreen: true)
        AppDelegate.shared.mainController.toggleMiniPlayer(hidden: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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

        addChild(signInUp)
        view.addSubview(signInUp.view)
        signInUp.didMove(toParent: self)
        NSLayoutConstraint.activate([
            signInUp.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            signInUp.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            signInUp.view.topAnchor.constraint(equalTo: view.topAnchor),
            signInUp.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func closeButtonTapped() {
        guard let navigationController else {
            Helper.showError(message: "Couldn't get navigation controller")
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

    func finishWithWalletSync() async {
        await Wallet.shared.startSync()

        AppDelegate.shared.mainController.checkUploadButton()
        AppDelegate.shared.mainController.startWalletBalanceTimer()
        AppDelegate.shared.mainController.checkAndClaimEmailReward(completion: {})

        if firstRunFlow {
            frDelegate?.requestFinished(showSkip: true, showContinue: true)
            frDelegate?.nextStep()
        } else {
            if let vcs = navigationController?.viewControllers {
                let index = max(0, vcs.count - 2)
                var targetVc = vcs[index]
                if targetVc == self {
                    targetVc = vcs[index - 1]
                }
                navigationController?.popToViewController(targetVc, animated: true)
                checkAndShowYouTubeSync(popViewController: false)
            } else {
                checkAndShowYouTubeSync(popViewController: true)
            }
        }
    }

    func checkAndShowYouTubeSync(popViewController: Bool) {
        if popViewController {
            AppDelegate.shared.mainNavigationController?.popViewController(animated: false)
        }
        guard let channels = Lbryio.currentUser?.youtubeChannels,
              // Prompt Claim Channel(s) if "Your videos are ready to be transferred."
              YouTubeSyncScreen.ViewModel.transferEnabled(channels: channels)
        else {
            return
        }
        let vc = storyboard?.instantiateViewController(identifier: "yt_sync_vc") as! YouTubeSyncViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }
}
