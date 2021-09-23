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

        if let urlContext = connectionOptions.urlContexts.first {
            let url = urlContext.url
            handleLaunchUrl(url: url)
        }
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

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.currentFileViewController != nil {
            appDelegate.currentFileViewController?.connectPlayer()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.currentFileViewController != nil, appDelegate.player != nil {
            appDelegate.currentFileViewController?.disconnectPlayer()
            appDelegate.setupRemoteTransportControls()
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.currentFileViewController != nil {
            appDelegate.currentFileViewController?.connectPlayer()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }

    func handleLaunchUrl(url: URL) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.mainViewController != nil, appDelegate.mainNavigationController != nil {
            if appDelegate.mainController.handleSpecialUrl(url: url.absoluteString) {
                return
            }

            let lbryUrl = LbryUri.tryParse(url: url.absoluteString, requireProto: false)
            if lbryUrl != nil {
                if lbryUrl!.isChannelUrl() {
                    let vc = appDelegate.mainViewController?.storyboard?
                        .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = appDelegate.mainViewController?.storyboard?
                        .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
                }
            }
        } else {
            appDelegate.pendingOpenUrl = url.absoluteString
        }
    }
}
