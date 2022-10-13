//
//  NetworkImage.swift
//  Odysee
//
//  Created by Keith Toh on 11/10/2022.
//
//  Uses AsyncImage on iOS 15 and above,
//  and manual loading on older versions
//
//  Manual loading code from
//  https://stackoverflow.com/a/65778418/15603854


import Combine
import SwiftUI

struct NetworkImage: View {
    @ObservedObject var viewModel = ViewModel()

    let url: URL?

    var body: some View {
        if #available(iOS 15, *) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.black
            }
        } else {
            Group {
                if let data = viewModel.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.black
                }
            }
            .onAppear {
                viewModel.loadImage(from: url)
            }
        }
    }

    class ViewModel: ObservableObject {
        @Published var imageData: Data?

        private static let cache = NSCache<NSURL, NSData>()

        private var cancellables = Set<AnyCancellable>()

        func loadImage(from url: URL?) {
            guard let url = url else {
                return
            }

            if let data = Self.cache.object(forKey: url as NSURL) {
                imageData = data as Data
                return
            }

            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .replaceError(with: nil)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    if let data = $0 {
                        Self.cache.setObject(data as NSData, forKey: url as NSURL)
                        self?.imageData = data
                    }
                }
                .store(in: &cancellables)
        }
    }
}
