//
//  AppDelegate.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import AVFoundation
import MediaPlayer
import Firebase
import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    weak var mainViewController: UIViewController?
    weak var mainTabViewController: UITabBarController?
    weak var mainNavigationController: UINavigationController?
    weak var miniPlayerView: UIView?
    
    var player: AVPlayer?
    var currentClaim: Claim?
    var pendingOpenUrl: String?
    var currentFileViewController: FileViewController?
    var playerObserverAdded: Bool = false
    
    var mainController: MainViewController {
        return mainViewController as! MainViewController
    }
    
    func registerPlayerObserver() {
        if player != nil && !playerObserverAdded {
            player!.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
            player!.currentItem!.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [.new], context: nil)
            playerObserverAdded = true
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object as AnyObject? === player {
            if keyPath == "timeControlStatus" && player!.timeControlStatus == .playing {
                if currentFileViewController != nil {
                    currentFileViewController!.checkTimeToStart()
                }
                return
            }
        }
        
        if keyPath == "playbackLikelyToKeepUp" && player != nil {
            if !(currentFileViewController?.playerConnected ?? false) {
                player?.play()
            }
        }
    }
    
    static func completeFirstRun() {
        let defaults = UserDefaults.standard
        defaults.setValue(true, forKey: Helper.keyFirstRunCompleted)
    }
    
    static func hasCompletedFirstRun() -> Bool {
        let defaults = UserDefaults.standard
        return (defaults.value(forKey: Helper.keyFirstRunCompleted) as? Bool ?? false)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        Helper.initFormatters()
        
        
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: {_, _ in })
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        pendingOpenUrl = url.absoluteString
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "Odysee")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play / Pause Command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player != nil {
                self.player!.play()
                return .success
            }
            
            return .commandFailed
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player != nil {
                self.player!.pause()
                return .success
            }
            
            return .commandFailed
        }

        
        setupNowPlaying()
    }
    
    func setupNowPlaying() {
        // Define Now Playing Info
        if currentFileViewController != nil && player != nil {
            if let claim = currentFileViewController?.claim {
                var nowPlayingInfo = [String : Any]()
                nowPlayingInfo[MPMediaItemPropertyTitle] = claim.value?.title!
                nowPlayingInfo[MPMediaItemPropertyArtist] = claim.signingChannel != nil ?
                    (claim.signingChannel!.value?.title ?? claim.signingChannel!.name) : String.localized("Anonymous")
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = ""
                
                var image: UIImage? = nil
                if let thumbnailUrl = claim.value?.thumbnail?.url {
                    if let cacheData = Cache.getImage(url: thumbnailUrl) {
                        image = UIImage(data: cacheData)
                    } else if let data = try? Data(contentsOf: URL(string: thumbnailUrl)!) {
                        image = UIImage(data: data)
                        if (image != nil) {
                            Cache.putImage(url: thumbnailUrl, image: data)
                        }
                    }
                }
                
                let playerItem = self.player!.currentItem!
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.asset.duration.seconds
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.player!.rate
                if image != nil {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] =
                        MPMediaItemArtwork(boundsSize: image!.size) { size in
                            return image!
                    }
                }
                
                // Set the metadata
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        completionHandler()
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handleNotification(userInfo: userInfo)
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func handleNotification(userInfo: [AnyHashable: Any]) {
        let finalTarget = userInfo["target"] as! String
        
        if (mainViewController != nil && mainNavigationController != nil) {
            if mainController.handleSpecialUrl(url: finalTarget) {
                return
            }
            
            let lbryUrl = LbryUri.tryParse(url: finalTarget, requireProto: false)
            if lbryUrl != nil {
                if lbryUrl!.isChannelUrl() {
                    let vc = mainViewController?.storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = mainViewController?.storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    mainNavigationController?.pushViewController(vc, animated: true)
                }
            }
        } else {
            pendingOpenUrl = finalTarget
        }
    }
    
    func resetPlayerObserver() {
        playerObserverAdded = false
    }
}

