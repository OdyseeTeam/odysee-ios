//
//  SearchViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/11/2020.
//

import Firebase
import UIKit

class SearchViewController: UIViewController, UIGestureRecognizerDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var getStartedView: UIStackView!
    @IBOutlet weak var noResultsView: UIStackView!
    
    @IBOutlet weak var resultsListView: UITableView!
    @IBOutlet weak var loadingContainer: UIView!
    
    var searchTask: DispatchWorkItem?
    var currentFrom = 0
    var currentQuery: String? = nil
    var searching: Bool = false
    let pageSize = 20
    var claims: [Claim] = []
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Search", AnalyticsParameterScreenClass: "SearchViewController"])
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        
        getStartedView.isHidden = false
        searchBar.backgroundImage = UIImage()
        //searchBar.becomeFirstResponder()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func search(query: String?, from: Int) {
        if ((query ?? "").isBlank || (currentQuery == query && currentFrom == from)) {
            return
        }
        
        if (from == 0) {
            Analytics.logEvent("search", parameters: ["query": query!])
        }
        
        getStartedView.isHidden = true
        noResultsView.isHidden = true
        loadingContainer.isHidden = false
        
        searching = true
        currentQuery = query
        currentFrom = from
        Lighthouse.search(rawQuery: query!, size: pageSize, from: currentFrom, relatedTo: nil, completion: { results, error in
            if (results == nil || results!.count == 0) {
                self.checkNoResults()
                return
            }
            
            var resolveUrls: [String] = []
            for item in results! {
                let lbryUri = LbryUri.tryParse(url: String(format: "%@#%@", item["name"] as! String, item["claimId"] as! String), requireProto: false)
                if (lbryUri != nil) {
                    resolveUrls.append(lbryUri!.description)
                }
            }
            
            self.resolveAndDisplayResults(urls: resolveUrls)
        })
    }
    
    func resolveAndDisplayResults(urls: [String]) {
        var params: Dictionary<String, Any> = Dictionary<String, Any>()
        params["urls"] = urls
        
        Lbry.apiCall(method: Lbry.methodResolve, params: params, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                // display no results
                self.loadingContainer.isHidden = true
                self.checkNoResults()
                return
            }
            
            var claimResults: [Claim] = []
            let result = data["result"] as! NSDictionary
            for (_, claimData) in result {
                let data = try! JSONSerialization.data(withJSONObject: claimData, options: [.prettyPrinted, .sortedKeys])
                do {
                    let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                    if (claim != nil && !(claim?.claimId ?? "").isBlank && !self.claims.contains(where: { $0.claimId == claim?.claimId })) {
                        Lbry.addClaimToCache(claim: claim)
                        claimResults.append(claim!)
                    }
                } catch let error {
                    print(error)
                }
            }
            self.claims.append(contentsOf: claimResults)
            self.searching = false
            
            DispatchQueue.main.async {
                self.loadingContainer.isHidden = true
                self.checkNoResults()
                self.searchBar.resignFirstResponder()
                self.resultsListView.reloadData()
            }
        })
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchTask?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            if (!searchText.isBlank && searchText != (self?.currentQuery ?? "")) {
                self?.resetSearch()
            }
            self?.search(query: searchText, from: 0)
        }
        self.searchTask = task
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5, execute: task)
    }
    
    func resetSearch() {
        self.claims = []
        DispatchQueue.main.async {
            self.resultsListView.reloadData()
        }
    }
    
    func checkNoResults() {
        DispatchQueue.main.async {
            self.loadingContainer.isHidden = true
            self.noResultsView.isHidden = self.claims.count > 0
        }
    }
    
    @IBAction func backTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return claims.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
        
        let claim: Claim = claims[indexPath.row]
        cell.setClaim(claim: claim)
            
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = claims[indexPath.row]
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (claim.name!.starts(with: "@")) {
            // channel claim
            let vc = storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = claim
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        } else {
            // file claim
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = claim
            appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (resultsListView.contentOffset.y >= (resultsListView.contentSize.height - resultsListView.bounds.size.height)) {
            if (!searching) {
                search(query: currentQuery, from: currentFrom + pageSize)
            }
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)  {
        searchBar.resignFirstResponder()
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
