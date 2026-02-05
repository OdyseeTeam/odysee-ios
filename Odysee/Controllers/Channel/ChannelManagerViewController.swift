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

    static let channelCreationLimit = 5

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
            method: BackendMethods.claimList,
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
            method: BackendMethods.channelAbandon,
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

        if channels.count > indexPath.row {
            let claim = channels[indexPath.row]
            cell.setClaim(claim: claim)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard channels.count > indexPath.row else {
            return
        }

        let claim = channels[indexPath.row]
        if claim.claimId == "new" {
            newChannelTapped(tableView)
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
            if let indexPath = channelListView.indexPathForRow(at: touchPoint),
               channels.count > indexPath.row
            {
                let claim = channels[indexPath.row]

                guard claim.claimId != "new" else {
                    return
                }

                let vc = storyboard?
                    .instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
                vc.currentClaim = claim
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard channels.count > indexPath.row else {
            return
        }

        if editingStyle == .delete {
            // abandon channel
            let claim = channels[indexPath.row]
            if claim.claimId == "new" {
                return
            }

            // show confirmation dialog before deleting
            let alert = UIAlertController(
                title: String.localized("Abandon channel?"),
                message: String.localized("Are you sure you want to delete this channel?"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .destructive, handler: { _ in
                self.abandonChannel(channel: claim)
                self.channels.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }))
            alert.addAction(UIAlertAction(title: String.localized("No"), style: .cancel))
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
        guard let user = Lbryio.currentUser else {
            showError(message: "Failed to get current user")
            return
        }

        var ids = channels.compactMap(\.claimId)
        if let ytChannels = user.youtubeChannels, ytChannels.count > 0 {
            let ytChannelIds = Set(ytChannels.compactMap(\.channelClaimId))
            ids = ids.filter {
                !ytChannelIds.contains($0)
            }
        }

        // https://github.com/OdyseeTeam/odysee-frontend/blob/9d7b39b5a8337b4b424aec458b133f02de8f5fca/ui/redux/selectors/claims.js#L1131
        guard ids.filter({ $0 != "new" }).count <= Self.channelCreationLimit else {
            showError(message: "Channel limit exceeded")
            return
        }

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
