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
    @IBOutlet var typePicker: UIPickerView!
    @IBOutlet var publishTimePicker: UIPickerView!
    @IBOutlet var sortByPicker: UIPickerView!
    @IBOutlet var fileTypesView: UIStackView!

    @IBOutlet var filterOptionsView: UIStackView!
    @IBOutlet var resultsListView: UITableView!
    @IBOutlet var loadingContainer: UIView!

    let refreshControl = UIRefreshControl()

    var searchTask: DispatchWorkItem?
    var currentFrom = 0
    var currentQuery: String?
    var currentClaimType: ClaimType?
    var currentMediaTypes: [Lighthouse.MediaType] = [.video, .audio, .image, .text]
    var currentTimeFilter: Lighthouse.TimeFilter?
    var currentSortBy: Lighthouse.SortBy?
    var searching: Bool = false
    var lighthouseUrls = [String]()
    let pageSize = 20
    var claims = OrderedSet<Claim>()
    var winningClaim: Claim?
    var prefetchController: ImagePrefetchingController!

    var showVideo = true
    var showAudio = true
    var showImage = true
    var showText = true

    let filterClaimTypes = ["Any", "File", "Channel"]
    let sortByOptions = ["Relevance", "Newest first", "Oldest First"]

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

        refreshControl.attributedTitle = NSAttributedString(string: String.localized("Pull down to refresh"))
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        refreshControl.tintColor = Helper.primaryColor
        resultsListView.addSubview(refreshControl)
        resultsListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")

        publishTimePicker.selectRow(4 /* All Time */, inComponent: 0, animated: false)
    }

    func resolveWinning(query: String) {
        if Lighthouse.containsFilteredKeyword(query) {
            return
        }

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
                    canShow = !tags.contains(where: Constants.NotTags.contains)
                }

                // check if the winning claim is filtered or blocked
                canShow = !Lbryio.isClaimFiltered(winningClaim) && !Lbryio.isClaimAppleFiltered(winningClaim) && canShow
                canShow = !Lbryio.isClaimBlocked(winningClaim) && canShow

                // only show the winning claim if it is not mature content or blocked
                if canShow {
                    // if the claim is already in the search results, remove it so we can promote to the top
                    claims.removeAll(where: { $0.claimId == winningClaim.claimId })
                    claims.insert(winningClaim, at: 0)
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

    func search(
        query: String?,
        from: Int,
        claimType: ClaimType?,
        mediaTypes: [Lighthouse.MediaType],
        timeFilter: Lighthouse.TimeFilter?,
        sortBy: Lighthouse.SortBy?,
        force: Bool = false
    ) {
        if query.isBlank ||
            (
                currentQuery == query &&
                    currentFrom == from &&
                    currentClaimType == claimType &&
                    currentMediaTypes == mediaTypes &&
                    currentTimeFilter == timeFilter &&
                    currentSortBy == sortBy &&
                    !force
            )
        {
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
        currentClaimType = claimType
        currentMediaTypes = mediaTypes
        currentTimeFilter = timeFilter
        currentSortBy = sortBy
        Lighthouse.search(
            rawQuery: query!,
            size: pageSize,
            from: currentFrom,
            relatedTo: nil,
            claimType: claimType,
            mediaTypes: mediaTypes,
            timeFilter: timeFilter,
            sortBy: sortBy,
            completion: { results, _ in
                guard let results = results, !results.isEmpty else {
                    DispatchQueue.main.async {
                        self.searching = false
                        self.claims = []
                        self.resolveWinning(query: query!)
                        self.checkNoResults()
                    }
                    return
                }

                self.lighthouseUrls = results.compactMap { item in
                    LbryUri.tryParse(
                        url: String(format: "%@#%@", item["name"] as! String, item["claimId"] as! String),
                        requireProto: false
                    )?.description
                }
                Lbry.apiCall(
                    method: Lbry.Methods.resolve,
                    params: .init(urls: self.lighthouseUrls)
                )
                .subscribeResult(self.didResolveResults)
            }
        )
    }

    func didResolveResults(_ result: Result<ResolveResult, Error>) {
        result.showErrorIfPresent()
        if case let .success(resolve) = result {
            let urls = resolve.claims.values.sorted(
                like: self.lighthouseUrls,
                keyPath: \.permanentUrl!,
                transform: LbryUri.normalize
            )

            let oldCount = claims.count
            claims.append(contentsOf: urls)
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
        filterButton.isEnabled = true
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
        resultsListView.isHidden = claims.isEmpty
        noResultsView.isHidden = !claims.isEmpty
        noResultsLabel.text = Lighthouse.containsFilteredKeyword(currentQuery!) ?
            String
            .localized(
                "This search term is restricted for iOS users of Odysee. Consider using odysee.com for the Complete Odysee Experience. Alternatively, you can visit odysee.com from the browser of your iOS device and save the website to your homescreen. This will provide you with a similar app-like experience."
            ) :
            String
            .localized(
                "Oops! We could not find any content matching your search term. Please try again with something different."
            )
        refreshControl.endRefreshing()
    }

    func claimType(for index: Int) -> ClaimType? {
        let filterType = filterClaimTypes[index]
        switch filterType {
        case "File": return .stream
        case "Channel": return .channel
        case "Any": return nil
        default: return nil
        }
    }

    func mediaTypesFromFilter() -> [Lighthouse.MediaType] {
        let videoType = showVideo ? Lighthouse.MediaType.video : nil
        let audioType = showAudio ? Lighthouse.MediaType.audio : nil
        let imageType = showImage ? Lighthouse.MediaType.image : nil
        let textType = showText ? Lighthouse.MediaType.text : nil
        return [videoType, audioType, imageType, textType].compactMap { $0 }
    }

    func timeFilter(for index: Int) -> Lighthouse.TimeFilter? {
        let timeFilter = Helper.contentFromItemNames[index]
        switch timeFilter {
        case "Past 24 hours": return .today
        case "Past week": return .thisweek
        case "Past month": return .thismonth
        case "Past year": return .thisyear
        case "All time": return nil
        default: return nil
        }
    }

    func sortBy(for index: Int) -> Lighthouse.SortBy? {
        let sortBy = sortByOptions[index]
        switch sortBy {
        case "Oldest First": return .ascending
        case "Newest first": return .descending
        case "Relevance": return nil
        default: return nil
        }
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
        resetSearch()
        search(
            query: currentQuery,
            from: currentFrom,
            claimType: currentClaimType,
            mediaTypes: mediaTypesFromFilter(),
            timeFilter: currentTimeFilter,
            sortBy: currentSortBy
        )
    }

    @IBAction func audioSwitchedChanged(_ sender: UISwitch) {
        showAudio = sender.isOn
        resetSearch()
        search(
            query: currentQuery,
            from: currentFrom,
            claimType: currentClaimType,
            mediaTypes: mediaTypesFromFilter(),
            timeFilter: currentTimeFilter,
            sortBy: currentSortBy
        )
    }

    @IBAction func imageSwitchChanged(_ sender: UISwitch) {
        showImage = sender.isOn
        resetSearch()
        search(
            query: currentQuery,
            from: currentFrom,
            claimType: currentClaimType,
            mediaTypes: mediaTypesFromFilter(),
            timeFilter: currentTimeFilter,
            sortBy: currentSortBy
        )
    }

    @IBAction func textSwitchChanged(_ sender: UISwitch) {
        showText = sender.isOn
        resetSearch()
        search(
            query: currentQuery,
            from: currentFrom,
            claimType: currentClaimType,
            mediaTypes: mediaTypesFromFilter(),
            timeFilter: currentTimeFilter,
            sortBy: currentSortBy
        )
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == typePicker {
            UIView.animate(withDuration: 0.3) {
                self.fileTypesView.isHidden = pickerView.selectedRow(inComponent: 0) != 1 /* File */
            }
            resetSearch()
            search(
                query: currentQuery,
                from: currentFrom,
                claimType: claimType(for: pickerView.selectedRow(inComponent: 0)),
                mediaTypes: currentMediaTypes,
                timeFilter: currentTimeFilter,
                sortBy: currentSortBy
            )
        } else if pickerView == sortByPicker {
            resetSearch()
            search(
                query: currentQuery,
                from: currentFrom,
                claimType: currentClaimType,
                mediaTypes: currentMediaTypes,
                timeFilter: currentTimeFilter,
                sortBy: sortBy(for: pickerView.selectedRow(inComponent: 0))
            )
        } else {
            resetSearch()
            search(
                query: currentQuery,
                from: currentFrom,
                claimType: currentClaimType,
                mediaTypes: currentMediaTypes,
                timeFilter: timeFilter(for: pickerView.selectedRow(inComponent: 0)),
                sortBy: currentSortBy
            )
        }
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
        if searching {
            return
        }

        if (resultsListView.contentSize.height - resultsListView.bounds.size.height) >= 0 &&
            resultsListView.contentOffset.y >=
            (resultsListView.contentSize.height - resultsListView.bounds.size.height)
        {
            search(
                query: currentQuery,
                from: currentFrom + pageSize,
                claimType: currentClaimType,
                mediaTypes: currentMediaTypes,
                timeFilter: currentTimeFilter,
                sortBy: currentSortBy
            )
        }

        if !refreshControl.isRefreshing && resultsListView.contentOffset.y < -300 {
            resetSearch()
            search(
                query: searchBar.searchTextField.text,
                from: 0,
                claimType: currentClaimType,
                mediaTypes: currentMediaTypes,
                timeFilter: currentTimeFilter,
                sortBy: currentSortBy,
                force: true
            )
            refreshControl.beginRefreshing()
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
        search(
            query: searchBar.searchTextField.text,
            from: 0,
            claimType: currentClaimType,
            mediaTypes: currentMediaTypes,
            timeFilter: currentTimeFilter,
            sortBy: currentSortBy,
            force: true
        )
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == typePicker {
            return filterClaimTypes.count
        } else if pickerView == sortByPicker {
            return sortByOptions.count
        } else {
            return Helper.contentFromItemNames.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == typePicker {
            return filterClaimTypes[row]
        } else if pickerView == sortByPicker {
            return sortByOptions[row]
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

    @objc func refresh(_ sender: Any) {
        if searching {
            return
        }

        resetSearch()
        search(
            query: searchBar.searchTextField.text,
            from: 0,
            claimType: currentClaimType,
            mediaTypes: currentMediaTypes,
            timeFilter: currentTimeFilter,
            sortBy: currentSortBy,
            force: true
        )
    }
}
