//
//  MainViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 02/11/2020.
//

import Firebase
import UIKit

class HomeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var claimListView: UITableView!
    @IBOutlet weak var categoryButtonsContainer: UIStackView!
    @IBOutlet weak var noContentView: UIStackView!
    
    @IBOutlet weak var sortByLabel: UILabel!
    @IBOutlet weak var contentFromLabel: UILabel!
    
    let refreshControl = UIRefreshControl()
    let categories: [String] = ["Cheese", "Big Hits", "Gaming", "Lab", "Tech", "News", "Finance 2.0", "The Universe", "Wild West"]
    let channelIds: [[String]?] = [
        ContentSources.PrimaryChannelContentIds,
        ContentSources.BigHitsChannelIds,
        ContentSources.GamingChannelIds,
        ContentSources.ScienceChannelIds,
        ContentSources.TechnologyChannelIds,
        ContentSources.NewsChannelIds,
        ContentSources.FinanceChannelIds,
        ContentSources.TheUniverseChannelIds,
        ContentSources.PrimaryChannelContentIds
    ]
    let wildWestCategoryIndex: Int = 8
    var currentCategoryIndex: Int = 0
    var categoryButtons: [UIButton] = []
    var options = Dictionary<String, Any>()
    
    let pageSize: Int = 20
    var currentPage: Int = 1
    var lastPageReached: Bool = false
    var loading: Bool = false
    var claims: [Claim] = []
    
    var sortByPicker: UIPickerView!
    var contentFromPicker: UIPickerView!
    
    var currentSortByIndex = 0 // default to Trending content
    var currentContentFromIndex = 1 // default to Past week
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Home", AnalyticsParameterScreenClass: "HomeViewController"])
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        let bottom = (appDelegate.mainTabViewController?.tabBar.frame.size.height)! + 2
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: bottom)
    }
    
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
        let isWildWest = currentCategoryIndex == wildWestCategoryIndex
        let orderByValue = Helper.sortByItemValues[currentSortByIndex]
        let releaseTimeValue = currentSortByIndex == 2 ? Helper.buildReleaseTime(contentFrom: Helper.contentFromItemNames[currentContentFromIndex]) : Helper.releaseTime6Months()
        
        options = Lbry.buildClaimSearchOptions(claimType: ["stream"], anyTags: nil, notTags: nil, channelIds: channelIds[currentCategoryIndex], notChannelIds: nil, claimIds: nil, orderBy: isWildWest ? ["trending_group", "trending_mixed"] : orderByValue, releaseTime: isWildWest ? Helper.buildReleaseTime(contentFrom: Helper.contentFromItemNames[1]) : releaseTimeValue, maxDuration: nil, limitClaimsPerChannel: 5, page: currentPage, pageSize: pageSize)
    }
    
    func loadClaims() {
        if (loading) {
            return
        }
        
        DispatchQueue.main.async {
            self.noContentView.isHidden = true
            self.loadingContainer.isHidden = false
        }
        loading = true
        
        updateClaimSearchOptions()
        Lbry.apiCall(method: Lbry.methodClaimSearch, params: options, connectionString: Lbry.lbrytvConnectionString, completion: { data, error in
            guard let data = data, error == nil else {
                self.loadingContainer.isHidden = true
                self.loading = false
                self.checkNoContent()
                return
            }
            
            let result = data["result"] as? [String: Any]
            let items = result?["items"] as? [[String: Any]]
            if (items != nil) {
                if items!.count < self.pageSize {
                    self.lastPageReached = true
                }
                var loadedClaims: [Claim] = []
                items?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let claim: Claim? = try JSONDecoder().decode(Claim.self, from: data)
                        if (claim != nil && !self.claims.contains(where: { $0.claimId == claim?.claimId }) && !Lbryio.isClaimFiltered(claim!) && !Lbryio.isClaimBlocked(claim!)) {
                            loadedClaims.append(claim!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.claims.append(contentsOf: loadedClaims)
                if self.currentCategoryIndex != self.wildWestCategoryIndex {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "claim_cell", for: indexPath) as! ClaimTableViewCell
        
        let claim: Claim = claims[indexPath.row]
        cell.setClaim(claim: claim)
            
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let claim: Claim = claims[indexPath.row]
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
        vc.claim = claim
        
        appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
        appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (claimListView.contentOffset.y >= (claimListView.contentSize.height - claimListView.bounds.size.height)) {
            if (!loading && !lastPageReached) {
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
        button.setTitleColor(UIColor.label, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.addTarget(self, action: #selector(self.categoryButtonTapped), for: .touchUpInside)
        
        categoryButtons.append(button)
        categoryButtonsContainer.addArrangedSubview(button)
    }
    
    @objc func categoryButtonTapped(sender: UIButton) {
        for button in categoryButtons {
            if (button.backgroundColor == Helper.primaryColor) {
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
        DispatchQueue.main.async {
            self.currentPage = 1
            self.lastPageReached = false
            self.claims.removeAll()
            self.claimListView.reloadData()
        }
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
       let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Sort content by"), dataSource: self, delegate: self, parent: self, handler: { _ in
            let selectedIndex = self.sortByPicker.selectedRow(inComponent: 0)
            let prevIndex = self.currentSortByIndex
            self.currentSortByIndex = selectedIndex
            if (prevIndex != self.currentSortByIndex) {
                self.checkUpdatedSortBy()
                self.resetContent()
                self.loadClaims()
            }
        })
        
        sortByPicker = picker
        present(alert, animated: true, completion: {
            self.sortByPicker.selectRow(self.currentSortByIndex, inComponent: 0, animated: true)
        })
    }
    
    @IBAction func contentFromLabelTapped(_ sender: Any) {
        let (picker, alert) = Helper.buildPickerActionSheet(title: String.localized("Content from"), dataSource: self, delegate: self, parent: self, handler: { _ in
            let selectedIndex = self.contentFromPicker.selectedRow(inComponent: 0)
            let prevIndex = self.currentContentFromIndex
            self.currentContentFromIndex = selectedIndex
            if (prevIndex != self.currentContentFromIndex) {
                self.checkUpdatedContentFrom()
                self.resetContent()
                self.loadClaims()
            }
        })
        
        contentFromPicker = picker
        present(alert, animated: true, completion: {
            self.contentFromPicker.selectRow(self.currentContentFromIndex, inComponent: 0, animated: true)
        })
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (pickerView == sortByPicker) {
            return Helper.sortByItemNames.count
        } else {
            return Helper.contentFromItemNames.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if (pickerView == sortByPicker) {
            return Helper.sortByItemNames[row]
        } else {
            return Helper.contentFromItemNames[row]
        }
    }
    
    @objc func refresh(_ sender: AnyObject) {
        if (loading) {
            return
        }
        
        resetContent()
        loadClaims()
    }
}
