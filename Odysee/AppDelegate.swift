//
//  AppDelegate.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import AVFoundation
import FirebaseCore
import MediaPlayer
import PINRemoteImage
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, UITabBarControllerDelegate {
    static let keyLastTabIndex = "lastTabIndex"

    static var shared: AppDelegate {
        // swift-format-ignore
        // Always exists as AppDelegate
        UIApplication.shared.delegate as! AppDelegate
    }

    weak var mainViewController: UIViewController?
    weak var mainTabViewController: UITabBarController?
    weak var mainNavigationController: UINavigationController?

    var player: AVPlayer?
    var currentPlaylistClaim: Claim?
    var currentClaim: Claim?
    var pictureInPicturePlayingClaim: Claim?
    var pendingOpenUrl: String?
    var currentFileViewController: FileViewController?
    var playerObserverAdded: Bool = false
    var playerObservers: [NSKeyValueObservation]?
    var currentTimeControlStatus: AVPlayer.TimeControlStatus?
    var remoteCommands = [CommandCenterCommands: Any]()

    // One-time only lazily activate the Audio Session when playing a file.
    // This prevents the app from taking over the audio stream on launch.
    lazy var lazyPlayer: AVPlayer? = {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            mainController.showMessage(message: "Lazy AVAudioSession activation failed! \(error)")
        }
        return self.player
    }()

    var mainController: MainViewController {
        return mainViewController as! MainViewController
    }

    func registerPlayerObserver() {
        if let lazyPlayer = lazyPlayer, !playerObserverAdded {
            lazyPlayer.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
            lazyPlayer.currentItem?.addObserver(
                self,
                forKeyPath: "playbackLikelyToKeepUp",
                options: [.new],
                context: nil
            )
            if playerObservers == nil {
                playerObservers = [NSKeyValueObservation]()
            }
            playerObservers?.append(lazyPlayer.observe(\.rate, options: .initial) { [unowned self] _, _ in
                handlePlaybackChange()
            })
            playerObservers?
                .append(lazyPlayer.observe(\.currentItem?.status, options: .initial) { [unowned self] _, _ in
                    handlePlaybackChange()
                })
            playerObserverAdded = true
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    @objc func playerDidFinishPlaying(note: NSNotification) {
        removeRemoteTransportControls()
        (mainViewController as? MainViewController)?.miniPlayerPlayPauseButton.isUserInteractionEnabled = false

        if let currentFileViewController {
            currentFileViewController.playNextPlaylistItem()
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if object as AnyObject? === lazyPlayer, currentTimeControlStatus != lazyPlayer?.timeControlStatus {
            currentTimeControlStatus = lazyPlayer?.timeControlStatus
            if keyPath == "timeControlStatus", lazyPlayer?.timeControlStatus == .playing {
                if let currentFileViewController = currentFileViewController {
                    currentFileViewController.checkTimeToStart()
                    DispatchQueue.main.async {
                        self.lazyPlayer?.rate = currentFileViewController.playerRate
                    }
                }
                return
            }
        }

        if let player = lazyPlayer,
           let item = player.currentItem,
           keyPath == "playbackLikelyToKeepUp",
           item.isPlaybackLikelyToKeepUp,
           currentFileViewController?.playerConnected != true,
           player.timeControlStatus != .paused
        {
            player.play()
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

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: { _, _ in })
        application.registerForRemoteNotifications()

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        pendingOpenUrl = url.absoluteString
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Now Playing Controls

    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play / Pause Command

        remoteCommands[.play] = commandCenter.playCommand.addTarget { [unowned self] _ in
            if let lazyPlayer = lazyPlayer {
                lazyPlayer.play()
                return .success
            }

            return .commandFailed
        }

        remoteCommands[.pause] = commandCenter.pauseCommand.addTarget { [unowned self] _ in
            if let lazyPlayer = lazyPlayer {
                lazyPlayer.pause()
                return .success
            }

            return .commandFailed
        }

        remoteCommands[.togglePlayPause] = commandCenter.togglePlayPauseCommand.addTarget { [unowned self] _ in
            if let lazyPlayer = lazyPlayer {
                if lazyPlayer.rate == 0 {
                    lazyPlayer.play()
                } else {
                    lazyPlayer.pause()
                }
                return .success
            }
            return .commandFailed
        }

        // swiftformat:disable:next wrap
        remoteCommands[.changePlaybackRate] = commandCenter.changePlaybackRateCommand.addTarget { [unowned self] event in
            if let lazyPlayer = lazyPlayer, let event = event as? MPChangePlaybackRateCommandEvent {
                lazyPlayer.rate = event.playbackRate
                return .success
            }
            return .commandFailed
        }

        remoteCommands[.skipBackward] = commandCenter.skipBackwardCommand.addTarget { [unowned self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                skipBackward(by: event.interval)
                return .success
            }

            return .commandFailed
        }

        remoteCommands[.skipForward] = commandCenter.skipForwardCommand.addTarget { [unowned self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                skipForward(by: event.interval)
                return .success
            }

            return .commandFailed
        }

        // swiftformat:disable:next wrap
        remoteCommands[.changePlaybackPosition] = commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }

        setupNowPlaying()
    }

    func removeRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(remoteCommands[.play])
        commandCenter.pauseCommand.removeTarget(remoteCommands[.pause])
        commandCenter.togglePlayPauseCommand.removeTarget(remoteCommands[.togglePlayPause])
        commandCenter.changePlaybackRateCommand.removeTarget(remoteCommands[.changePlaybackRate])
        commandCenter.skipBackwardCommand.removeTarget(remoteCommands[.skipBackward])
        commandCenter.skipForwardCommand.removeTarget(remoteCommands[.skipForward])
        commandCenter.changePlaybackPositionCommand.removeTarget(remoteCommands[.changePlaybackPosition])

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    private func skipBackward(by interval: TimeInterval) {
        if let lazyPlayer {
            seek(to: lazyPlayer.currentTime() - CMTime(seconds: interval, preferredTimescale: 1))
        }
    }

    private func skipForward(by interval: TimeInterval) {
        if let lazyPlayer {
            seek(to: lazyPlayer.currentTime() + CMTime(seconds: interval, preferredTimescale: 1))
        }
    }

    private func seek(to position: TimeInterval) {
        seek(to: CMTime(seconds: position, preferredTimescale: 1))
    }

    private func seek(to time: CMTime) {
        lazyPlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { isFinished in
            if isFinished {
                self.handlePlaybackChange()
            }
        }
    }

    private func handlePlaybackChange() {
        guard let lazyPlayer = lazyPlayer,
              let currentItem = lazyPlayer.currentItem,
              currentItem.status == .readyToPlay
        else {
            return
        }

        (mainViewController as? MainViewController)?.miniPlayerPlayPauseButton.image = UIImage(
            systemName: lazyPlayer.rate == 0 ? "play.fill" : "pause.fill"
        )

        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

        guard var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo else {
            setupRemoteTransportControls()
            (mainViewController as? MainViewController)?.miniPlayerPlayPauseButton.isUserInteractionEnabled = true
            return
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentItem.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = currentItem.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = lazyPlayer.rate
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    private func makeMediaItem(_ image: UIImage) -> MPMediaItemArtwork {
        return MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in image })
    }

    var thumbDownloadURL: URL?
    var thumbDownloadUUID: UUID?
    func setupNowPlaying() {
        // Define Now Playing Info
        if currentFileViewController != nil, lazyPlayer != nil {
            if let claim = currentFileViewController?.claim {
                var nowPlayingInfo = [String: Any]()
                nowPlayingInfo[MPMediaItemPropertyTitle] = claim.value?.title ?? ""
                nowPlayingInfo[MPMediaItemPropertyArtist] = if let text = claim.signingChannel?.titleOrName {
                    text
                } else {
                    String.localized("Anonymous")
                }
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = ""

                if let thumbnailUrl = claim.value?.thumbnail?.url.flatMap(URL.init),
                   thumbDownloadURL != thumbnailUrl
                {
                    let mgr = PINRemoteImageManager.shared()
                    if let previousUUID = thumbDownloadUUID {
                        mgr.cancelTask(with: previousUUID)
                    }
                    var cachedImage: UIImage?
                    thumbDownloadURL = thumbnailUrl
                    thumbDownloadUUID = mgr.downloadImage(
                        with: thumbnailUrl,
                        options: .downloadOptionsSkipDecode,
                        completion: { [unowned self] result in
                            if result.resultType == .memoryCache {
                                // Got image from memory cache. This is synchronous.
                                assert(Thread.isMainThread)
                                cachedImage = result.image
                            } else {
                                // image was not available in memory cache. This is asynchronous.
                                // Dispatch to main, and if we're still looking for the same image,
                                // add it into the nowPlayingInfo.
                                DispatchQueue.main.async { [self] in
                                    guard thumbDownloadURL == thumbnailUrl else {
                                        return
                                    }
                                    thumbDownloadURL = nil
                                    thumbDownloadUUID = nil
                                    let ctr = MPNowPlayingInfoCenter.default()
                                    if let image = result.image, var info = ctr.nowPlayingInfo {
                                        info[MPMediaItemPropertyArtwork] = makeMediaItem(image)
                                        ctr.nowPlayingInfo = info
                                    }
                                }
                            }
                        }
                    )
                    if let cachedImage = cachedImage {
                        thumbDownloadURL = nil
                        thumbDownloadUUID = nil
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = makeMediaItem(cachedImage)
                    }
                }

                if let lazyPlayer, let playerItem = lazyPlayer.currentItem {
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
                    Task {
                        if let duration = try? await playerItem.asset.load(.duration) {
                            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] =
                                duration.seconds
                        }
                    }
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = lazyPlayer.rate
                }

                // Set the metadata
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([[.banner, .sound]])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        handleNotification(userInfo: userInfo)
        completionHandler(UIBackgroundFetchResult.newData)
    }

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let finalTarget = userInfo["target"] as? String else {
            return
        }

        if let mainController = mainViewController as? MainViewController, let mainNavigationController {
            if mainController.handleSpecialUrl(url: finalTarget) {
                return
            }

            if let lbryUrl = LbryUri.tryParse(url: finalTarget, requireProto: false) {
                if lbryUrl.isChannel {
                    let vc = mainController.storyboard?
                        .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    mainNavigationController.pushViewController(vc, animated: true)
                } else {
                    let vc = mainController.storyboard?
                        .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    mainNavigationController.pushViewController(vc, animated: true)
                }
            }
        } else {
            pendingOpenUrl = finalTarget
        }
    }

    func resetPlayerObserver() {
        playerObserverAdded = false
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let index = tabBarController.selectedIndex
        let defaults = UserDefaults.standard
        defaults.setValue(index, forKey: AppDelegate.keyLastTabIndex)
    }

    enum CommandCenterCommands {
        case play
        case pause
        case togglePlayPause
        case changePlaybackRate
        case skipBackward
        case skipForward
        case changePlaybackPosition
    }
}
