//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Firebase
import OrderedCollections
import PINRemoteImage
import UIKit

class HomeViewController: UIViewController,
    UITableViewDelegate,
    UITableViewDataSource,
    UIPickerViewDelegate,
    UIPickerViewDataSource,
    UITableViewDataSourcePrefetching
{
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var claimListView: UITableView!
    @IBOutlet var categoryButtonsContainer: UIStackView!
    @IBOutlet var noContentView: UIStackView!

    @IBOutlet var sortByLabel: UILabel!
    @IBOutlet var contentFromLabel: UILabel!

    static var categoryIndexMovies: Int = -1
    static var categoryIndexWildWest: Int = -1
    static let categoryNameGeneral: String = "general"
    static let categoryNameMovies: String = "movies"

    let refreshControl = UIRefreshControl()
    var categories: [String] = []
    var channelIds: [[String]?] = []
    var currentCategoryIndex: Int = 0
    var categoryButtons: [UIButton] = []

    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loading: Bool = false
    var claims = OrderedSet<Claim>()

    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!

    var currentSortByIndex = 0 // default to Trending content
    var currentContentFromIndex = 1 // default to Past week

    var prefetchController: ImagePrefetchingController!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [AnalyticsParameterScreenName: "Home", AnalyticsParameterScreenClass: "HomeViewController"]
        )

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
        let bottom = (AppDelegate.shared.mainTabViewController?.tabBar.frame.size.height)! + 2
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: bottom)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buildDynamicCategories()
        prefetchController = ImagePrefetchingController { [unowned self] indexPath in
            let claim = self.claims[indexPath.row]
            return ClaimTableViewCell.imagePrefetchURLs(claim: claim)
        }
        // Do any additional setup after loading the view.
        refreshControl.attributedTitle = NSAttributedString(string: String.localized("Pull down to refresh"))
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        refreshControl.tintColor = Helper.primaryColor
        claimListView.addSubview(refreshControl)
        claimListView.register(ClaimTableViewCell.nib, forCellReuseIdentifier: "claim_cell")

        loadingContainer.layer.cornerRadius = 20

        categories.forEach { category in
            self.addCategoryButton(label: category)
        }
        selectCategoryButton(button: categoryButtons[0])

        if claims.count == 0 {
            loadClaims()
        }
    }

    func buildDynamicCategories() {
        for (idx, category) in ContentSources.DynamicContentCategories.enumerated() {
            categories.append(String.localized(category.label!))
            channelIds.append(category.channelIds)
            if category.name == Self.categoryNameMovies {
                Self.categoryIndexMovies = idx
            }
        }

        categories.append(String.localized("Wild West"))
        channelIds.append([])
        Self.categoryIndexWildWest = categories.count - 1
    }

    func didLoadClaims(_ result: Result<Page<Claim>, Error>) {
        assert(Thread.isMainThread)
        result.showErrorIfPresent()
        if case let .success(payload) = result {
            let oldCount = claims.count
            claims.append(contentsOf: payload.items)
            if claims.count != oldCount {
                claimListView.reloadData()
            }
            lastPageReached = payload.isLastPage
        }
        loadingContainer.isHidden = true
        loading = false
        checkNoContent()
        refreshControl.endRefreshing()
    }

    func loadClaims() {
        assert(Thread.isMainThread)
        if loading {
            return
        }

        noContentView.isHidden = true
        loadingContainer.isHidden = false
        loading = true

        // Capture category index for use in sorting, before leaving main thread.
        let category = currentCategoryIndex
        let isWildWest = category == Self.categoryIndexWildWest
        let releaseTimeValue = currentSortByIndex == 2 ? Helper
            .buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : Helper
            .releaseTime6Months()

        Lbry.apiCall(
            method: Lbry.Methods.claimSearch,
            params: .init(
                claimType: [.stream],
                page: currentPage,
                pageSize: pageSize,
                releaseTime: isWildWest ?
                    Helper.buildReleaseTime(contentFrom: Helper.contentFromItemNames[1]) :
                    releaseTimeValue,
                limitClaimsPerChannel:
                currentCategoryIndex == Self.categoryIndexMovies ? 20 : 5,
                channelIds: isWildWest ? nil : channelIds[currentCategoryIndex],
                orderBy: isWildWest ?
                    ["trending_group", "trending_mixed"]
                    : Helper.sortByItemValues[currentSortByIndex]
            ),
            transform: { page in
                if !isWildWest {
                    page.items
                        .sort {
                            $0.value!.releaseTime.flatMap(Int64.init) ?? 0 > $1.value!.releaseTime
                                .flatMap(Int64.init) ?? 0
                        }
                }
            }
        )
        .subscribeResult(didLoadClaims)
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

        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = claim

        AppDelegate.shared.mainNavigationController?.view.layer.add(
            Helper.buildFileViewTransition(),
            forKey: kCATransition
        )
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if claimListView.contentOffset.y >= (claimListView.contentSize.height - claimListView.bounds.size.height) {
            if !loading, !lastPageReached {
                currentPage += 1
                loadClaims()
            }
            return
        }

        guard !refreshControl.isRefreshing, !loading else {
            return
        }

        if claimListView.contentOffset.y < -300 {
            resetContent()
            loadClaims()
            refreshControl.beginRefreshing()
        }
    }

    func addCategoryButton(label: String) {
        let button = UIButton(type: .system)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 20, bottom: 4, right: 20)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = Helper.primaryColor.cgColor
        button.setTitle(label, for: .normal)
        button.setTitleColor(UIColor.label, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.addTarget(self, action: #selector(categoryButtonTapped), for: .touchUpInside)

        categoryButtons.append(button)
        categoryButtonsContainer.addArrangedSubview(button)
    }

    @objc func categoryButtonTapped(sender: UIButton) {
        for button in categoryButtons {
            if button.backgroundColor == Helper.primaryColor {
                button.backgroundColor = UIButton(type: .roundedRect).backgroundColor
                button.setTitleColor(UIColor.label, for: .normal)
                break
            }
        }
        selectCategoryButton(button: sender)

        let category = sender.title(for: .normal)

        currentCategoryIndex = categories.firstIndex(of: category!)!
        resetContent()
        loadClaims()
    }

    func resetContent() {
        assert(Thread.isMainThread)
        currentPage = 1
        lastPageReached = false
        claims.removeAll()
        claimListView.reloadData()
    }

    func selectCategoryButton(button: UIButton) {
        button.backgroundColor = Helper.primaryColor
        button.setTitleColor(UIColor.white, for: .normal)
    }

    func checkNoContent() {
        assert(Thread.isMainThread)
        noContentView.isHidden = !claims.isEmpty
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func checkUpdatedSortBy() {
        let itemName = Helper.sortByItemNames[currentSortByIndex]
        sortByLabel.text = String(format: "%@ ▾", String(itemName.prefix(upTo: itemName.firstIndex(of: " ")!)))
        contentFromLabel.isHidden = currentSortByIndex != 2
    }

    func checkUpdatedContentFrom() {
        contentFromLabel.text = String(format: "%@ ▾", String(Helper.contentFromItemNames[currentContentFromIndex]))
    }

    @IBAction func sortByLabelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(
            title: String.localized("Sort content by"),
            dataSource: self,
            delegate: self,
            parent: self,
            handler: { _ in
                let selectedIndex = self.sortByPicker.selectedRow(inComponent: 0)
                let prevIndex = self.currentSortByIndex
                self.currentSortByIndex = selectedIndex
                if prevIndex != self.currentSortByIndex {
                    self.checkUpdatedSortBy()
                    self.resetContent()
                    self.loadClaims()
                }
            }
        )

        sortByPicker = picker
        present(alert, animated: true, completion: {
            self.sortByPicker.selectRow(self.currentSortByIndex, inComponent: 0, animated: true)
        })
    }

    @IBAction func contentFromLabelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(
            title: String.localized("Content from"),
            dataSource: self,
            delegate: self,
            parent: self,
            handler: { _ in
                let selectedIndex = self.contentFromPicker.selectedRow(inComponent: 0)
                let prevIndex = self.currentContentFromIndex
                self.currentContentFromIndex = selectedIndex
                if prevIndex != self.currentContentFromIndex {
                    self.checkUpdatedContentFrom()
                    self.resetContent()
                    self.loadClaims()
                }
            }
        )

        contentFromPicker = picker
        present(alert, animated: true, completion: {
            self.contentFromPicker.selectRow(self.currentContentFromIndex, inComponent: 0, animated: true)
        })
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == sortByPicker {
            return Helper.sortByItemNames.count
        } else {
            return Helper.contentFromItemNames.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == sortByPicker {
            return Helper.sortByItemNames[row]
        } else {
            return Helper.contentFromItemNames[row]
        }
    }

    @objc func refresh(_ sender: AnyObject) {
        if loading {
            return
        }

        resetContent()
        loadClaims()
    }

    // MARK: UITableViewDataSourcePrefetching

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        prefetchController.prefetch(at: indexPaths)
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        prefetchController.cancelPrefetching(at: indexPaths)
    }
}
