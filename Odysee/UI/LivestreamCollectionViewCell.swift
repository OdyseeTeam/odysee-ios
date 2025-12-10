//
//  LivestreamCollectionViewCell.swift
//  Odysee
//
//  Created by Keith Toh on 27/04/2022.
//

import UIKit

class LivestreamCollectionViewCell: UICollectionViewCell {
    static let nib = UINib(nibName: "LivestreamCollectionViewCell", bundle: nil)
    static let spacemanImage = UIImage(named: "spaceman")
    static let thumbImageSpec = ImageSpec(size: CGSize(width: 390, height: 220))

    var currentClaim: Claim?

    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var hasAccessView: UIStackView!
    @IBOutlet var membersOnlyView: UIView!
    @IBOutlet var viewerCountStackView: UIStackView!
    @IBOutlet var viewerCountLabel: UILabel!
    @IBOutlet var viewerCountImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var publisherLabel: UILabel!
    @IBOutlet var startTimeLabel: UILabel!

    var viewerCountBackground: UIView?

    override func awakeFromNib() {
        super.awakeFromNib()
        let publisherTapGesture = UITapGestureRecognizer(target: self, action: #selector(publisherTapped(_:)))
        publisherLabel.addGestureRecognizer(publisherTapGesture)
        thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
    }

    func setLivestreamInfo(claim: Claim, startTime: Date, viewerCount: Int) {
        setClaimInfo(claim: claim)

        let startTimeRelative = Helper.fullRelativeDateFormatter.localizedString(for: startTime, relativeTo: Date())
        startTimeLabel.text = "Started \(startTimeRelative)"

        viewerCountImageView.isHidden = viewerCount == 0
        if viewerCount > 0 {
            viewerCountLabel.text = String(viewerCount)
        } else {
            viewerCountLabel.text = "LIVE"
        }
    }

    func setFutureStreamClaim(claim: Claim) {
        setClaimInfo(claim: claim)

        var releaseTime = Double(claim.value?.releaseTime ?? "0") ?? 0
        if releaseTime == 0 {
            releaseTime = Double(claim.timestamp ?? 0)
        }

        if releaseTime > 0 {
            let date = Date(timeIntervalSince1970: releaseTime)
            let releaseTimeRelative = Helper.fullRelativeDateFormatter.localizedString(for: date, relativeTo: Date())
            startTimeLabel.text = String(format: String.localized("Live %@"), releaseTimeRelative)
        } else {
            startTimeLabel.text = "..."
        }

        viewerCountImageView.isHidden = true
        viewerCountStackView.backgroundColor = .black
        viewerCountBackground?.backgroundColor = .black
        viewerCountLabel.text = "LIVE"
    }

    func setClaimInfo(claim: Claim) {
        if let currentClaim, claim.claimId != currentClaim.claimId {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.pin_cancelImageDownload()
            thumbnailImageView.image = nil
            thumbnailImageView.backgroundColor = nil
        }

        backgroundColor = claim.featured ? UIColor.black : nil
        titleLabel.textColor = claim.featured ? UIColor.white : nil
        startTimeLabel.textColor = claim.featured ? UIColor.white : nil

        titleLabel.text = claim.name
        publisherLabel.text = claim.signingChannel?.titleOrName

        // load thumbnail url
        if let thumbnailUrl = claim.value?.thumbnail?.url.flatMap(URL.init) {
            thumbnailImageView.load(url: thumbnailUrl.makeImageURL(spec: Self.thumbImageSpec))
            thumbnailImageView.backgroundColor = nil
        } else {
            thumbnailImageView.image = Self.spacemanImage
            thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        }

        if claim.value?.tags?.contains(Constants.MembersOnly) ?? false {
            DispatchQueue.global().async {
                MembershipPerk.perkCheck(
                    authToken: Lbryio.authToken,
                    claimId: claim.claimId,
                    type: .livestream
                ) { result in
                    if case let .success(hasAccess) = result {
                        DispatchQueue.main.async {
                            self.membersOnlyView.isHidden = hasAccess
                            self.hasAccessView.isHidden = !hasAccess
                        }
                    }
                }
            }
        } else {
            membersOnlyView.isHidden = true
            hasAccessView.isHidden = true
        }

        currentClaim = claim
    }

    @objc func publisherTapped(_ sender: Any) {
        if let channelClaim = currentClaim?.signingChannel {
            let vc = AppDelegate.shared.mainController.storyboard?
                .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = channelClaim
            AppDelegate.shared.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    static func imagePrefetchURLs(claim: Claim) -> [URL] {
        if let thumbnailUrl = claim.value?.thumbnail?.url.flatMap(URL.init) {
            return [thumbnailUrl.makeImageURL(spec: thumbImageSpec)]
        }
        return []
    }
}
