//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import UIKit

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var claimListView: UITableView!
    @IBOutlet weak var categoryButtonsContainer: UIStackView!
    @IBOutlet weak var noContentView: UIStackView!
    
    var refreshControl = UIRefreshControl()
    
    let categories: [String] = ["All", "Enlightenment", "Gaming", "Lab", "Tech", "News", "Finance 2.0", "Nice People", "The Rabbit Hole"]
    let channelIds: [[String]] = [
        ContentSources.PrimaryChannelContentIds,
        ContentSources.EnlightenmentChannelIds,
        ContentSources.GamingChannelIds,
        ContentSources.ScienceChannelIds,
        ContentSources.TechnologyChannelIds,
        ContentSources.NewsChannelIds,
        ContentSources.FinanceChannelIds,
        ContentSources.CommunityChannelIds,
        ContentSources.RabbitHoleChannelIds
    ]
    var currentCategoryIndex: Int = 0
    var categoryButtons: [UIButton] = []
    var options = Dictionary<String, Any>()
    
    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loading: Bool = false
    var claims: [Claim] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        refreshControl.attributedTitle = NSAttributedString(string: "Pull down to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        refreshControl.tintColor = Helper.primaryColor
        claimListView.addSubview(refreshControl)
        
        loadingContainer.layer.cornerRadius = 20
        
        categories.forEach{ category in
            self.addCategoryButton(label: category)
        }
        selectCategoryButton(button: categoryButtons[0])
        
        if (claims.count == 0) {
            loadClaims()
        }
    }
    
    func updateClaimSearchOptions() {
        options = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: channelIds[currentCategoryIndex], notChannelIds: nil, orderBy: ["release_time"], releaseTime: nil, maxDuration: nil, limitClaimsPerChannel: 5, page: currentPage, pageSize: pageSize)
    }
    
    func loadClaims() {
        if (loading) {
            return
        }
        
        noContentView.isHidden = true
        loadingContainer.isHidden = false
        loading = true
        
        updateClaimSearchOptions()
        Lbry.apiCall(method: Lbry.methodClaimSearch, params: options, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            if (data != nil) {
                let result = data?["result"] as? [String: Any]
                let items = result?["items"] as? [[String: Any]]
                if (items != nil) {
                    var loadedClaims: [Claim] = []
                    items?.forEach{ item in
                        let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                        do {
                            let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                            if (claim != nil && !self.claims.contains(where: { $0.claimId == claim?.claimId })) {
                                loadedClaims.append(claim!)
                            }
                        } catch let error {
                            print(error)
                        }
                    }
                    self.claims.append(contentsOf: loadedClaims)
                    self.claims.sort(by: { Int64($0.value?.releaseTime ?? "0")! > Int64($1.value?.releaseTime ?? "0")! })
                }
            }
            
            self.loading = false
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
                self.checkNoContent()
                self.claimListView.reloadData()
                self.refreshControl.endRefreshing()
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
        
        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = claim
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (claimListView.contentOffset.y >= (claimListView.contentSize.height - claimListView.bounds.size.height)) {
            if (!loading) {
                currentPage += 1
                loadClaims()
            }
        }
    }
    
    func addCategoryButton(label: String) {
        let button = UIButton(type: .system)
        button.contentEdgeInsets = UIEdgeInsets.init(top: 4, left: 20, bottom: 4, right: 20)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = Helper.primaryColor.cgColor
        button.setTitle(label, for: .normal)
        button.setTitleColor(UIColor.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.addTarget(self, action: #selector(self.categoryButtonTapped), for: .touchUpInside)
        
        categoryButtons.append(button)
        categoryButtonsContainer.addArrangedSubview(button)
    }
    
    @objc func categoryButtonTapped(sender: UIButton) {
        for button in categoryButtons {
            if (button.backgroundColor == Helper.primaryColor) {
                button.backgroundColor = UIButton(type: .roundedRect).backgroundColor
                button.setTitleColor(UIColor.black, for: .normal)
                break
            }
        }
        selectCategoryButton(button: sender)
        
        let category = sender.title(for: .normal)
        
        currentCategoryIndex = categories.firstIndex(of: category!)!
        currentPage = 1
        loading = false
        
        claims.removeAll()
        claimListView.reloadData()
        loadClaims()
    }
    
    func selectCategoryButton(button: UIButton) {
        button.backgroundColor = Helper.primaryColor
        button.setTitleColor(UIColor.white, for: .normal)
    }
    
    func checkNoContent() {
        DispatchQueue.main.async {
            self.noContentView.isHidden = self.claims.count > 0
        }
    }
    
    @objc func refresh(_ sender: AnyObject) {
        if (loading) {
            return
        }
        
        currentPage = 1
        claims.removeAll()
        claimListView.reloadData()
        loadClaims()
    }
}
