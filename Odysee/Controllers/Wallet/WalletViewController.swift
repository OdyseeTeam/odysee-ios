//
//  WalletViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import Base58Swift
import Firebase
import UIKit

class WalletViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, WalletBalanceObserver {
    let keyBalanceObserver = "wallet_vc"
    let keyReceiveAddress = "walletReceiveAddress"
    let currencyFormatter = NumberFormatter()
    
    var loadingRecentTransactions = false
    var recentTransactions: [Transaction] = []
    
    @IBOutlet weak var recentTxListHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var walletScrollView: UIScrollView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var usdBalanceLabel: UILabel!
    
    @IBOutlet weak var receiveAddressTextField: UITextField!
    //@IBOutlet weak var getNewAddressButton: UIButton!
    
    @IBOutlet weak var sendAddressTextField: UITextField!
    @IBOutlet weak var sendAmountTextField: UITextField!
    @IBOutlet weak var loadingSendView: UIActivityIndicatorView!
    @IBOutlet weak var sendButton: UIButton!
    
    @IBOutlet weak var recentTransactionsListView: UITableView!
    @IBOutlet weak var noRecentTransactionsLabel: UILabel!
    @IBOutlet weak var loadingRecentTransactionsView: UIActivityIndicatorView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.addWalletObserver(key: keyBalanceObserver, observer: self)
        self.view.isHidden = !Lbryio.isSignedIn()
        
