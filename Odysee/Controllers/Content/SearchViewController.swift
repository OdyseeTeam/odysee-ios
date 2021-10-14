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
    UITableViewDataSourcePrefetching
{
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var getStartedView: UIStackView!
    @IBOutlet var noResultsView: UIStackView!
    @IBOutlet var noResultsLabel: UILabel!

    @IBOutlet var resultsListView: UITableView!
    @IBOutlet var loadingContainer: UIView!

    var searchTask: DispatchWorkItem?
    var currentFrom = 0
    var currentQuery: String?
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
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [AnalyticsParameterScreenName: "Search", AnalyticsParameterScreenClass: "SearchViewController"]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        prefetchController = ImagePrefetchingController { [unowned self] indexPath in
            ClaimTableViewCell.imagePrefetchURLs(claim: self.claims[indexPath.row])
        }

        loadingContainer.layer.cornerRadius = 20

        getStartedView.isHidden = false
        searchBar.backgroundImage = UIImage()

        resultsListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
    }

    func resolveWinning(query: String) {
        var sanitisedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSMakeRange(0, sanitisedQuery.count)
        sanitisedQuery = LbryUri.regexInvalidUri.stringByReplacingMatches(
            in: query,
            options: [],
            range: range,
            withTemplate: ""
        )

        var possibleUrls = [String(format: "lbry://%@", sanitisedQuery)]
        if !sanitisedQuery.starts(with: "@") {
            // if it's not a channel url, add the channel url as a possible url
            possibleUrls.append(String(format: "lbry://@%@", sanitisedQuery))
        }

        Lbry.apiCall(
            method: Lbry.Methods.resolve,
            params: .init(urls: possibleUrls)
        )
        .subscribeResult(didResolveWinning)
    }

    func didResolveWinning(_ result: Result<ResolveResult, Error>) {
        if case let .success(resolve) = result {
            var winningClaims: [Claim] = []
            winningClaims.append(contentsOf: resolve.claims.values)

            if winningClaims.count > 0 {
                winningClaims
                    .sort(by: {
                        Decimal(string: $1.meta?.effectiveAmount ?? "0")! >
                            Decimal(string: $0.meta?.effectiveAmount ?? "0")!
                    })
                let winningClaim = winningClaims[0]
                winningClaim.featured = true

                // check if the winning claim could be mature content
                var isMature = false
                if let tags = winningClaim.value?.tags {
                    isMature = tags.contains(where: Constants.MatureTags.contains)
                }

                if !isMature {
                    // in some cases, some mature content may not be properly tagged (possibly due to abuse)
                    // check the claim name, title or description just in case
                    for matureTag in Constants.MatureTags {
                        // TODO: Move this check into a helper method?
                        if winningClaim.name!.contains(matureTag) {
                            isMature = true
                            break
                        }
                        if let title = winningClaim.value?.title {
                            if title.contains(matureTag) {
                                isMature = true
                                break
                            }
                        }
                        if let description = winningClaim.value?.description {
                            if description.contains(matureTag) {
                                isMature = true
                                break
                            }
                        }
                    }
                }

                // only show the winning claim if it is not mature content
                if !isMature {
                    // if the claim is already in the search results, remove it so we can promote to the top
                    claims.removeAll(where: { $0.claimId == winningClaim.claimId })
                    claims.insert(winningClaim, at: 0)
                    resultsListView.reloadData()
                    checkNoResults()
                }
            }
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func search(query: String?, from: Int) {
        if (query ?? "").isBlank || (currentQuery == query && currentFrom == from) {
            return
        }

        if from == 0 {
            Analytics.logEvent("search", parameters: ["query": query!])
        }

        getStartedView.isHidden = true
        noResultsView.isHidden = true
        loadingContainer.isHidden = false

        searching = true
        currentQuery = query
        currentFrom = from
        Lighthouse.search(
            rawQuery: query!,
            size: pageSize,
            from: currentFrom,
            relatedTo: nil,
            completion: { results, _ in
                guard let results = results, !results.isEmpty else {
                    DispatchQueue.main.async {
                        self.searching = false
                        self.checkNoResults()
                    }
                    return
                }

                let urls = results.compactMap { item in
                    LbryUri.tryParse(
                        url: String(format: "%@#%@", item["name"] as! String, item["claimId"] as! String),
                        requireProto: false
                    )?.description
                }
                Lbry.apiCall(
                    method: Lbry.Methods.resolve,
                    params: .init(urls: urls)
                )
                .subscribeResult(self.didResolveResults)
            }
        )
    }

    func didResolveResults(_ result: Result<ResolveResult, Error>) {
        result.showErrorIfPresent()
        if case let .success(resolve) = result {
            let oldCount = claims.count
            claims.append(contentsOf: resolve.claims.values)
            if claims.count != oldCount {
                resultsListView.reloadData()
            }

            // try to resolve the winning claim after loading initial set of results
            if let query = currentQuery {
                resolveWinning(query: query)
            }
        }
        checkNoResults()
        searching = false
        loadingContainer.isHidden = true
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // disable auto search. Consider making this a toggled setting in the future?
        /* self.searchTask?.cancel()
         let task = DispatchWorkItem { [weak self] in
             if (!searchText.isBlank && searchText != (self?.currentQuery ?? "")) {
                 self?.resetSearch()
             }
             self?.search(query: searchText, from: 0)
         }
         self.searchTask = task
         DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5, execute: task) */
    }

    func resetSearch() {
        claims = []
        DispatchQueue.main.async {
            self.resultsListView.reloadData()
        }
    }

    func checkNoResults() {
        assert(Thread.isMainThread)
        loadingContainer.isHidden = true
        noResultsView.isHidden = !claims.isEmpty
        noResultsLabel.text = Lighthouse.containsFilteredKeyword(currentQuery!) ?
            String
            .localized(
                "This search term is disabled to comply with iOS content guidelines. View this search on the web at odysee.com"
            ) :
            String
            .localized(
                "Oops! We could not find any content matching your search term. Please try again with something different."
            )
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
        navigationController?.popViewController(animated: true)
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
        if claim.name!.starts(with: "@") {
            // channel claim
            let vc = storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = claim
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        } else {
            // file claim
            let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
            vc.claim = claim
            appDelegate.mainNavigationController?.view.layer.add(
                Helper.buildFileViewTransition(),
                forKey: kCATransition
            )
            appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if resultsListView.contentOffset
            .y >= (resultsListView.contentSize.height - resultsListView.bounds.size.height)
        {
            if !searching {
                search(query: currentQuery, from: currentFrom + pageSize)
            }
        }
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if searching {
            return
        }
        resetSearch()
        search(query: searchBar.searchTextField.text, from: 0)
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        prefetchController.prefetch(at: indexPaths)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        prefetchController.cancelPrefetching(at: indexPaths)
    }
}
