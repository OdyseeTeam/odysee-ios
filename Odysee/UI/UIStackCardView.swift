//
//  UIStackCardView.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 05/03/2021.
//

import UIKit

class UIStackCardView: UIStackView {
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
         // Drawing code
     }
     */
    var cornerRadius: CGFloat = 0
    var shadowOffsetWidth: CGFloat = 0
    var shadowOffsetHeight: CGFloat = 3
    var shadowColour = UIColor.systemGray
    var shadowOpacity: CGFloat = 0.6

    override func layoutSubviews() {
        layer.shadowColor = shadowColour.cgColor
        layer.shadowOffset = CGSize(width: shadowOffsetWidth, height: shadowOffsetHeight)

        let shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        layer.shadowPath = shadowPath.cgPath
        layer.shadowOpacity = Float(shadowOpacity)
    }
}
