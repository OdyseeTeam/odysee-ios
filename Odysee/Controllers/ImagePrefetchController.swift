//
//  ImagePrefetchController.swift
//  Odysee
//
//  Created by Adlai Holler on 6/3/21.
//

import Foundation
import PINRemoteImage

// A helper for using PINRemoteImage+UITableViewDataSourcePrefetching.
// You give it a `(IndexPath) -> [URL]` to get the URLs for a given cell.
// You forward it the `prefetchRows` and `cancelPrefetching` calls.
// It manages the prefetching.
class ImagePrefetchingController {
    private let mgr = PINRemoteImageManager.shared()
    private let imageURLProvider: (IndexPath) -> [URL]
    private var prefetchingMap = [IndexPath: [UUID]]()

    init(imageURLProvider: @escaping (IndexPath) -> [URL]) {
        assert(Thread.isMainThread)
        self.imageURLProvider = imageURLProvider
    }

    deinit {
        assert(Thread.isMainThread)
        for uuids in prefetchingMap.values {
            uuids.forEach(mgr.cancelTask)
        }
    }

    func prefetch(at indexPaths: [IndexPath]) {
        assert(Thread.isMainThread)
        prefetchingMap.reserveCapacity(prefetchingMap.count + indexPaths.count)
        // TODO: We would like to sort these index paths intelligently by distance from the center
        // of the viewport, so that we start prefetching the rows most likely to be seen next.
        // However, in iOS 14 there is a bug if we call rectForRowAtIndexPath: here, and the
        // indexPathForRowAt: method is also unreliable here.
        for indexPath in indexPaths {
            if prefetchingMap[indexPath] != nil {
                return
            }
            let urls = imageURLProvider(indexPath)
            if !urls.isEmpty {
                let uuids = mgr.prefetchImages(with: urls)
                prefetchingMap[indexPath] = uuids
            }
        }
    }
    
    // NOTE: The index paths in this method do NOT necessarily refer to indexes
    // in the data source. For instance, if you delete all the items, you'll get
    // cancelPrefetch for the items you had beforehand. The index paths only
    // refer to index paths from previous calls to `prefetch`
    func cancelPrefetching(at indexPaths: [IndexPath]) {
        assert(Thread.isMainThread)
        for indexPath in indexPaths {
            guard let index = prefetchingMap.index(forKey: indexPath) else {
                continue
            }
            prefetchingMap[index].value.forEach(mgr.cancelTask)
            prefetchingMap.remove(at: index)
        }
    }
}
