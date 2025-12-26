//
//  ChannelManagerViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import FirebaseAnalytics
import UIKit

class ChannelManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,
    UIGestureRecognizerDelegate
{
    @IBOutlet var channelListView: UITableView!
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var noChannelsView: UIView!
    @IBOutlet var newChannelButton: UIButton!

    var longPressGestureRecognizer: UILongPressGestureRecognizer!

    var loadingChannels = false
    var channels: [Claim] = []

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
                AnalyticsParameterScreenName: "Channels",
                AnalyticsParameterScreenClass: "ChannelManagerViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self

        loadChannels()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        channelListView.tableFooterView = UIView()
        loadChannels()

        longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleUploadCellLongPress)
        )
        channelListView.addGestureRecognizer(longPressGestureRecognizer)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func addNewPlaceholder() {
        let newPlaceholder = Claim()
        newPlaceholder.claimId = "new"
        channels.append(newPlaceholder)
    }

    func loadChannels() {
        if loadingChannels {
            return
        }

        loadingChannels = true
        loadingContainer.isHidden = false
        channelListView.isHidden = channels.count <= 1
        noChannelsView.isHidden = true

        Lbry.apiCall(
            method: LbryMethods.claimList,
            params: .init(
                claimType: [.channel],
                page: 1,
                pageSize: 999,
                resolve: true
            )
        )
        .subscribeResult(didLoadChannels)
    }

    func didLoadChannels(_ result: Result<Page<Claim>, Error>) {
        loadingChannels = false
        loadingContainer.isHidden = true
        guard case let .success(page) = result else {
            checkNoChannels()
            result.showErrorIfPresent()
            return
        }

        channels.removeAll(keepingCapacity: true)
        addNewPlaceholder()
        channels.append(contentsOf: page.items)
        Lbry.ownChannels = channels.filter { $0.claimId != "new" }
        checkNoChannels()
        channelListView.reloadData()
    }

    func abandonChannel(channel: Claim) {
        guard let claimId = channel.claimId else {
            showError(message: "channel has nil claimId")
            return
        }
        Lbry.apiCall(
            method: LbryMethods.channelAbandon,
            params: .init(
                claimId: claimId,
                blocking: true
            )
        )
        .subscribeResult { result in
            result.showErrorIfPresent()
        }
    }

    func checkNoChannels() {
        DispatchQueue.main.async {
            self.channelListView.isHidden = self.channels.count <= 1
            self.noChannelsView.isHidden = self.channels.count > 1
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return channels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "channel_list_cell",
            for: indexPath
        ) as! ChannelListTableViewCell

        let claim: Claim = channels[indexPath.row]
        cell.setClaim(claim: claim)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = channels[indexPath.row]
        if claim.claimId == "new" {
            let vc = storyboard?
                .instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
            navigationController?.pushViewController(vc, animated: true)
            return
        }

        let vc = AppDelegate.shared.mainController.storyboard?
            .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
        vc.channelClaim = claim
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @objc func handleUploadCellLongPress(sender: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == .began {
            let touchPoint = longPressGestureRecognizer.location(in: channelListView)
            if let indexPath = channelListView.indexPathForRow(at: touchPoint) {
                let claim: Claim = channels[indexPath.row]
                let vc = storyboard?
                    .instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
                if claim.claimId != "new" {
                    vc.currentClaim = claim
                }
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            // abandon channel
            let claim: Claim = channels[indexPath.row]
            if claim.claimId == "new" {
                return
            }

            // show confirmation dialog before deleting
            let alert = UIAlertController(
                title: String.localized("Abandon channel?"),
                message: String.localized("Are you sure you want to delete this channel?"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
                self.abandonChannel(channel: claim)
                self.channels.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }))
            alert.addAction(UIAlertAction(title: String.localized("No"), style: .destructive))
            present(alert, animated: true)
        }
    }

    func showError(message: String?) {
        AppDelegate.shared.mainController.showError(message: message)
    }

    func showError(error: Error?) {
        AppDelegate.shared.mainController.showError(error: error)
    }

    @IBAction func backTapped(_ sender: Any) {
        // show alert for unsaved changes before going back

        navigationController?.popViewController(animated: true)
    }

    @IBAction func newChannelTapped(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
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
