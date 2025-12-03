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

    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var txidLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var claimInfoLabel: UILabel!
    @IBOutlet var feeLabel: UILabel!

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
        descriptionLabel.text = transaction.description
        if let value = transaction.value, let valueDecimal = Decimal(string: value) {
            amountLabel.text = Helper.currencyFormatter4.string(from: valueDecimal as NSDecimalNumber)
        }
        if let txid = transaction.txid {
            txidLabel.text = String(txid.prefix(7))
        }

        claimInfoLabel.text = transaction.claim?.name

        if let timestamp = transaction.timestamp {
            let date: Date = NSDate(timeIntervalSince1970: Double(timestamp)) as Date
            dateLabel.text = Helper.shortRelativeDateFormatter.localizedString(for: date, relativeTo: Date())
        } else {
            dateLabel.text = String.localized("Pending")
        }
        feeLabel.text = ""

        let claimInfoTapGesture = UITapGestureRecognizer(target: self, action: #selector(claimInfoTapped(_:)))
        claimInfoLabel.addGestureRecognizer(claimInfoTapGesture)

        let txidTapGesture = UITapGestureRecognizer(target: self, action: #selector(txidTapped(_:)))
        txidLabel.addGestureRecognizer(txidTapGesture)
    }

    @objc func claimInfoTapped(_ sender: Any) {
        if let name = tx?.claim?.name, let claimId = tx?.claim?.claimId {
            if let url = LbryUri.tryParse(url: String(format: "%@#%@", name, claimId), requireProto: false) {
                if name.starts(with: "@") {
                    let vc = AppDelegate.shared.mainViewController?.storyboard?
                        .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = url
                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    // file claim
                    let vc = AppDelegate.shared.mainViewController?.storyboard?
                        .instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = url
                    AppDelegate.shared.mainNavigationController?.view.layer.add(
                        Helper.buildFileViewTransition(),
                        forKey: kCATransition
                    )
                    AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: false)
                }
            }
        }
    }

    @objc func txidTapped(_ sender: Any) {
        if let txid = tx?.txid {
            if let url = URL(string: String(format: "%@/%@", Helper.txLinkPrefix, txid)) {
                let vc = SFSafariViewController(url: url)
                AppDelegate.shared.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }
}
