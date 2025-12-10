//
//  VideoPickerController.swift
//  Odysee
//
//  Created by Adlai Holler on 5/29/21.
//

import PhotosUI
import UIKit

typealias PickVideoCompletion = (Bool) -> Void

class VideoPickerController: PHPickerViewControllerDelegate {
    var itemProvider: NSItemProvider?
    var pickingCompletion: PickVideoCompletion?
    var viewController: UIViewController?

    func startPicking(
        _ vc: UIViewController,
        sourceVC: UIViewController,
        completion: @escaping PickVideoCompletion
    ) {
        assert(Thread.isMainThread)
        viewController = vc
        pickingCompletion = completion
        vc.modalPresentationStyle = .overCurrentContext
        sourceVC.present(vc, animated: true)
    }

    func didFinishPicking(_ itemProvider: NSItemProvider?) {
        assert(Thread.isMainThread)
        self.itemProvider = itemProvider
        viewController?.dismiss(animated: true)
        viewController = nil
        pickingCompletion?(itemProvider != nil)
        pickingCompletion = nil
    }

    var pickedVideoName: String? {
        if let itemProvider {
            assert(itemProvider.suggestedName != nil)
            return itemProvider.suggestedName ?? "video"
        } else {
            return nil
        }
    }

    func pickVideo(from sourceVC: UIViewController, completion: @escaping PickVideoCompletion) {
        var cfg = PHPickerConfiguration()
        cfg.filter = .videos
        let vc = PHPickerViewController(configuration: cfg)
        vc.delegate = self
        startPicking(vc, sourceVC: sourceVC, completion: completion)
    }

    func getVideoURL(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let itemProvider else {
            completion(.failure(GenericError("Please select a video")))
            return
        }

        itemProvider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.movie.identifier) {
            url, _, error in
            let result = Result<URL, Error> {
                if let error = error {
                    throw error
                }
                guard let url = url else {
                    throw GenericError("Unable to load video")
                }
                return url
            }
            completion(result)
        }
    }

    // MARK: PHPickerViewControllerDelegate

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        didFinishPicking(results.first?.itemProvider)
    }
}
