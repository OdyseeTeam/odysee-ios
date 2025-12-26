//
//  PublishesViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 26/02/2021.
//

import FirebaseAnalytics
import OrderedCollections
import UIKit

class PublishesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet var noUploadsView: UIView!
    @IBOutlet var uploadsListView: UITableView!
    @IBOutlet var loadingContainer: UIView!

    var newPlaceholderAdded = false
    var longPressGestureRecognizer: UILongPressGestureRecognizer!
    var loadingUploads = false
    var uploads = OrderedSet<Claim>()
    var currentPage: Int = 1
    var pageSize: Int = 50

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        uploadsListView.tableFooterView = UIView()

        longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleUploadCellLongPress)
        )
        uploadsListView.addGestureRecognizer(longPressGestureRecognizer)
        uploadsListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Uploads",
                AnalyticsParameterScreenClass: "PublishesViewController",
            ]
        )

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
        loadUploads()
    }

    func addNewPlaceholder() {
        if newPlaceholderAdded {
            return
        }
        let newPlaceholder = Claim()
        newPlaceholder.claimId = "new"
        uploads.append(newPlaceholder)
        newPlaceholderAdded = true
    }

    func loadUploads() {
        if loadingUploads {
            return
        }

        loadingUploads = true
        loadingContainer.isHidden = false

        Lbry.apiCall(
            method: LbryMethods.claimList,
            params: .init(
                claimType: [.stream],
                page: currentPage,
                pageSize: pageSize,
                resolve: true
            )
        )
        .subscribeResult(didReceiveUploads)
    }

    func didReceiveUploads(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        if case let .success(page) = result {
            uploads.removeAll()
            uploads.append(contentsOf: page.items)
            uploadsListView.reloadData()
            Lbry.ownUploads = uploads.filter { $0.claimId != "new" }
        }
        result.showErrorIfPresent()
        loadingUploads = false
        loadingContainer.isHidden = true
        uploadsListView.isHidden = uploads.isEmpty
        noUploadsView.isHidden = !uploads.isEmpty
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
     }
     */

    func abandonClaim(claim: Claim) {
        guard let claimId = claim.claimId else {
            showError(message: "claim has nil claimId")
            return
        }
        Lbry.apiCall(
            method: LbryMethods.streamAbandon,
            params: .init(
                claimId: claimId,
                blocking: true
            )
        )
        .subscribeResult(didAbandonClaim)
    }

    func didAbandonClaim(_ result: Result<Transaction, Error>) {
        assert(Thread.isMainThread)
        // TODO: Handle failure and re-insert the row.
        result.showErrorIfPresent()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploads.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell

        let claim: Claim = uploads[indexPath.row]
        cell.setClaim(claim: claim)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = uploads[indexPath.row]
        if claim.claimId == "new" {
            let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
            return
        }

        let vc = AppDelegate.shared.mainController.storyboard?
            .instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = claim
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @objc func handleUploadCellLongPress(sender: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == .began {
            let touchPoint = longPressGestureRecognizer.location(in: uploadsListView)
            if let indexPath = uploadsListView.indexPathForRow(at: touchPoint) {
                let claim: Claim = uploads[indexPath.row]
                let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
                vc.currentClaim = claim
                AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
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
            let claim: Claim = uploads[indexPath.row]
            if claim.claimId == "new" {
                return
            }

            // show confirmation dialog before deleting
            let alert = UIAlertController(
                title: String.localized("Abandon content?"),
                message: String.localized("Are you sure you want to delete this upload?"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
                self.abandonClaim(claim: claim)
                self.uploads.remove(at: indexPath.row)
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

    @IBAction func newUploadTapped(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }
}
