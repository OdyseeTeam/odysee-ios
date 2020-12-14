//
//  ChannelManagerViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import Firebase
import UIKit

class ChannelManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var channelListView: UITableView!
    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var noChannelsView: UIView!
    @IBOutlet weak var newChannelButton: UIButton!
    
    var loadingChannels = false
    var channels: [Claim] = []
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Channels", AnalyticsParameterScreenClass: "ChannelManagerViewController"])
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        loadChannels()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        channelListView.tableFooterView = UIView()
        loadChannels()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func addNewPlaceholder() {
        let newPlaceholder = Claim()
        newPlaceholder.claimId = "new"
        self.channels.append(newPlaceholder)
    }
    
    func loadChannels() {
        if loadingChannels {
            return
        }
        
        loadingChannels = true
        loadingContainer.isHidden = false
        channelListView.isHidden = channels.count <= 1
        noChannelsView.isHidden = true
        
        var options = Dictionary<String, Any>()
        options["claim_type"] = ["channel"]
        options["page"] = 1
        options["page_size"] = 999
        options["resolve"] = true
        Lbry.apiCall(method: Lbry.methodClaimList, params: options, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                self.loadingChannels = false
                self.loadingContainer.isHidden = true
                self.checkNoChannels()
                return
            }
            
            let result = data["result"] as? [String: Any]
            let items = result?["items"] as? [[String: Any]]
            if (items != nil) {
                var loadedClaims: [Claim] = []
                items?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claim != nil) {
                            loadedClaims.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.channels.removeAll()
                self.addNewPlaceholder()
                self.channels.append(contentsOf: loadedClaims)
                Lbry.ownChannels = self.channels.filter { $0.claimId != "new" }
            }
            
            self.loadingChannels = false
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
                self.checkNoChannels()
                self.channelListView.reloadData()
            }
        })
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "channel_list_cell", for: indexPath) as! ChannelListTableViewCell
        
        let claim: Claim = channels[indexPath.row]
        cell.setClaim(claim: claim)
            
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = channels[indexPath.row]
        let vc = storyboard?.instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
        if claim.claimId != "new" {
            vc.currentClaim = claim
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func showError(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    @IBAction func backTapped(_ sender: Any) {
        // show alert for unsaved changes before going back
        
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func newChannelTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = self.storyboard?.instantiateViewController(identifier: "channel_editor_vc") as! ChannelEditorViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
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
