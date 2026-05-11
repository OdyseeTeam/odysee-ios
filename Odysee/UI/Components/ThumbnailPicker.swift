//
//  ThumbnailPicker.swift
//  Odysee
//
//  Created by Keith Toh on 09/05/2026.
//

import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI

@available(iOS 16, *)
struct ThumbnailPicker: View {
    @StateObject var viewModel: ViewModel = .init()

    var imageWidth: Double

    var action: (String) -> Void

    var body: some View {
        Group {
            switch viewModel.imageState {
            case let .success(thumbnailImage):
                let _ = action(thumbnailImage.urlString)
                thumbnailImage.image.resizable().scaledToFit()
            case .empty:
                Image("spaceman")
                    .resizable().scaledToFit()
                    .frame(width: imageWidth)
                    .padding()
                    .background(Color("light_primary"))
            case .loading:
                ProgressView()
            case .failure:
                Text("Thumbnail upload failed. Please try again")
            }
        }
        .frame(width: imageWidth, height: imageWidth * 9 / 16, alignment: .center)
        .overlay(alignment: .bottom) {
            PhotosPicker(selection: $viewModel.imageSelection, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "pencil.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 30))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
    }

    enum ImageState {
        case empty
        case loading
        case success(ThumbnailImage)
        case failure(Error)
    }

    enum TransferError: Error {
        case importFailed
    }

    struct ThumbnailImage: Transferable {
        let image: Image
        let urlString: String

        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(importedContentType: .image) { data in
                guard let uiImage = UIImage(data: data) else {
                    throw TransferError.importFailed
                }

                let imageUrl = try await Helper.uploadImage(image: uiImage)

                let image = Image(uiImage: uiImage)
                return ThumbnailImage(image: image, urlString: imageUrl)
            }
        }
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published private(set) var inProgress: Bool = false

        @Published private(set) var imageState: ImageState = .empty

        @Published var imageSelection: PhotosPickerItem? = nil {
            didSet {
                if let imageSelection {
                    self.imageSelection = nil

                    Task {
                        inProgress = true
                        defer {
                            inProgress = false
                        }

                        do {
                            imageState = .loading
                            let image = try await imageSelection.loadTransferable(type: ThumbnailImage.self)

                            if let image {
                                imageState = .success(image)
                            } else {
                                imageState = .empty
                            }
                        } catch {
                            Helper.showError(error: error)
                            imageState = .failure(error)
                        }
                    }
                }
            }
        }
    }
}
