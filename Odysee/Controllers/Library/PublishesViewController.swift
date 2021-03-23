//
//  PublishesViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 26/02/2021.
//

import Firebase
import UIKit

class PublishesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var noUploadsView: UIView!
    @IBOutlet weak var uploadsListView: UITableView!
    @IBOutlet weak var loadingContainer: UIView!
    
    var newPlaceholderAdded = false
    var longPressGestureRecognizer: UILongPressGestureRecognizer!
    var loadingUploads = false
    var uploads: [Claim] = []
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
        
        loadUploads()
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
        
        let options: Dictionary<String, Any> = ["claim_type": "stream", "page": currentPage, "page_size": pageSize, "resolve": true]
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                self.loadingUploads = false
                self.loadingContainer.isHidden = true
                self.checkNoUploads()
                return
            }
            
            let result = data["result"] as? [String: Any]
            if let items = result?["items"] as? [[String: Any]] {
                var loadedClaims: [Claim] = []
                items.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claim != nil && !self.uploads.contains(where: { $0.claimId == claim?.claimId })) {
                            loadedClaims.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                //self.uploads.removeAll()
                //self.addNewPlaceholder()
                self.uploads.append(contentsOf: loadedClaims)
                Lbry.ownUploads = self.uploads.filter { $0.claimId != "new" }
            }
            
            self.loadingUploads = false
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
                self.checkNoUploads()
                self.uploadsListView.reloadData()
            }
        })
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
        let params: Dictionary<String, Any> = ["claim_id": claim.claimId!, "blocking": true]
        Lbry.apiCall(method: Lbry.methodStreamAbandon, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                self.showError(error: error)
                return
            }
        })
    }
    
    func checkNoUploads() {
        DispatchQueue.main.async {
            self.uploadsListView.isHidden = self.uploads.count == 0
            self.noUploadsView.isHidden = self.uploads.count > 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploads.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "upload_list_cell", for: indexPath) as! ClaimTableViewCell
        
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
                self.showError(message: "You cannot remove a pending upload. Please try again later.")
                return
            }
            
            // show confirmation dialog before deleting
            let alert = UIAlertController(title: String.localized("Abandon channel?"), message: String.localized("Are you sure you want to delete this upload?"), preferredStyle: .alert)
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
