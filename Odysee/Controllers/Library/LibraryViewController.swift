//
//  LibraryViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import FirebaseAnalytics

class LibraryViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.isHidden = !Lbryio.isSignedIn()

        // check if current user is signed in
        if !Lbryio.isSignedIn() {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Library",
                AnalyticsParameterScreenClass: "LibraryViewController",
            ]
        )

        AppDelegate.shared.mainController?.toggleHeaderVisibility(hidden: false)
        AppDelegate.shared.mainController?.adjustMiniPlayerBottom(
            bottom: Helper.miniPlayerBottomWithTabBar(appDelegate: AppDelegate.shared))
    }

    }
}
