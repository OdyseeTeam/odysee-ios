//
//  FileTableViewCell.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 08/11/2020.
//

import UIKit
import Odysee

class ClaimTableViewCell: UITableViewCell {
    static let nib = UINib(nibName: "ClaimTableViewCell", bundle: nil)
    static let spacemanImage = UIImage(named: "spaceman")
    static let thumbImageSpec = ImageSpec(size: CGSize(width: 390, height: 220))
    static let channelImageSpec = ImageSpec(size: CGSize(width: 100, height: 0))

    @IBOutlet var channelImageView: UIImageView!
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var hasAccessView: UIStackView!
    @IBOutlet var membersOnlyView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var publisherLabel: UILabel!
    @IBOutlet var publishTimeLabel: UILabel!
    @IBOutlet var durationView: UIView!
    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var viewerCountStackView: UIStackView!
    @IBOutlet var viewerCountLabel: UILabel!
    @IBOutlet var viewerCountImageView: UIView!

    var currentClaim: Claim?
    var reposterChannelClaim: Claim?

    var reposterOverlay: UIStackView!
    var reposterLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        let publisherTapGesture = UITapGestureRecognizer(target: self, action: #selector(publisherTapped(_:)))
        publisherLabel.addGestureRecognizer(publisherTapGesture)
        channelImageView.rounded()
        channelImageView.backgroundColor = Helper.lightPrimaryColor
        thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
        createRepostOverlay()

        if #available(iOS 14, *) {
        } else {
            let viewerCountBackground = UIView()
            viewerCountBackground.backgroundColor = Helper.primaryColor
            viewerCountBackground.layer.cornerRadius = 6
            viewerCountBackground.translatesAutoresizingMaskIntoConstraints = false
            viewerCountStackView.insertSubview(viewerCountBackground, at: 0)
            NSLayoutConstraint.activate([
                viewerCountBackground.leadingAnchor.constraint(equalTo: viewerCountStackView.leadingAnchor),
                viewerCountBackground.trailingAnchor.constraint(equalTo: viewerCountStackView.trailingAnchor),
                viewerCountBackground.topAnchor.constraint(equalTo: viewerCountStackView.topAnchor),
                viewerCountBackground.bottomAnchor.constraint(equalTo: viewerCountStackView.bottomAnchor)
            ])
        }
    }

    static func imagePrefetchURLs(claim: Claim) -> [URL] {
        if claim.claimId == "placeholder" || claim.claimId == "new" {
            return []
        }

        var actualClaim: Claim = claim
        if claim.valueType == ClaimType.repost, claim.repostedClaim != nil {
            actualClaim = claim.repostedClaim!
        }

        var result = [URL]()
        if let thumbnailUrl = actualClaim.value?.thumbnail?.url.flatMap(URL.init) {
            let isChannel = actualClaim.name?.starts(with: "@") ?? false
            let spec = isChannel ? Self.channelImageSpec : Self.thumbImageSpec
            result.append(thumbnailUrl.makeImageURL(spec: spec))
        }
        return result
    }

    func setLivestreamClaim(claim: Claim, startTime: Date, viewerCount: Int) {
        setClaim(claim: claim)

        publishTimeLabel.text = String(
            format: String.localized("Started %@"),
            Helper.fullRelativeDateFormatter.localizedString(for: startTime, relativeTo: Date())
        )
        viewerCountStackView.isHidden = false
        durationView.isHidden = true
        viewerCountImageView.isHidden = viewerCount == 0
        if viewerCount > 0 {
            viewerCountLabel.text = String(viewerCount)
        } else {
            viewerCountLabel.text = "LIVE"
        }
    }

    func setClaim(claim: Claim) {
        setClaim(claim: claim, showRepostOverlay: true)
    }

    func setClaim(claim: Claim, showRepostOverlay: Bool) {
        guard let _ = claim.claimId else {
            return
        }

        var actualClaim: Claim = claim
        if claim.valueType == ClaimType.repost && claim.repostedClaim != nil {
            reposterOverlay.isHidden = !showRepostOverlay
            reposterChannelClaim = claim.signingChannel
            reposterLabel.text = reposterChannelClaim?.name ?? claim.shortUrl
            actualClaim = claim.repostedClaim!
        } else {
            reposterOverlay.isHidden = true
        }

        if currentClaim != nil && actualClaim.claimId != currentClaim!.claimId {
            // reset the thumbnail image (to prevent the user from seeing image load changes when scrolling due to cell reuse)
            thumbnailImageView.pin_cancelImageDownload()
            thumbnailImageView.image = nil
            thumbnailImageView.backgroundColor = nil
            channelImageView.pin_cancelImageDownload()
            channelImageView.image = nil
            channelImageView.backgroundColor = nil
        }

        backgroundColor = actualClaim.featured ? UIColor.black : nil

        thumbnailImageView.backgroundColor = actualClaim.claimId == "placeholder" ? UIColor.systemGray5 : UIColor.clear
        titleLabel.backgroundColor = actualClaim.claimId == "placeholder" ? UIColor.systemGray5 : UIColor.clear
        publisherLabel.backgroundColor = actualClaim.claimId == "placeholder" ? UIColor.systemGray5 : UIColor.clear
        publishTimeLabel.backgroundColor = actualClaim.claimId == "placeholder" ? UIColor.systemGray5 : UIColor.clear
        durationView.isHidden = actualClaim.claimId == "placeholder" || actualClaim.claimId == "new"

        if actualClaim.claimId == "placeholder" {
            titleLabel.text = nil
            publisherLabel.text = nil
            publishTimeLabel.text = nil
            return
        }

        if actualClaim.claimId == "new" {
            titleLabel.text = String.localized("New Upload")
            publisherLabel.text = nil
            publishTimeLabel.text = nil
            thumbnailImageView.image = Self.spacemanImage
            return
        }

        currentClaim = actualClaim

        let isChannel = actualClaim.name!.starts(with: "@")
        channelImageView.isHidden = !isChannel
        thumbnailImageView.isHidden = isChannel

        titleLabel.textColor = actualClaim.featured ? UIColor.white : nil
        titleLabel.text = actualClaim.value?.title
        publisherLabel.text = isChannel ? actualClaim.name : actualClaim.signingChannel?.titleOrName

        // load thumbnail url
        if let thumbnailUrl = actualClaim.value?.thumbnail?.url.flatMap(URL.init) {
            if isChannel {
                channelImageView.load(url: thumbnailUrl.makeImageURL(spec: Self.channelImageSpec))
            } else {
                thumbnailImageView.load(url: thumbnailUrl.makeImageURL(spec: Self.thumbImageSpec))
            }
        } else {
            if isChannel {
                channelImageView.image = Self.spacemanImage
                channelImageView.backgroundColor = Helper.lightPrimaryColor
            } else {
                thumbnailImageView.image = Self.spacemanImage
                thumbnailImageView.backgroundColor = Helper.lightPrimaryColor
            }
        }

        var releaseTime = Double(actualClaim.value?.releaseTime ?? "0")!
        if releaseTime == 0 {
            releaseTime = Double(actualClaim.timestamp ?? 0)
        }
        let confirmations = actualClaim.confirmations ?? 0

        publishTimeLabel.textColor = actualClaim.featured ? UIColor.white : nil
        if releaseTime > 0 && confirmations > 0 {
            let date = Date(timeIntervalSince1970: releaseTime) // TODO: Timezone check / conversion?
            publishTimeLabel.text = Helper.fullRelativeDateFormatter.localizedString(for: date, relativeTo: Date())
        } else {
            publishTimeLabel.text = String.localized("Pending")
        }

        var duration: Int64 = 0
        if actualClaim.value?.video != nil || actualClaim.value?.audio != nil {
            let streamInfo = actualClaim.value?.video ?? actualClaim.value?.audio
            duration = streamInfo?.duration ?? 0
        }

        let isLivestream = actualClaim.value?.source == nil && !isChannel
        durationView.isHidden = duration <= 0 && !isLivestream
        if duration > 0 {
            if duration < 60 {
                durationLabel.text = String(format: "0:%02d", duration)
            } else {
                durationLabel.text = Helper.durationFormatter.string(from: TimeInterval(duration))
            }
        } else if isLivestream {
            durationLabel.text = "LIVE"
        }

        if actualClaim.value?.tags?.contains(Constants.MembersOnly) ?? false {
            DispatchQueue.global().async {
                MembershipPerk.perkCheck(
                    authToken: Lbryio.authToken,
                    claimId: actualClaim.claimId,
                    type: isLivestream ? .livestream : .content
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
    }

    private func createRepostOverlay() {
        reposterOverlay = UIStackView()
        reposterOverlay.backgroundColor = Helper.primaryColor.withAlphaComponent(0.8)
        reposterOverlay.bounds = CGRect(x: 0, y: 0, width: 116, height: 30)
        reposterOverlay.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        reposterOverlay.layer.position = CGPoint(x: 20, y: 20)
        reposterOverlay.transform = CGAffineTransform(rotationAngle: -45.0 / 180.0 * .pi)
        reposterOverlay.axis = .vertical
        reposterOverlay.alignment = .center
        contentView.addSubview(reposterOverlay)
        reposterOverlay.isHidden = true

        // TODO: arrow.triangle.2.circlepath on iOS 14+
        let imageView = UIImageView(image: UIImage(systemName: "arrow.2.circlepath")!)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        reposterOverlay.addArrangedSubview(imageView)
        addConstraints([
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 14),
        ])

        reposterLabel = UILabel()
        reposterLabel.translatesAutoresizingMaskIntoConstraints = false
        reposterLabel.textColor = .white
        reposterLabel.textAlignment = .center
        reposterLabel.font = .systemFont(ofSize: 12)
        reposterOverlay.addArrangedSubview(reposterLabel)
        addConstraints([
            reposterLabel.widthAnchor.constraint(equalTo: reposterOverlay.widthAnchor, constant: -25),
        ])

        let reposterTapGesture = UITapGestureRecognizer(target: self, action: #selector(reposterTapped(_:)))
        reposterOverlay.addGestureRecognizer(reposterTapGesture)
    }

    @objc func publisherTapped(_ sender: Any) {
        if currentClaim!.signingChannel != nil {
            let channelClaim = currentClaim!.signingChannel!
            let appDelegate = UIApplication.shared.delegate as! AppDelegate

            let currentVc = UIApplication.currentViewController()
            if let channelVc = currentVc as? ChannelViewController {
                if channelVc.channelClaim?.claimId == channelClaim.claimId {
                    // if we already have the channel page open, don't do anything
                    return
                }
            }

            let vc = appDelegate.mainController.storyboard?
                .instantiateViewController(identifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = channelClaim
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func reposterTapped(_ sender: Any) {
        if let channelClaim = reposterChannelClaim {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate

            if let currentVc = UIApplication.currentViewController() as? ChannelViewController {
                if currentVc.channelClaim?.claimId == channelClaim.claimId {
                    // if we already have the channel page open, don't do anything
                    return
                }
            }

            let vc = appDelegate.mainController.storyboard?
                .instantiateViewController(withIdentifier: "channel_view_vc") as! ChannelViewController
            vc.channelClaim = channelClaim
            appDelegate.mainNavigationController?.pushViewController(vc, animated: true)
        }
    }
}
