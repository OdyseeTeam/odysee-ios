//
//  VideoPickerController.swift
//  Odysee
//
//  Created by Adlai Holler on 5/29/21.
//

import MobileCoreServices
import PhotosUI
import UIKit

typealias PickVideoCompletion = (Bool) -> Void

protocol VideoPickerController {
    var pickedVideoName: String? { get }
    // `completion` runs on main thread
    func pickVideo(from sourceVC: UIViewController, completion: @escaping PickVideoCompletion)
    // `completion` runs off main thread
    func getVideoURL(completion: @escaping (Result<URL, Error>) -> Void)
}

func makeVideoPickerController() -> VideoPickerController {
    if #available(iOS 14, *) {
        return ModernVideoPickerController()
    } else {
        return LegacyVideoPickerController()
    }
}

// MARK: Private

fileprivate class BaseVideoPickerController<Payload> : NSObject {
    var payload: Payload?
    var pickingCompletion: PickVideoCompletion?
    var viewController: UIViewController?
    
    func startPicking(_ vc: UIViewController,
                      sourceVC: UIViewController,
                      completion: @escaping PickVideoCompletion) {
        assert(Thread.isMainThread)
        self.viewController = vc
        self.pickingCompletion = completion
        vc.modalPresentationStyle = .overCurrentContext
        sourceVC.present(vc, animated: true)
    }
    
    func didFinishPicking(_ newPayload: Payload?) {
        assert(Thread.isMainThread)
        if let newPayload = newPayload {
            payload = newPayload
        }
        viewController?.dismiss(animated: true)
        viewController = nil
        pickingCompletion?(newPayload != nil)
        pickingCompletion = nil
    }
}

// iOS<14 implementation based on UIImagePickerController

@available(iOS, deprecated: 14)
fileprivate final class LegacyVideoPickerController : BaseVideoPickerController<URL>,
                                                      VideoPickerController,
                                                      UIImagePickerControllerDelegate,
                                                      UINavigationControllerDelegate {
    
    // MARK: VideoPickerController

    var pickedVideoName: String? {
        return payload?.lastPathComponent
    }
    
    func pickVideo(from sourceVC: UIViewController, completion: @escaping PickVideoCompletion) {
        let vc = UIImagePickerController()
        vc.mediaTypes = [String(kUTTypeMovie)]
        vc.delegate = self
        startPicking(vc, sourceVC: sourceVC, completion: completion)
    }
    
    func getVideoURL(completion: @escaping (Result<URL, Error>) -> Void) {
        let result = Result<URL, Error> {
            guard let url = payload else {
                throw GenericError("Please select a video")
            }
            return url
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            completion(result)
        }
    }
    
    // MARK: UIImagePickerControllerDelegate

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.didFinishPicking(nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo
                                info: [UIImagePickerController.InfoKey : Any]) {
        self.didFinishPicking(info[.mediaURL] as? URL)
    }
}

// iOS 14 implementation based on PHPickerViewController

@available(iOS 14, *)
fileprivate final class ModernVideoPickerController : BaseVideoPickerController<NSItemProvider>,
                                                      VideoPickerController,
                                                      PHPickerViewControllerDelegate {
    
    // MARK: VideoPickerController
    
    var pickedVideoName: String? {
        if let payload = payload {
            assert(payload.suggestedName != nil)
            return payload.suggestedName ?? "video"
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
        guard let itemProvider = payload else {
            completion(.failure(GenericError("Please select a video")))
            return
        }
    
        itemProvider.loadInPlaceFileRepresentation(forTypeIdentifier: String(kUTTypeMovie)) {
            url, inPlace, error in
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

