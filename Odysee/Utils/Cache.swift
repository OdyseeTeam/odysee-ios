//
//  Cache.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/11/2020.
//

import Foundation

// TODO: Remove in favor of PINRemoteImage.
class Cache {
    static let imageCache = NSCache<NSString, NSData>()

    static func putImage(url: String, image: Data) {
        imageCache.setObject(image as NSData, forKey: url as NSString)
    }
    static func getImage(url: String) -> Data? {
        return imageCache.object(forKey: url as NSString) as Data?
    }
}
