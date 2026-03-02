//
//  YouTubeSyncViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/02/2021.
//

import FirebaseAnalytics

class YouTubeSyncViewController: UIViewController, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "YouTubeSync",
                AnalyticsParameterScreenClass: "YouTubeSyncViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func finish() {
        AppDelegate.shared.mainNavigationController?.popViewController(animated: true)
    }
}
