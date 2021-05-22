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
        descriptionLabel.text = transaction.description
        amountLabel.text = Helper.currencyFormatter4.string(from: Decimal(string: transaction.value!)! as NSDecimalNumber)
        txidLabel.text = String(transaction.txid!.prefix(7))
        
        claimInfoLabel.text = transaction.claim != nil ? transaction.claim!.name : ""
        
        if (transaction.timestamp == nil) {
            dateLabel.text = String.localized("Pending")
        } else {
            let date: Date = NSDate(timeIntervalSince1970: Double(transaction.timestamp!)) as Date
            dateLabel.text = Helper.shortRelativeDateFormatter.localizedString(for: date, relativeTo: Date())
        }
        feeLabel.text = ""
        
        let claimInfoTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.claimInfoTapped(_:)))
        claimInfoLabel.addGestureRecognizer(claimInfoTapGesture)
        
        let txidTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.txidTapped(_:)))
        txidLabel.addGestureRecognizer(txidTapGesture)
    }
    
    @objc func claimInfoTapped(_ sender: Any) {
        if tx != nil && tx!.claim != nil {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let claim = tx!.claim!
            let url = LbryUri.tryParse(url: String(format: "%@#%@", claim.name!, claim.claimId!), requireProto: false)
            if url != nil {
                if claim.name!.starts(with: "@") {
                    let vc = appDelegate.mainViewController?.storyboard?.instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
                    vc.claimUrl = url
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
                } else {
                    // file claim
                    let vc = appDelegate.mainViewController?.storyboard?.instantiateViewController(identifier: "file_view_vc") as! FileViewController
                    vc.claimUrl = url
                    appDelegate.mainNavigationController?.view.layer.add(Helper.buildFileViewTransition(), forKey: kCATransition)
                    appDelegate.mainNavigationController?.pushViewController(vc, animated: false)
                }
            }
        }
    }
    
    @objc func txidTapped(_ sender: Any) {
        if tx != nil {
            if let url = URL(string: String(format: "%@/%@", Helper.txLinkPrefix, tx!.txid!)) {
                let vc = SFSafariViewController(url: url)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.mainController.present(vc, animated: true, completion: nil)
            }
        }
    }
}