        if (!Lbryio.isSignedIn()) {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "Wallet", AnalyticsParameterScreenClass: "WalletViewController"])
        
        if (Lbryio.isSignedIn()) {
            checkReceiveAddress()
            loadRecentTransactions()
            if Lbry.walletBalance != nil {
                balanceUpdated(balance: Lbry.walletBalance!)
            }
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.toggleHeaderVisibility(hidden: false)
        let bottom = (appDelegate.mainTabViewController?.tabBar.frame.size.height)! + 2
        appDelegate.mainController.adjustMiniPlayerBottom(bottom: bottom)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.removeWalletObserver(key: keyBalanceObserver)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        currencyFormatter.roundingMode = .down
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .decimal
        currencyFormatter.locale = Locale.current
        
        displayBalance(balance: Lbry.walletBalance)
        
        recentTransactionsListView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        registerForKeyboardNotifications()
    }
    
    func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        let kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        let contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: kbSize.height, right: 0.0)
        walletScrollView.contentInset = contentInsets
        walletScrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        walletScrollView.contentInset = contentInsets
        walletScrollView.scrollIndicatorInsets = contentInsets
    }
    
    func checkReceiveAddress() {
        let defaults = UserDefaults.standard
        let receiveAddress = defaults.string(forKey: keyReceiveAddress)
        if ((receiveAddress ?? "").isBlank) {
            getNewReceiveAddress()
            return
        }
        receiveAddressTextField.text = receiveAddress
    }
    
    /*@IBAction func getNewAddressTapped(_ sender: UIButton) {
        getNewReceiveAddress()
    }*/
    
    @IBAction func sendTapped(_ sender: UIButton) {
        sendAddressTextField.resignFirstResponder()
        sendAmountTextField.resignFirstResponder()
        
        let recipientAddress = sendAddressTextField.text
        let amount = Decimal(string: sendAmountTextField.text!)
        if (!Helper.isAddressValid(address: recipientAddress)) {
            showError(message: String.localized("Please enter a valid address to send to"))
            return
        }
        if amount == nil {
            showError(message: String.localized("Please enter valid amount"))
            return
        }

        let alert = UIAlertController(title: String.localized("Send credits?"), message: String.localized(String(format: "Are you sure you want to send credits to %@?", recipientAddress!)), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
            self.confirmSendCredits(recipientAddress: recipientAddress!, amount: Helper.sdkAmountFormatter.string(from: amount! as NSDecimalNumber)!)
        }))
        alert.addAction(UIAlertAction(title: String.localized("No"), style: .destructive))
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func viewAllTapped(_ sender: UIButton) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = storyboard?.instantiateViewController(identifier: "transactions_vc") as! TransactionsViewController
        appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
    }
    
    func confirmSendCredits(recipientAddress: String, amount: String) {
        var params = Dictionary<String, Any>()
        params["addresses"] = [recipientAddress]
        params["amount"] = amount
        params["blocking"] = true
        
        loadingSendView.isHidden = false
        sendButton.isEnabled = false
        Lbry.apiCall(method: Lbry.methodWalletSend, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let _ = data, error == nil else {
                self.showError(error: error)
                return
            }
            
            DispatchQueue.main.async {
                self.showMessage(message: String.localized("You sent credits!"))
                self.sendAddressTextField.text = ""
                self.sendAmountTextField.text = ""
                self.loadingSendView.isHidden = true
                self.sendButton.isEnabled = true
            }
        })
    }
        
    func getNewReceiveAddress() {
        //getNewAddressButton.isEnabled = false
        Lbry.apiCall(method: Lbry.methodAddressUnused, params: Dictionary<String, Any>(), connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                print(error!)
                return
            }
            
            let newAddress = data["result"] as! String
            DispatchQueue.main.async {
                let defaults = UserDefaults.standard
                defaults.setValue(newAddress, forKey: self.keyReceiveAddress)
                self.receiveAddressTextField.text = newAddress
                //self.getNewAddressButton.isEnabled = true
            }
        })
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if (textField == receiveAddressTextField) {
            sendAddressTextField.resignFirstResponder()
            sendAmountTextField.resignFirstResponder()
            
            UIPasteboard.general.string = receiveAddressTextField.text
            showMessage(message: String.localized("Address copied!"))
            return false
        }
        return true
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    // dismiss soft keyboard when anywhere in the view (outside of text fields) is tapped
    @IBAction func anywhereTapped(_ sender: Any) {
        sendAddressTextField.resignFirstResponder()
        sendAmountTextField.resignFirstResponder()
    }
    
    func balanceUpdated(balance: WalletBalance) {
        displayBalance(balance: balance)
    }
    
    func displayBalance(balance: WalletBalance?) {
        if (balance != nil) {
            balanceLabel.text = currencyFormatter.string(from: balance!.available! as NSDecimalNumber)
            
            if (Lbryio.currentLbcUsdRate ?? 0) == 0 {
                // attempt to reload the exchange rate (if it wasn't loaded previously)
                Lbryio.loadExchangeRate(completion: { rate, error in
                    guard let rate = rate, error == nil else {
                        // pass
                        return
                    }
                    DispatchQueue.main.async {
                        self.usdBalanceLabel.text = String(format: "≈$%@", self.currencyFormatter.string(from: (balance!.available! * rate) as NSDecimalNumber)!)
                    }
                })
            } else {
                usdBalanceLabel.text = String(format: "≈$%@", currencyFormatter.string(from: (balance!.available! * Lbryio.currentLbcUsdRate!) as NSDecimalNumber)!)
            }
        }
    }
    
    func loadRecentTransactions() {
        if (loadingRecentTransactions) {
            return
        }
        
        var params = Dictionary<String, Any>()
        params["page"] = 1
        params["page_size"] = 5
        
        recentTransactions.removeAll()
        recentTransactionsListView.reloadData()
        
        loadingRecentTransactions = true
        loadingRecentTransactionsView.isHidden = false
        noRecentTransactionsLabel.isHidden = true
        
        Lbry.apiCall(method: Lbry.methodTransactionList, params: params, connectionString: Lbry.lbrytvConnectionString, authToken: Lbryio.authToken, completion: { data, error in
            guard let data = data, error == nil else {
                self.showError(error: error)
                return
            }
            
            let result = data["result"] as! [String: Any]
            let items = result["items"] as? [[String: Any]]
            if (items != nil) {
                items?.forEach{ item in
                    let data = try! JSONSerialization.data(withJSONObject: item, options: [.prettyPrinted, .sortedKeys])
                    do {
                        let transaction: Transaction? = try JSONDecoder().decode(Transaction.self, from: data)
                        if (transaction != nil) {
                            self.recentTransactions.append(transaction!)
                        }
                    } catch let error {
                        print(error)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.loadingRecentTransactions = false
                self.loadingRecentTransactionsView.isHidden = true
                self.noRecentTransactionsLabel.isHidden = self.recentTransactions.count > 0
                self.recentTransactionsListView.reloadData()
            }
        })
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentTransactions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "recent_tx_cell", for: indexPath) as! TransactionTableViewCell
        
        let transaction: Transaction = recentTransactions[indexPath.row]
        cell.setTransaction(transaction: transaction)
            
        return cell
    }

    func showMessage(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showMessage(message: message)
    }
    func showError(message: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(message: message)
    }
    func showError(error: Error?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.mainController.showError(error: error)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentSize" {
            if (change?[.newKey]) != nil {
                let contentHeight: CGFloat = recentTransactionsListView.contentSize.height
                recentTxListHeightConstraint.constant = contentHeight
            }
        }
    }
}
