//
//  ThumbnailPicker.swift
//  Odysee
//
//  Created by Keith Toh on 09/05/2026.
//

import CachedAsyncImage
import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI

@available(iOS 16, *)
struct ThumbnailPicker: View {
    var imageWidth: Double

    var defaultImage: URL?

    // Updated by ViewModel
    @Binding var inProgress: Bool
    typealias Action = (URL) -> Void
    var action: Action

    @StateObject private var model: ViewModel = .init()

    private var placeholder: some View {
        Image("spaceman")
            .resizable().scaledToFit()
            .frame(width: imageWidth)
            .padding()
            .background(Color("light_primary"))
            .accessibilityHidden(true)
    }

    var body: some View {
        Group {
            switch model.imageState {
            case let .success(thumbnailImage):
                thumbnailImage.image.resizable().scaledToFit()
            case .empty:
                if let defaultImage {
                    CachedAsyncImage(url: defaultImage) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else if phase.error != nil {
                            placeholder
                        } else {
                            ProgressView()
                        }
                    }
                } else {
                    placeholder
                }
            case .loading:
                ProgressView()
            case .failure:
                Text("Thumbnail upload failed. Please try again")
            }
        }
        .frame(width: imageWidth, height: imageWidth * 9 / 16, alignment: .center)
        .overlay(alignment: .bottom) {
            PhotosPicker(selection: $model.imageSelection, matching: .images, photoLibrary: .shared()) {
                Image(systemName: Icons.editOverlay)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 30))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .onAppear {
            model.inProgress = _inProgress
            model.action = action
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
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(importedContentType: .image) { data in
                guard let uiImage = UIImage(data: data) else {
                    throw TransferError.importFailed
                }

                let imageUrl = try await Helper.uploadImage(image: uiImage)

                let image = Image(uiImage: uiImage)
                return ThumbnailImage(image: image, url: imageUrl)
            }
        }
    }

    @MainActor
    class ViewModel: ObservableObject {
        var inProgress: Binding<Bool>?
        var action: Action?

        @Published private(set) var imageState: ImageState = .empty

        @Published var imageSelection: PhotosPickerItem? = nil {
            didSet {
                if let imageSelection {
                    self.imageSelection = nil

                    Task {
                        inProgress?.wrappedValue = true
                        defer {
                            inProgress?.wrappedValue = false
                        }

                        do {
                            imageState = .loading
                            let image = try await imageSelection.loadTransferable(type: ThumbnailImage.self)

                            if let image {
                                imageState = .success(image)
                                action?(image.url)
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
