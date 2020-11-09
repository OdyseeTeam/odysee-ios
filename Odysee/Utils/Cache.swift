//
//  Cache.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 09/11/2020.
//

import Foundation

class Cache {
    static let imageCache = NSCache<NSString, NSData>()

    static func putImage(url: String, image: Data) {
        imageCache.setObject(image as NSData, forKey: NSString(string: url))
    }
    static func getImage(url: String) -> Data? {
        return imageCache.object(forKey: NSString(string: url)) as Data?
    }
}
