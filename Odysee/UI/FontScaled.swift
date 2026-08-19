//
//  FontScaled.swift
//  Odysee
//
//  Created by Keith on 19/08/2026.
//

import SwiftUI
import UIKit

/// Reads the current font's point size
///
/// https://jaredsinclair.com/2024/03/02/scaled-metrics.html
@propertyWrapper
struct FontScaled: DynamicProperty {
    var factor: CGFloat = 1
    var style: UIFont.TextStyle

    init(wrappedValue factor: CGFloat = 1, relativeTo style: UIFont.TextStyle) {
        self.factor = factor
        self.style = style
    }

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var wrappedValue: CGFloat {
        let traits = UITraitCollection {
            $0.preferredContentSizeCategory = .init(dynamicTypeSize)
        }
        let font = UIFont.preferredFont(
            forTextStyle: style,
            compatibleWith: traits
        )
        return font.pointSize * factor
    }
}
