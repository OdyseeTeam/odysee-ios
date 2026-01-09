//
//  SceneDelegate.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import AVFoundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        windowScene.windows.forEach { $0.tintColor = Helper.primaryColor }

        UIApplication.shared.beginReceivingRemoteControlEvents()

        if let userActivity = connectionOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL
        {
            handleLaunchUrl(url: url)
        } else if let urlContext = connectionOptions.urlContexts.first {
            let url = urlContext.url
            handleLaunchUrl(url: url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handleLaunchUrl(url: url)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleLaunchUrl(url: url)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        if AppDelegate.shared.currentFileViewController != nil {
            AppDelegate.shared.currentFileViewController?.connectPlayer()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        if UserDefaults.standard.integer(forKey: "BackgroundPlaybackMode") != 0 {
            (UIApplication.shared.delegate as? AppDelegate)?.currentFileViewController?.disconnectPlayer()
        }
    }

    func handleLaunchUrl(url: URL) {
        if AppDelegate.shared.mainViewController != nil, AppDelegate.shared.mainNavigationController != nil {
            if AppDelegate.shared.mainController.handleSpecialUrl(url: url.absoluteString) {
                return
            }

            if let lbryUrl = LbryUri.tryParse(url: url.absoluteString, requireProto: false) {
                if lbryUrl.isChannel {
                    let vc = AppDelegate.shared.mainViewController?.storyboard?
                        .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = AppDelegate.shared.mainViewController?.storyboard?
                        .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
                }
            }
        } else {
            AppDelegate.shared.pendingOpenUrl = url.absoluteString
        }
    }

    @available(iOS 26.0, *)
    func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        .minimal
    }
}
