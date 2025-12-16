//
//  WalletViewController.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 01/12/2020.
//

import Base58Swift
import FirebaseAnalytics
import UIKit

class WalletViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate,
    WalletBalanceObserver
{
    let keyBalanceObserver = "wallet_vc"

    var loadingRecentTransactions = false
    var recentTransactions: [Transaction] = []

    @IBOutlet var recentTxListHeightConstraint: NSLayoutConstraint!
    @IBOutlet var balanceLabel: UILabel!
    @IBOutlet var usdBalanceLabel: UILabel!

    @IBOutlet var immediatelySpendableLabel: UILabel!
    @IBOutlet var boostingContentLabel: UILabel!
    @IBOutlet var tipsLabel: UILabel!
    @IBOutlet var initialPublishesLabel: UILabel!
    @IBOutlet var supportingContentLabel: UILabel!
    @IBOutlet var boostingMoreLabel: UILabel!
    @IBOutlet var boostingContentBreakdownView: UIView!

    @IBOutlet var receiveAddressTextField: UITextField!
    // @IBOutlet weak var getNewAddressButton: UIButton!

    @IBOutlet var sendAddressTextField: UITextField!
    @IBOutlet var sendAmountTextField: UITextField!
    @IBOutlet var loadingSendView: UIActivityIndicatorView!
    @IBOutlet var sendButton: UIButton!

    @IBOutlet var recentTransactionsListView: UITableView!
    @IBOutlet var noRecentTransactionsLabel: UILabel!
    @IBOutlet var loadingRecentTransactionsView: UIActivityIndicatorView!

    var boostingBreakdownVisible = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.shared.mainController.addWalletObserver(key: keyBalanceObserver, observer: self)
        view.isHidden = !Lbryio.isSignedIn()

        if !Lbryio.isSignedIn() {
            // show the sign in view
            let vc = storyboard?.instantiateViewController(identifier: "ua_vc") as! UserAccountViewController
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [AnalyticsParameterScreenName: "Wallet", AnalyticsParameterScreenClass: "WalletViewController"]
        )

        if Lbryio.isSignedIn() {
            checkReceiveAddress()
            loadRecentTransactions()
            if let balance = Lbry.walletBalance {
                balanceUpdated(balance: balance)
            }
        }

        AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
        AppDelegate.shared.mainController.adjustMiniPlayerBottom(
            bottom: Helper.miniPlayerBottomWithTabBar(appDelegate: AppDelegate.shared))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.shared.mainController.removeWalletObserver(key: keyBalanceObserver)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        displayBalance(balance: Lbry.walletBalance)

        recentTransactionsListView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }

    func checkReceiveAddress() {
        let defaults = UserDefaults.standard
        let receiveAddress = defaults.string(forKey: Helper.keyReceiveAddress)
        if receiveAddress.isEmpty {
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

        guard let recipientAddress = sendAddressTextField.text,
              Helper.isAddressValid(address: recipientAddress)
        else {
            showError(message: String.localized("Please enter a valid address to send to"))
            return
        }
        guard let amountValue = sendAmountTextField.text,
              let amount = Decimal(string: amountValue)
        else {
            showError(message: String.localized("Please enter valid amount"))
            return
        }
        if amount > Lbry.walletBalance?.available ?? 0 {
            showError(message: String.localized("Insufficient funds"))
            return
        }

        let alert = UIAlertController(
            title: String.localized("Send credits?"),
            message: String
                .localized(String(format: "Are you sure you want to send credits to %@?", recipientAddress)),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String.localized("Yes"), style: .default, handler: { _ in
            self.confirmSendCredits(
                recipientAddress: recipientAddress,
                amount: Helper.sdkAmountFormatter.string(from: amount as NSDecimalNumber) ?? ""
            )
        }))
        alert.addAction(UIAlertAction(title: String.localized("No"), style: .destructive))

        present(alert, animated: true, completion: nil)
    }

    @IBAction func viewAllTapped(_ sender: UIButton) {
        let vc = storyboard?.instantiateViewController(identifier: "transactions_vc") as! TransactionsViewController
        AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func boostingMoreTapped(_ sender: Any) {
        boostingBreakdownVisible = !boostingBreakdownVisible
        boostingContentBreakdownView.isHidden = !boostingBreakdownVisible
        boostingMoreLabel.text = boostingBreakdownVisible ? "less" : "more"
    }

    func confirmSendCredits(recipientAddress: String, amount: String) {
        var params = [String: Any]()
        params["addresses"] = [recipientAddress]
        params["amount"] = amount
        params["blocking"] = true

        loadingSendView.isHidden = false
        sendButton.isEnabled = false
        Lbry.apiCall(
            method: Lbry.methodWalletSend,
            params: params,
            url: Lbry.lbrytvURL,
            authToken: Lbryio.authToken,
            completion: { data, error in
                guard data != nil, error == nil else {
                    self.showError(error: error)
                    DispatchQueue.main.async {
                        self.loadingSendView.isHidden = true
                        self.sendButton.isEnabled = true
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.showMessage(message: String.localized("You sent credits!"))
                    self.sendAddressTextField.text = ""
                    self.sendAmountTextField.text = ""
                    self.loadingSendView.isHidden = true
                    self.sendButton.isEnabled = true
                }
            }
        )
    }

    func getNewReceiveAddress() {
        // getNewAddressButton.isEnabled = false
        Lbry.apiCall(method: Lbry.Methods.addressUnused, params: .init()).subscribeResult { result in
            guard case let .success(address) = result else {
                result.showErrorIfPresent()
                return
            }
            UserDefaults.standard.set(address, forKey: Helper.keyReceiveAddress)
            self.receiveAddressTextField.text = address
            // self.getNewAddressButton.isEnabled = true
        }
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == receiveAddressTextField {
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
        let currencyFormatter = Helper.currencyFormatter
        if let balance = balance {
            balanceLabel.text = currencyFormatter.string(from: NSDecimalNumber(decimal: balance.total ?? Decimal(0)))
            immediatelySpendableLabel.text = currencyFormatter
                .string(from: NSDecimalNumber(decimal: balance.available ?? Decimal(0)))
            boostingContentLabel.text = currencyFormatter
                .string(from: NSDecimalNumber(decimal: balance.reserved ?? Decimal(0)))
            tipsLabel.text = currencyFormatter.string(from: NSDecimalNumber(decimal: balance.tips ?? Decimal(0)))
            initialPublishesLabel.text = currencyFormatter
                .string(from: NSDecimalNumber(decimal: balance.claims ?? Decimal(0)))
            supportingContentLabel.text = currencyFormatter
                .string(from: NSDecimalNumber(decimal: balance.supports ?? Decimal(0)))

            if let total = balance.total {
                if let rate = Lbryio.currentLbcUsdRate {
                    usdBalanceLabel.text = String(
                        format: "≈$%@",
                        currencyFormatter.string(from: (total * rate) as NSDecimalNumber) ?? ""
                    )
                } else {
                    // attempt to reload the exchange rate (if it wasn't loaded previously)
                    Lbryio.loadExchangeRate(completion: { rate, error in
                        guard let rate = rate, error == nil else {
                            self.showError(error: error)
                            return
                        }
                        DispatchQueue.main.async {
                            self.usdBalanceLabel.text = String(
                                format: "≈$%@",
                                currencyFormatter.string(from: (total * rate) as NSDecimalNumber) ?? ""
                            )
                        }
                    })
                }
            }
        }
    }

    func loadRecentTransactions() {
        if loadingRecentTransactions {
            return
        }

        recentTransactions.removeAll()
        recentTransactionsListView.reloadData()

        loadingRecentTransactions = true
        loadingRecentTransactionsView.isHidden = false
        noRecentTransactionsLabel.isHidden = true

        Lbry.apiCall(
            method: Lbry.Methods.transactionList,
            params: .init(
                page: 1,
                pageSize: 5
            )
        )
        .subscribeResult(didLoadRecentTransactions)
    }

    func didLoadRecentTransactions(_ result: Result<Page<Transaction>, Error>) {
        loadingRecentTransactions = false
        loadingRecentTransactionsView.isHidden = true
        defer {
            noRecentTransactionsLabel.isHidden = !recentTransactions.isEmpty
        }
        guard case let .success(page) = result else {
            result.showErrorIfPresent()
            return
        }
        recentTransactions.append(contentsOf: page.items)
        recentTransactionsListView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentTransactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "recent_tx_cell",
            for: indexPath
        ) as! TransactionTableViewCell

        let transaction: Transaction = recentTransactions[indexPath.row]
        cell.setTransaction(transaction: transaction)

        return cell
    }

    func showMessage(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showMessage(message: message)
        }
    }

    func showError(message: String?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(message: message)
        }
    }

    func showError(error: Error?) {
        DispatchQueue.main.async {
            AppDelegate.shared.mainController.showError(error: error)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "contentSize" {
            if change?[.newKey] != nil {
                let contentHeight: CGFloat = recentTransactionsListView.contentSize.height
                recentTxListHeightConstraint.constant = contentHeight
            }
        }
    }
}
