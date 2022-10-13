//
//  RestrictedUIHostingController.swift
//  Odysee
//
//  Created by Keith Toh on 10/10/2022.
//

import UIKit
import SwiftUI

final public class RestictedUIHostingController<Content>: UIHostingController<Content> where Content: View {
    public override var navigationController: UINavigationController? {
        nil
    }
}
