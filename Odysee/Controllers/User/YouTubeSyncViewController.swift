//
//  YouTubeSyncViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/02/2021.
//

import FirebaseAnalytics
import SwiftUI

class YouTubeSyncViewController: UIViewController, UIGestureRecognizerDelegate {
    lazy var youTubeSync = {
        let rootView = YouTubeSyncScreen(
            close: { [weak self] in
                self?.finish()
            },
            model: .init(channels: Lbryio.currentUser?.youtubeChannels)
        )
        let vc = UIHostingController(rootView: rootView)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: true, fullscreen: true)
        AppDelegate.shared.mainController.toggleMiniPlayer(hidden: true)
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if AppDelegate.shared.lazyPlayer != nil {
            AppDelegate.shared.mainController.toggleMiniPlayer(hidden: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(youTubeSync)
        view.addSubview(youTubeSync.view)
        youTubeSync.didMove(toParent: self)
        NSLayoutConstraint.activate([
            youTubeSync.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            youTubeSync.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            youTubeSync.view.topAnchor.constraint(equalTo: view.topAnchor),
            youTubeSync.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func finish() {
        AppDelegate.shared.mainNavigationController?.popViewController(animated: true)
    }
}
