//
//  TransactionsViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 05/12/2020.
//

import UIKit

class TransactionsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var transactionListView: UITableView!
    @IBOutlet weak var noTransactionsView: UIView!
    @IBOutlet weak var loadingContainer: UIView!
    @IBOutlet weak var backView: UIView!
    
    var transactions: [Transaction] = []
    var loadingTransactions: Bool = false
    var lastPageReached: Bool = false
    var currentPage = 1
    let pageSize = 25
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: 2)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self

        // Do any additional setup after loading the view.
        loadingContainer.layer.cornerRadius = 20
        transactionListView.tableFooterView = UIView()
        loadTransactions()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func loadTransactions() {
        if (loadingTransactions) {
            return
        }
        
        var params = Dictionary<String, Any>()
        params["page"] = currentPage
        params["page_size"] = pageSize
        
        loadingTransactions = true
        loadingContainer.isHidden = false
        noTransactionsView.isHidden = true
        transactionListView.isHidden = currentPage == 1
        
        Lbry.apiCall(method: Lbry.methodTransactionList, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.checkTransactionsLoaded()
                return
            }
            
            let result = data["result"] as! [String: Any]
            let items = result["items"] as? [[String: Any]]
            if (items != nil) {
                if items!.count < self.pageSize {
                    self.lastPageReached = true
                }
                items?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let transaction: Transaction? = try JSONDecoder().decode(Transaction.self, from: data)
                        if (transaction != nil && !self.transactions.contains(where: { $0.txid == transaction?.txid })) {
                            self.transactions.append(transaction!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
                self.transactions.sort(by: { ($0.timestamp ?? 0) > ($1.timestamp ?? 0) })
            }
            
            self.checkTransactionsLoaded()
        })
    }
    
    func checkTransactionsLoaded() {
        DispatchQueue.main.async {
            self.loadingTransactions = false
            self.loadingContainer.isHidden = true
            self.noTransactionsView.isHidden = self.transactions.count > 0
            self.transactionListView.isHidden = self.transactions.count == 0
            self.transactionListView.reloadData()
        }
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
        self.navigationController?.popViewController(animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (transactionListView.contentOffset.y >= (transactionListView.contentSize.height - transactionListView.bounds.size.height)) {
            if (!loadingTransactions && !lastPageReached) {
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
