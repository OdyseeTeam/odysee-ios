//
//  SearchViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 12/11/2020.
//

import Firebase
import OrderedCollections
import SafariServices
import UIKit

class SearchViewController: UIViewController,
                            UIGestureRecognizerDelegate,
                            UISearchBarDelegate,
                            UITableViewDelegate,
                            UITableViewDataSource,
                            UITableViewDataSourcePrefetching {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var getStartedView: UIStackView!
    @IBOutlet weak var noResultsView: UIStackView!
    @IBOutlet weak var noResultsLabel: UILabel!
    
    @IBOutlet weak var resultsListView: UITableView!
    @IBOutlet weak var loadingContainer: UIView!
    
    var searchTask: DispatchWorkItem?
    var currentFrom = 0
    var currentQuery: String? = nil
    var searching: Bool = false
    let pageSize = 20
    var claims = OrderedSet<Claim>()
    var prefetchController: ImagePrefetchingController!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: true)
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Search", AnalyticsParameterScreenClass: "SearchViewController"])
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        prefetchController = ImagePrefetchingController { [unowned self] indexPath in
            return ClaimTableViewCell.imagePrefetchURLs(claim: self.claims[indexPath.row])
        }
        
        loadingContainer.layer.cornerRadius = 20
        
        getStartedView.isHidden = false
        searchBar.backgroundImage = UIImage()
        
        resultsListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
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
            guard let results = results, !results.isEmpty else {
                DispatchQueue.main.async {
                    self.checkNoResults()
                }
                return
            }
            
            var params = [String: Any]()
            params["urls"] = results.compactMap { dict -> String? in
                let name = dict["name"] as! String
                let id = dict["claimId"] as! String
                let str = [name, id].joined(separator: "#")
                return LbryUri.tryParse(url: str, requireProto: false)?.description
            }
            Lbry.apiCall(method: Lbry.Methods.resolve,
                         params: params,
                         transform: { table in
                            table.values.forEach(Lbry.addClaimToCache)
                         },
                         completion: self.didResolveResults)
        })
    }
    
    func didResolveResults(_ result: Result<[String: Claim], Error>) {
        result.showErrorIfPresent()
        if case let .success(claimDict) = result {
            let oldCount = claims.count
            claims.append(contentsOf: claimDict.values)
            if claims.count != oldCount {
                resultsListView.reloadData()
            }
        }
        checkNoResults()
        searching = false
        loadingContainer.isHidden = true
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
        assert(Thread.isMainThread)
        loadingContainer.isHidden = true
        noResultsView.isHidden = !claims.isEmpty
        noResultsLabel.text = Lighthouse.containsFilteredKeyword(currentQuery!) ?
            String.localized("This search term is disabled to comply with iOS content guidelines. View this search on the web at odysee.com") :
            String.localized("Oops! We could not find any content matching your search term. Please try again with something different.")
    }
    
    @IBAction func noResultsViewTapped(_ sender: Any) {
        if Lighthouse.containsFilteredKeyword(currentQuery!) {
            if let url = URL(string: String(format: "https://odysee.com/$/search?q=%@", currentQuery!)) {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
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
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        prefetchController.prefetch(at: indexPaths)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        prefetchController.cancelPrefetching(at: indexPaths)
    }
}
