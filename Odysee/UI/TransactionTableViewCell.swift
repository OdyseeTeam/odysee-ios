//
//  TransactionTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 05/12/2020.
//

import SafariServices
import UIKit

class TransactionTableViewCell: UITableViewCell {
    
    var tx: Transaction?
    let txLinkPrefix = "https://explorer.lbry.com/tx"
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var txidLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var claimInfoLabel: UILabel!
    @IBOutlet weak var feeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setTransaction(transaction: Transaction) {
        tx = transaction
        descriptionLabel.text = Helper.describeTransaction(transaction: transaction)
        amountLabel.text = Helper.currencyFormatter4.string(from: Decimal(string: transaction.value!)! as NSDecimalNumber)
        txidLabel.text = String(transaction.txid!.prefix(7))
        
        if (transaction.timestamp == nil) {
            dateLabel.text = String.localized("Pending")
        } else {
            let date: Date = NSDate(timeIntervalSince1970: Double(transaction.timestamp!)) as Date
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            dateLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        }
        feeLabel.text = ""
        
        let txidTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.txidTapped(_:)))
        txidLabel.addGestureRecognizer(txidTapGesture)
    }
    
    @objc func txidTapped(_ sender: Any) {
        if tx != nil {
            if let url = URL(string: String(format: "%@/%@", txLinkPrefix, tx!.txid!)) {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }
}
