//
//  ChannelScreen.swift
//  Odysee
//
//  Created by Keith on 21/09/2026.
//

import ListItemTracking
import SwiftUI

@available(iOS 16, *)
extension ChannelScreen {
    enum Channel {
        case claim(Claim)
        case uri(name: String, claimId: String)
    }
}

@available(iOS 16, *)
struct ChannelScreen: View {
    @State var channel: Channel

    @State private var error: Error?
    @State private var abandoned: Bool = false

    @State private var tab: Int = 2

    var body: some View {
        if let error {
            Text(error.localizedDescription)
                .foregroundStyle(.red)
        } else if case let .claim(claim) = channel {
            VStack {
                Image(.spacemanCover)
                    .resizable()
                    .frame(maxHeight: 100)

//                TabView(selection: $tab) {
//                    Text("A")
//                        .tag(0)
//
//                    Text("b")
//                        .tag(1)
//
                Comments(
                    // FIXME: Shouldn't be nil in model
                    model: .init(claimId: claim.claimId ?? "")
                )
                .tag(2)
//                }
//                .tabViewStyle(.page(indexDisplayMode: .always))
//                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        } else if case let .uri(name, claimId) = channel {
            if abandoned {
                // FIXME: Maybe
                Text("This channel may have been unpublished.")
            } else {
                ProgressView()
                    .task {
                        do {
                            let resolve = try await BackendMethods.resolve.call(params: .init(
                                urls: [LbryUri.normalize(url: "\(name)#\(claimId)")]
                            ))

                            guard let claim = resolve.claims.values.first else {
                                abandoned = true
                                return
                            }

                            channel = .claim(claim)
                        } catch {
                            self.error = error
                        }
                    }
            }
        }
    }
}

@available(iOS 16, *)
#Preview {
    ChannelScreen(channel: .uri(
        // FIXME: Change to odysee
        name: "@ktprograms", claimId: "989f7977d0394ec45389ba05c50109dd958b655e"
    ))
}

@available(iOS 17, *)
struct Thing: View {
    @State var offset: CGFloat = 0
    @State var tab: Int = 0

    struct A: View {
        var num: Int
        var range: Range<Int>
        @Binding var offset: CGFloat
        @Binding var tab: Int

        @State var myOffset: CGFloat?

        var body: some View {
            GeometryReader { listGeometry in
                List {
                    Color.red
                        .listRowInsets(.init())
                        .frame(height: 300)
                        .onItemFrameChanged(listGeometry: listGeometry) { frame in
                            myOffset = frame?.origin.y
                            print("MYLOG", myOffset)

                            if tab == num {
                                if let frame {
                                    offset = frame.origin.y
                                } else {
                                    offset = -300
                                }
                            }
                        }
                        .onChange(of: tab) {
                            if tab == num {
                                offset = myOffset ?? -300
                            }
                        }

                    ForEach(range) {
                        Text(String($0))
                    }
                }
                .listStyle(.plain)
                .trackListFrame()
            }
            .ignoresSafeArea()
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            A(num: 0, range: 1 ..< 100, offset: $offset, tab: $tab)
                .tag(0)

            A(num: 1, range: 100 ..< 200, offset: $offset, tab: $tab)
                .tag(1)

            A(num: 2, range: 200 ..< 300, offset: $offset, tab: $tab)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            ZStack(alignment: .bottom) {
                Image(.spacemanCover)
                    .resizable()
                    .opacity(0.5)
                    .scaledToFill()

                Text("Hellorld!")
                    .foregroundStyle(.white)
            }
            .frame(height: 300 + max(0, offset))
            .offset(y: min(0, max(offset, -200)))
            .ignoresSafeArea()
        }
    }
}

@available(iOS 17, *)
#Preview {
    Thing()
}

#Preview {
    TabView {
        Color.red
    }
    .tabViewStyle(.page(indexDisplayMode: .always))
    .indexViewStyle(.page(backgroundDisplayMode: .always))
    .overlay(alignment: .top) {
        Color.purple
            .frame(height: 100)
            .ignoresSafeArea()
    }
}

struct TheView: View {
    @State var selection = 1
    @State var offset: CGFloat = 0

    var body: some View {
        // FIXME: Make sure refreshable works (or don't)
        TabView(selection: $selection) {
            FrameTrackingList(offset: $offset, tag: 1, selection: $selection) {
                ForEach(1 ..< 100) {
                    Text(String($0))
                }
            }
            FrameTrackingList(offset: $offset, tag: 2, selection: $selection) {
                ForEach(100 ..< 200) {
                    Text(String($0))
                }
            }
            FrameTrackingList(offset: $offset, tag: 3, selection: $selection) {
                ForEach(200 ..< 300) {
                    Text(String($0))
                }
            }
        }
        .sharedHeaderPageView(
            offset: $offset,
            headerHeight: 300,
            headerMinHeight: 80
        ) {
            ZStack(alignment: .bottom) {
//                Image(.spacemanCover)
//                    .resizable()
//                    .scaledToFill()
//                    .blur(radius: 20)
//                    .frame(height: 300 + max(0, offset))
//                    .clipShape(.rect)
//
//                Image(.spacemanCover)
//                    .resizable()
//                    .scaledToFit()

                // This is from https://github.com/danielsaidi/ScrollKit/blob/main/Sources/ScrollKit/ScrollViewHeaderImage.swift
                Color.clear
                    .background {
                        Image(.spacemanCover)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()

                VStack {
                    Spacer()

                    Text("Hello world!")
                        .padding()
                        .background(.black)
                        .clipShape(.capsule)
                        .foregroundStyle(.white)

                    Spacer()
                }
                .frame(height: 80)
            }
        }
        .border(.black)
    }
}
