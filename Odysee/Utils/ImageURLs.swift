//
//  ImageURLs.swift
//  Odysee
//
//  Created by Adlai Holler on 6/16/21.
//

import Foundation
import PINRemoteImage
import UIKit

fileprivate let kImageServerBaseURL = "https://image-processor.vanwanet.com/optimize/"
fileprivate let kScale = UIScreen.main.scale

struct ImageSpec {
    var size: CGSize?
    var quality: Int?
    var format: String? = "webp"
    
    func appendPathSpecifier(to str: inout String) {
        if let size = size {
            str += "s:\(Int(size.width * kScale)):\(Int(size.height * kScale))/"
        }
        if let quality = quality {
            str += "quality:\(quality)/"
        }
    }
    func appendFormatSpecifier(to str: inout String) {
        if let format = format {
            str += "@\(format)"
        }
    }
}

extension URL {
    func makeImageURL(spec: ImageSpec) -> URL {
        var str = kImageServerBaseURL
        spec.appendPathSpecifier(to: &str)
        str += "plain/"
        str += absoluteString
        spec.appendFormatSpecifier(to: &str)
        return URL(string: str)!
    }
}
