//
//  ChannelListViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/12/2020.
//

import UIKit

class ChannelManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var channelListView: UITableView!
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var noChannelsView: UIView!
    @IBOutlet var newChannelButton: UIButton!

    var loadingChannels = false
    var channels: [Claim] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let newPlaceholder = Claim()
        newPlaceholder.claimId = "new"
        channels.append(newPlaceholder)

        loadChannels()
    }

    func loadChannels() {
        if loadingChannels {
            return
        }

        loadingChannels = true
        var options = [String: Any]()
        options["claim_type"] = ["channel"]
        options["page"] = 1
        options["page_size"] = 999
        options["resolve"] = true

        Lbry.apiCall(
            method: Lbry.methodClaimList,
            params: options,
            connectionString: Lbry.lbrytvConnectionString,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard let data = data, error == nil else {
                    self.showError(error: error)
                    self.loadingChannels = false
                    self.checkNoChannels()
                    return
                }

                let result = data["result"] as? [String: Any]
                let items = result?["items"] as? [[String: Any]]
                if items != nil {
                    var loadedClaims: [Claim] = []
                    items?.forEach { item in
                        let data = try! JSONSerialization.data(
                            withJSONObject: item,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        do {
                            let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                            if claim != nil, !self.channels.contains(where: { $0.claimId == claim?.claimId }) {
                                loadedClaims.append(claim!)
                            }
                        } catch {
                            print(error)
                        }
                    }
                    self.channels.append(contentsOf: loadedClaims)
                }

                self.loadingChannels = false
                DispatchQueue.main.async {
                    self.loadingContainer.isHidden = true
                    self.checkNoChannels()
                    self.channelListView.reloadData()
                }
            }
        )
    }

    func checkNoChannels() {}

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

    func showError(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }

    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
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
