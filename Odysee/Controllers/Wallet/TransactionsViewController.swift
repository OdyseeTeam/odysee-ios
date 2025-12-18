//
//  TransactionsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 05/12/2020.
//

import FirebaseAnalytics
import OrderedCollections
import UIKit

class TransactionsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
    UIGestureRecognizerDelegate
{
    @IBOutlet var transactionListView: UITableView!
    @IBOutlet var noTransactionsView: UIView!
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var backView: UIView!

    var transactions: OrderedSet<Transaction> = []
    var loadingTransactions: Bool = false
    var lastPageReached: Bool = false
    var currentPage = 1
    let pageSize = 25

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(bottom: Helper.miniPlayerBottomWithoutTabBar())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: "Transactions",
                AnalyticsParameterScreenClass: "TransactionsViewController",
            ]
        )

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        transactionListView.tableFooterView = UIView()
        loadTransactions()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func loadTransactions() {
        if loadingTransactions {
            return
        }

        loadingTransactions = true
        loadingContainer.isHidden = false
        noTransactionsView.isHidden = true
        transactionListView.isHidden = currentPage == 1

        Lbry.apiCall(
            method: LbryMethods.transactionList,
            params: .init(
                page: currentPage,
                pageSize: pageSize
            )
        )
        .subscribeResult(didLoadTransactions)
    }

    func didLoadTransactions(_ result: Result<Page<Transaction>, Error>) {
        loadingTransactions = false
        loadingContainer.isHidden = true
        defer {
            noTransactionsView.isHidden = !transactions.isEmpty
            transactionListView.isHidden = transactions.isEmpty
            transactionListView.reloadData()
        }
        guard case let .success(page) = result else {
            return
        }
        lastPageReached = page.isLastPage
        transactions.append(contentsOf: page.items)
        transactions.sort { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tx_cell", for: indexPath) as! TransactionTableViewCell

        let transaction: Transaction = transactions[indexPath.row]
        cell.setTransaction(transaction: transaction)

        return cell
    }

    @IBAction func backTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if transactionListView.contentOffset
            .y >= (transactionListView.contentSize.height - transactionListView.bounds.size.height)
        {
            if !loadingTransactions, !lastPageReached {
                currentPage += 1
                loadTransactions()
            }
        }
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
