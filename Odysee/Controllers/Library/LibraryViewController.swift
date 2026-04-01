//
//  LibraryViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import FirebaseAnalytics
import SwiftUI

class LibraryViewController: UIViewController {
    lazy var library = {
        let rootView = LibraryScreen()
        let vc = UIHostingController(rootView: rootView)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()

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

        setupLibraryView()
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

    func setupLibraryView() {
        addChild(library)
        view.addSubview(library.view)
        library.didMove(toParent: self)
        NSLayoutConstraint.activate([
            library.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            library.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            library.view.topAnchor.constraint(equalTo: view.topAnchor),
            library.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
