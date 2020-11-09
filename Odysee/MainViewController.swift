//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import UIKit

class MainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var claimListView: UITableView!
    
    var claims: [Claim] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        if (claims.count == 0) {
            loadClaims()
        }
    }
    
    func loadClaims() {
        activityIndicator.isHidden = false
        
        let options = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: ContentSources.PrimaryChannelContentIds, notChannelIds: nil, orderBy: ["release_time"], releaseTime: nil, maxDuration: nil, limitClaimsPerChannel: 1, page: 1, pageSize: 50)
        
        print("loading claims...")
        Lbry.apiCall(method: Lbry.methodClaimSearch, params: options, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            if (data != nil) {
                let result = data?["result"] as? [String: Any]
                let items = result?["items"] as? [[String: Any]]
                if (items != nil) {
                    var loadedClaims: [Claim] = []
                    items?.forEach{ item in
                        let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                        if let JSONString = String(data: data, encoding: String.Encoding.utf8) {
                           print(JSONString)
                        }
                        do {
                            let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                            if (claim != nil) {
                                loadedClaims.append(claim!)
                            }
                        } catch let error {
                            print(error)
                        }
                    }
                    self.claims.append(contentsOf: loadedClaims)
                }
            }
            
            DispatchQueue.main.async {
                self.activityIndicator.isHidden = true
                self.claimListView.reloadData()
                
            }
        })
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return claims.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! FileTableViewCell
        
        let claim: Claim = claims[indexPath.row]
        cell.setClaim(claim: claim)
            
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = claims[indexPath.row]
        print("cell clicked for claim: " + (claim.value?.title ?? ""))
        
        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = claim
        vc.modalPresentationStyle = .automatic
        present(vc, animated: true)
    }
    
    

}

extension UIImageView {
    func load(url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.image = image
                    }
                }
            }
        }
    }
}

