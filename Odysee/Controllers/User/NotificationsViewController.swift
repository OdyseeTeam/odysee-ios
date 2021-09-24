//
//  NotificationsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 10/12/2020.
//

import Firebase
import UIKit

class NotificationsViewController: UIViewController, UIGestureRecognizerDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var emptyView: UIView!
    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var notificationsListView: UITableView!
    let refreshControl = UIRefreshControl()
    
    var loadingNotifications = false
    var notifications: [LbryNotification] = Lbryio.cachedNotifications
    var authorThumbnailMap = [String: URL]()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.isHidden = !Lbryio.isSignedIn()
    
        AppDelegate.shared.mainController.notificationBadgeIcon.tintColor = Helper.primaryColor
        AppDelegate.shared.mainController.notificationsViewActive = true
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
        
        if (!Lbryio.isSignedIn()) {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Notifications", AnalyticsParameterScreenClass: "NotificationsViewController"])
        
        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.shared.mainController.notificationBadgeIcon.tintColor = UIColor.label
        AppDelegate.shared.mainController.notificationsViewActive = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        notificationsListView.tableFooterView = UIView()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull down to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        refreshControl.tintColor = Helper.primaryColor
        notificationsListView.addSubview(refreshControl)
        
        markNotificationsSeen()
        loadNotifications()
    }
    
    func markNotificationsSeen() {
        var seenIds: [Int64] = []
        for index in 0..<Lbryio.cachedNotifications.count {
            if !Lbryio.cachedNotifications[index].isSeen! {
                Lbryio.cachedNotifications[index].isSeen = true
                seenIds.append(Lbryio.cachedNotifications[index].id!)
            }
        }
        
        self.notifications = Lbryio.cachedNotifications
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.updateUnseenCount()
        }
            
        // send remote request
        if seenIds.count > 0 {
            var options: Dictionary<String, String> = [:]
            options["notification_ids"] = seenIds.map { String($0) }.joined(separator: ",");
            options["is_seen"] = "true"
            do {
                try Lbryio.post(resource: "notification", action: "edit", options: options, completion: { data, error in
                    guard let _ = data, error == nil else {
                        return
                    }
                })
            } catch {
                // pass
            }
        }
    }
    
    func markSingleNotificationRead(id: Int64) {
        if let index = Lbryio.cachedNotifications.firstIndex(where: { $0.id == id }) {
            Lbryio.cachedNotifications[index].isRead = true
            Lbryio.cachedNotifications[index].isSeen = true
            self.notifications = Lbryio.cachedNotifications
            DispatchQueue.main.async {
                self.notificationsListView.reloadData()
            }
            
            var options: Dictionary<String, String> = [:]
            options["notification_ids"] = String(id)
            options["is_seen"] = "true"
            options["is_read"] = "true"
            do {
                try Lbryio.post(resource: "notification", action: "edit", options: options, completion: { data, error in
                    guard let _ = data, error == nil else {
                        return
                    }
                })
            } catch {
                // pass
            }
        }
    }
    
    func deleteNotification(id: Int64) {
        var options: Dictionary<String, String> = [:]
        options["notification_ids"] = String(id)
        do {
            try Lbryio.post(resource: "notification", action: "delete", options: options, completion: { data, error in
                guard let _ = data, error == nil else {
                    return
                }
            })
        } catch {
            // pass
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func loadNotifications() {
        if loadingNotifications {
            return
        }
        
        loadingNotifications = true
        self.emptyView.isHidden = true
        self.notificationsListView.isHidden = notifications.count == 0
        self.loadingContainer.isHidden = false
        
        do {
            var options: Dictionary<String, String> = [:]
            if Lbryio.latestNotificationId > 0 {
                options["since_id"] = String(Lbryio.latestNotificationId)
            }
            try Lbryio.post(resource: "notification", action: "list", options: options, completion: { data, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        self.loadingContainer.isHidden = true
                    }
                    self.loadingNotifications = false
                    self.showError(error: error)
                    self.checkNoNotifications()
                    return
                }
                
                if let items = data as? [[String: Any]] {
                    var loadedNotifications: [LbryNotification] = []
                    items.forEach { item in
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: item as Any, options: [.prettyPrinted, .sortedKeys])
                            let notification: LbryNotification? = try JSONDecoder().decode(LbryNotification.self, from: jsonData)
                            if notification != nil && !self.notifications.contains(where: { $0.id == notification?.id }) {
                                loadedNotifications.append(notification!)
                            }
                        } catch {
                            // pass
                        }
                    }
                    self.notifications.append(contentsOf: loadedNotifications)
                    self.notifications.sort(by: { ($0.createdAt ?? "") > ($1.createdAt ?? "")! })
                    Lbryio.cachedNotifications = self.notifications
                    Lbryio.latestNotificationId = Lbryio.cachedNotifications.map{ $0.id! }.max() ?? 0
                }
                
                self.loadingNotifications = false
                DispatchQueue.main.async {
                    self.loadingContainer.isHidden = true
                    self.checkNoNotifications()
                    self.resolveCommentAuthors()
                    self.notificationsListView.reloadData()
                    self.refreshControl.endRefreshing()
                }
            })
        } catch let error {
            self.showError(error: error)
        }
    }
    
    func resolveCommentAuthors() {
        Lbry.apiCall(method: Lbry.Methods.resolve,
                     params: .init(
                        urls: notifications.filter { !($0.author ?? "").isBlank }.map { $0.author! }
                     ))
            .subscribeResult(didResolveCommentAuthors)
    }
    
    func didResolveCommentAuthors(_ result: Result<ResolveResult, Error>) {
        guard case let .success(resolve) = result else {
            return
        }
        Helper.addThumbURLs(claims: resolve.claims, thumbURLs: &authorThumbnailMap)
        notificationsListView.reloadData()
    }

    func checkNoNotifications() {
        DispatchQueue.main.async {
            self.emptyView.isHidden = self.notifications.count != 0
            self.notificationsListView.isHidden = self.notifications.count == 0
        }
    }
    
    func showError(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }
    
    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "notification_cell", for: indexPath) as! NotificationTableViewCell
        
        let notification: LbryNotification = notifications[indexPath.row]
        cell.setNotification(notification: notification)
        cell.setAuthorImageMap(map: authorThumbnailMap)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let notification: LbryNotification = notifications[indexPath.row]
        
        if notification.targetUrl != nil {
            markSingleNotificationRead(id: notification.id!)
            
            if AppDelegate.shared.mainController.handleSpecialUrl(url: notification.targetUrl!) {
                self.navigationController?.popViewController(animated: true)
                return
            }
            
            let lbryUrl = LbryUri.tryParse(url: notification.targetUrl!, requireProto: false)
            if lbryUrl != nil {
                if lbryUrl!.isChannelUrl() {
                    let vc = storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = lbryUrl
                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = lbryUrl
                    AppDelegate.shared.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let notification: LbryNotification = notifications[indexPath.row]
            self.deleteNotification(id: notification.id!)
            self.notifications.remove(at: indexPath.row)
            Lbryio.cachedNotifications = notifications
            
            tableView.deleteRows(at: [indexPath], with: .fade)
       }
    }

    @objc func refresh(_ sender: AnyObject) {
        if (loadingNotifications) {
            refreshControl.endRefreshing()
            return
        }
        
        loadNotifications()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
