//
//  NotificationsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/12/2020.
//

import FirebaseAnalytics
import SwiftUI

class NotificationsViewController: UIViewController, UIGestureRecognizerDelegate {
    lazy var notifications = {
        let rootView = NotificationsScreen()
        let vc = UIHostingController(rootView: rootView)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.isHidden = !Account.signedIn

        AppDelegate.shared.mainController?.notificationBadgeIcon.tintColor = Helper.primaryColor
        AppDelegate.shared.mainController?.notificationsViewActive = true

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self

        // check if current user is signed in
        if !Account.signedIn {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        } else {
            setupNotificationsView()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Notifications",
                AnalyticsParameterScreenClass: "NotificationsViewController",
            ]
        )

        AppDelegate.shared.mainController?.toggleHeaderVisibility(hidden: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.shared.mainController?.notificationBadgeIcon.tintColor = UIColor.label
        AppDelegate.shared.mainController?.notificationsViewActive = false
    }

    func setupNotificationsView() {
        guard notifications.parent == nil else {
            return
        }

        addChild(notifications)
        view.addSubview(notifications.view)
        notifications.didMove(toParent: self)
        NSLayoutConstraint.activate([
            notifications.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            notifications.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            notifications.view.topAnchor.constraint(equalTo: view.topAnchor),
            notifications.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
