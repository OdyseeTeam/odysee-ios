//
//  FileDismissAnimationController.swift
//  Odysee
//
//  Created by Adlai Holler on 5/17/21.
//

import UIKit

class FileDismissAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to)
        else {
            assertionFailure()
            return
        }

        transitionContext.containerView.insertSubview(toView, belowSubview: fromView)
        UIView.performWithoutAnimation {
            // We'll fade the header in as it grows so it looks nicer.
            AppDelegate.shared.mainController.headerArea.alpha = 0
            // The mini player is actually on top of us, so instead of it popping in, we hide it
            // and fade it in after the animation finishes.
            AppDelegate.shared.mainController.miniPlayerView.alpha = 0
            // The badge view isn't actually part of the header area so it doesn't animate
            // in correctly. We hide it during the transition then fade it back in.
            AppDelegate.shared.mainController.notificationBadgeView.alpha = 0
        }

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            options: .curveLinear
        ) {
            fromView.transform = CGAffineTransform(
                translationX: 0,
                y: transitionContext.containerView.bounds.height
            )
            AppDelegate.shared.mainController.toggleHeaderVisibility(hidden: false)
            AppDelegate.shared.mainController.headerArea.alpha = 1
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }

    func animationEnded(_ transitionCompleted: Bool) {
        // Fade the mini player & notification badge back in now that things have settled.
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            AppDelegate.shared.mainController.miniPlayerView.alpha = 1
            AppDelegate.shared.mainController.notificationBadgeView.alpha = 1
        }
    }
}
