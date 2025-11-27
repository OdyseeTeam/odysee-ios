//
//  FirstRunDelegate.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 17/03/2021.
//

import Foundation
import UIKit

protocol FirstRunDelegate {
    func requestStarted()
    func requestFinished(showSkip: Bool, showContinue: Bool)
    func finalPageReached()
    func showViewController(_ vc: UIViewController)
    func updateFirstChannelName(_ name: String?)
    func nextStep()
    func continueProcess()
}
