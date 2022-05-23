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
    UIPickerViewDataSource,
    UIPickerViewDelegate,
    UITableViewDelegate,
    UITableViewDataSource,
    UITableViewDataSourcePrefetching
{
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var getStartedView: UIStackView!
    @IBOutlet var noResultsView: UIStackView!
    @IBOutlet var noResultsLabel: UILabel!
    @IBOutlet var filterButton: UIButton!
    @IBOutlet var typePickerView: UIPickerView!
    @IBOutlet var publishTimePicker: UIPickerView!
    @IBOutlet var fileTypesView: UIStackView!

    @IBOutlet var filterOptionsView: UIStackView!
    @IBOutlet var resultsListView: UITableView!
    @IBOutlet var loadingContainer: UIView!

    var searchTask: DispatchWorkItem?
    var currentFrom = 0
    var currentQuery: String?
    var searching: Bool = false
    let pageSize = 20
    var claims = OrderedSet<Claim>()
    var filteredClaims = OrderedSet<Claim>()
    var winningClaim: Claim?
    var prefetchController: ImagePrefetchingController!

    var showVideo = true
    var showAudio = true
    var showImage = true
    var showText = true

    let filterClaimTypes = ["Any", "File", "Channel"]

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
            ClaimTableViewCell.imagePrefetchURLs(claim: self.filteredClaims[indexPath.row])
        }

        loadingContainer.layer.cornerRadius = 20

        getStartedView.isHidden = false
        searchBar.backgroundImage = UIImage()

        resultsListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")
        typePickerView.selectRow(0 /* Any */, inComponent: 0, animated: false)
        publishTimePicker.selectRow(4 /* All Time */, inComponent: 0, animated: false)
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
                        Decimal(string: $0.meta?.effectiveAmount ?? "0")! >
                            Decimal(string: $1.meta?.effectiveAmount ?? "0")!
                    })
                let winningClaim = winningClaims[0]
                winningClaim.featured = true

                var canShow = true

                // check if the winning claim could be mature content
                if let tags = winningClaim.value?.tags {
                    canShow = !tags.contains(where: Constants.MatureTags.contains)
                }

                // check if the winning claim is filtered or blocked
                canShow = !Lbryio.isClaimFiltered(winningClaim) && canShow
                canShow = !Lbryio.isClaimBlocked(winningClaim) && canShow

                // only show the winning claim if it is not mature content or blocked
                if canShow {
                    // if the claim is already in the search results, remove it so we can promote to the top
                    filteredClaims.removeAll(where: { $0.claimId == winningClaim.claimId })
                    filteredClaims.insert(winningClaim, at: 0)
                    resultsListView.reloadData()
                    checkNoResults()
                    self.winningClaim = winningClaim
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
                filterClaims()
            }

            // try to resolve the winning claim after loading initial set of results
            if let query = currentQuery {
                resolveWinning(query: query)
            }
        }
        checkNoResults()
        searching = false
        loadingContainer.isHidden = true
        filterButton.isEnabled = true
    }

    func filterClaims() {
        filteredClaims = OrderedSet(claims.filter(shouldShowClaim))

        // Add winning claim to top
        if let winningClaim = winningClaim {
            filteredClaims.removeAll(where: { $0.claimId == winningClaim.claimId })
            filteredClaims.insert(winningClaim, at: 0)
        }

        resultsListView.reloadData()
        checkNoResults()
    }

    func shouldShowClaim(claim: Claim) -> Bool {
        // Claim Type
        let filterType = filterClaimTypes[typePickerView.selectedRow(inComponent: 0)]
        let filterByFile = filterType == filterClaimTypes[1]
        let filterByChannel = filterType == filterClaimTypes[2]

        if claim.valueType == .channel && (!filterByChannel && filterByFile) {
            return false
        }
        if claim.valueType == .collection && (filterByChannel || filterByFile) {
            return false
        }
        if claim.valueType == .stream,
           let mediaType = claim.value?.source?.mediaType,
           (filterByChannel && !filterByFile) ||
           (mediaType.starts(with: MediaType.video.rawValue) && !showVideo) ||
           (mediaType.starts(with: MediaType.audio.rawValue) && !showAudio) ||
           (mediaType.starts(with: MediaType.image.rawValue) && !showImage) ||
           (mediaType.starts(with: MediaType.text.rawValue) && !showText)
        {
            return false
        }

        // Publish Time
        let contentFromTime = Int64(Helper.buildReleaseTime(
            contentFrom: Helper.contentFromItemNames[publishTimePicker.selectedRow(inComponent: 0)]
        )?.dropFirst() ?? "0") ?? 0
        var claimReleaseTime = Int64(claim.value?.releaseTime ?? "0") ?? 0
        if claimReleaseTime == 0 {
            claimReleaseTime = claim.timestamp ?? 0
        }

        return claimReleaseTime > contentFromTime
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
        noResultsView.isHidden = !filteredClaims.isEmpty
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

    @IBAction func filterButtonTapped(_ sender: Any) {
        UIView.animate(withDuration: 0.3) {
            self.filterOptionsView.isHidden.toggle()
        }
    }

    @IBAction func videoSwitchChanged(_ sender: UISwitch) {
        showVideo = sender.isOn
        filterClaims()
    }

    @IBAction func audioSwitchedChanged(_ sender: UISwitch) {
        showAudio = sender.isOn
        filterClaims()
    }

    @IBAction func imageSwitchChanged(_ sender: UISwitch) {
        showImage = sender.isOn
        filterClaims()
    }

    @IBAction func textSwitchChanged(_ sender: UISwitch) {
        showText = sender.isOn
        filterClaims()
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == typePickerView {
            UIView.animate(withDuration: 0.3) {
                self.fileTypesView.isHidden = pickerView.selectedRow(inComponent: 0) != 1 /* File */
            }
        }
        filterClaims()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredClaims.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell

        let claim: Claim = filteredClaims[indexPath.row]
        cell.setClaim(claim: claim)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = filteredClaims[indexPath.row]

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

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == typePickerView {
            return filterClaimTypes.count
        } else {
            return Helper.contentFromItemNames.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == typePickerView {
            return filterClaimTypes[row]
        } else {
            return Helper.contentFromItemNames[row]
        }
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        prefetchController.prefetch(at: indexPaths)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        prefetchController.cancelPrefetching(at: indexPaths)
    }
}
