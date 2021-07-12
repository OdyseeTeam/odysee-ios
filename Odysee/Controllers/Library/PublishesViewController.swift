//
//  PublishesViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 26/02/2021.
//

import Firebase
import OrderedCollections
import UIKit

class PublishesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var noUploadsView: UIView!
    @IBOutlet weak var uploadsListView: UITableView!
    @IBOutlet weak var loadingContainer: UIView!
    
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
        loadUploads()
        
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleUploadCellLongPress))
        uploadsListView.addGestureRecognizer(longPressGestureRecognizer)
        uploadsListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Uploads", AnalyticsParameterScreenClass: "PublishesViewController"])
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
    }
    
    func addNewPlaceholder() {
        if newPlaceholderAdded {
            return
        }
        let newPlaceholder = Claim()
        newPlaceholder.claimId = "new"
        self.uploads.append(newPlaceholder)
        newPlaceholderAdded = true
    }
    
    func loadUploads() {
        if loadingUploads {
            return
        }
        
        loadingUploads = true
        loadingContainer.isHidden = false
        
        Lbry.apiCall(method: Lbry.Methods.claimList,
                     params: .init(
                        claimType: [.stream],
                        page: currentPage,
                        pageSize: pageSize,
                        resolve: true))
            .subscribeResult(didReceiveUploads)
    }
    

    func didReceiveUploads(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        if case let .success(page) = result {
            UIView.performWithoutAnimation {
                uploadsListView.performBatchUpdates {
                    let oldCount = uploads.count
                    uploads.append(contentsOf: page.items)
                    let indexPaths = (oldCount..<uploads.count).map { IndexPath(item: $0, section: 0) }
                    uploadsListView.insertRows(at: indexPaths, with: .none)
                }
            }
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
        Lbry.apiCall(method: Lbry.Methods.streamAbandon,
                     params: .init(
                        claimId: claim.claimId!,
                        blocking: true
                     ))
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
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
            return
        }
        
        let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
        vc.currentClaim = claim
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func handleUploadCellLongPress(sender: UILongPressGestureRecognizer){
        if longPressGestureRecognizer.state == .began {
            let touchPoint = longPressGestureRecognizer.location(in: uploadsListView)
            if let indexPath = uploadsListView.indexPathForRow(at: touchPoint) {
                let claim: Claim = uploads[indexPath.row]
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let vc = appDelegate.mainController.storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
                vc.claim = claim
                appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // abandon channel
            let claim: Claim = uploads[indexPath.row]
            if claim.claimId == "new" {
                return
            }
            
            if claim.confirmations ?? 0 == 0 {
                // pending claim
                self.showError(message: String.localized("You cannot remove a pending upload. Please try again later."))
                return
            }
            
            // show confirmation dialog before deleting
            let alert = UIAlertController(title: String.localized("Abandon content?"), message: String.localized("Are you sure you want to delete this upload?"), preferredStyle: .alert)
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
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    @IBAction func newUploadTapped(_ sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "publish_vc") as! PublishViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }
}
