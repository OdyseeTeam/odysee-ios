//
//  StickyHeaderListsTabView.swift
//  Odysee
//
//  Created by Keith on 23/09/2026.
//

// Adapted from https://danielsaidi.com/blog/2023/02/09/adding-a-sticky-header-to-a-swiftui-scroll-view and https://github.com/danielsaidi/ScrollKit

import ListItemTracking
import SwiftUI

extension EnvironmentValues {
    // MARK: FrameTrackingList

    @Entry var stickyHeaderHeight: CGFloat = 0
}

/// A `List` that can be used as a `Tab`, which provides its scroll offset,
/// primarily for use with a shared sticky header
///
/// Ignores top safe area
struct FrameTrackingList<SelectionValue: Hashable, Content: View>: View {
    /// The shared offset to be used by the header overlay
    // FIXME: Does private(set) prevent setting from outside
    @Binding private(set) var offset: CGFloat

    /// Tag to identify which list (tab) this view is
    var tag: SelectionValue
    // FIXME: Test if this is not binding, will rerender whole view?
    /// The currently selected tab of the `TabView`,
    /// to check when this tab becomes active
    @Binding var selection: SelectionValue

    @ContentBuilder var content: () -> Content

    /// The current offset of this list (tab),
    /// to update shared when this tab becomes active
    ///
    /// `nil` if list is scrolled "past" the header
    @State private var myOffset: CGFloat?

    @Environment(\.stickyHeaderHeight) private var headerHeight

    var body: some View {
        GeometryReader { listGeometry in
            List {
                Color.clear
                    .listRowInsets(.init())
                    .frame(height: headerHeight)
                    .onItemFrameChanged(listGeometry: listGeometry) { frame in
                        myOffset = frame?.origin.y

                        updateOffset()
                    }

                content()
            }
            .listStyle(.plain)
            .trackListFrame()
        }
        .ignoresSafeArea(edges: .top)
        .tag(tag)
        .onChange(of: selection) { _ in
            updateOffset()
        }
    }

    /// If this tab is active, updates `offset` to either the current offset, if not `nil`,
    /// or `-1 * headerHeight`, so that the header is entirely out of view
    private func updateOffset() {
        if tag == selection {
            offset = myOffset ?? (-1 * headerHeight)
        }
    }
}

/// Ignores top safe area
struct PageViewHeaderSharing<Header: View>: ViewModifier {
    /// The shared offset to be used by the header overlay
    // FIXME: Does private(set) prevent setting from outside
    @Binding private(set) var offset: CGFloat

    var headerHeight: CGFloat
    var headerMinHeight: CGFloat

    @ViewBuilder var header: () -> Header

    /// The height of the header, plus a "stretch" if scrolling past the top (bouncy)
    private var headerFrameHeight: CGFloat {
        headerHeight + max(0, offset)
    }

    /// The offset, following scroll offset, except
    /// for staying at the top (it'll be filled in by "stretch") if scrolling past the top (bouncy),
    /// and leaving a minimum amount when scrolling down (sticky)
    private func headerOffset(geometry: GeometryProxy) -> CGFloat {
        // Delcared minimum height plus height taken by safe area
        let trueHeaderMinHeight = headerMinHeight + geometry.safeAreaInsets.top

        // The point at which the header offset must be stuck at,
        // to keep the minimum header height visible
        let remaining = headerHeight - trueHeaderMinHeight

        return min(0, max(offset, -1 * remaining))
    }

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    header()
                        .frame(maxHeight: headerFrameHeight)
                        .offset(y: headerOffset(geometry: geometry))
                        .ignoresSafeArea(edges: .top)
                }
                .environment(\.stickyHeaderHeight, headerHeight)
        }
    }
}

extension TabView {
    /// Ignores top safe area
    func sharedHeaderPageView<Header: View>(
        offset: Binding<CGFloat>,
        headerHeight: CGFloat,
        headerMinHeight: CGFloat,
        header: @escaping () -> Header
    ) -> some View {
        modifier(PageViewHeaderSharing(
            offset: offset,
            headerHeight: headerHeight,
            headerMinHeight: headerMinHeight,
            header: header
        ))
    }
}

@available(iOS 17, *)
#Preview {
    @Previewable @State var selection = 1
    @Previewable @State var offset: CGFloat = 0

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

            ScrollViewHeaderImage(Image(.spacemanCover))

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
