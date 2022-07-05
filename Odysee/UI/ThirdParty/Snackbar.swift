//
//  https://github.com/JastAir/Snackbar-iOS/blob/master/snackbar/SnackBar/Snackbar.swift
//  Snackbar.swift
//  snackbar
//
//  Created by Нейкович Сергей on 30.11.16.
//  Copyright © 2016 CubInCup. All rights reserved.
//

import UIKit

enum SBAnimationLength {
    case short
    case long
}

class Snackbar: NSObject {
    // settings snackbar
    var snackbarHeight: CGFloat = 65
    var backgroundColor: UIColor = .darkGray
    var textColor: UIColor = .white
    var buttonColor: UIColor = .cyan
    var buttonColorPressed: UIColor = .gray
    var sbLength: SBAnimationLength = .short

    // private variables
    private let window = UIApplication.shared.keyWindow!
    private let snackbarView = UIView(frame: .zero)

    private let txt = UILabel()
    private let btn = UIButton()

    private var action: (() -> Void)?

    private var showingSnackbar = false
    private var kbSize = CGSize.zero

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rotate),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    /// Show simple text notification
    open func createWithText(_ text: String) {
        setupSnackbarView()

        txt.text = text
        txt.textColor = textColor
        txt.numberOfLines = 0
        txt.frame = CGRect(
            x: window.frame.width * 5 / 100,
            y: 0,
            width: window.frame.width * 95 / 100,
            height: snackbarHeight
        )
        snackbarView.addSubview(txt)

        show()
    }

    /// Show snackbar with text and button
    open func createWithAction(text: String, actionTitle: String, action: @escaping () -> Void) {
        self.action = action

        setupSnackbarView()

        txt.text = text
        txt.textColor = textColor
        txt.numberOfLines = 0
        txt.frame = CGRect(
            x: window.frame.width * 5 / 100,
            y: 0,
            width: window.frame.width * 75 / 100,
            height: snackbarHeight
        )
        snackbarView.addSubview(txt)

        btn.setTitleColor(buttonColor, for: .normal)
        btn.setTitleColor(.gray, for: .highlighted)
        btn.setTitle(actionTitle, for: .normal)
        btn.addTarget(self, action: #selector(actionButtonPress), for: .touchUpInside)
        btn.frame = CGRect(
            x: window.frame.width * 73 / 100,
            y: 0,
            width: window.frame.width * 25 / 100,
            height: snackbarHeight
        )
        snackbarView.addSubview(btn)

        show()
    }

    open func show() {
        switch sbLength {
        case .short:
            animateBar(2)

        case .long:
            animateBar(3)
        }
        showingSnackbar = true
    }

    private func setupSnackbarView() {
        window.addSubview(snackbarView)

        snackbarView.frame = CGRect(x: 0, y: window.bounds.height, width: window.frame.width, height: snackbarHeight)
        snackbarView.backgroundColor = backgroundColor
    }

    fileprivate func animateBar(_ timerLength: Float) {
        UIView.animate(withDuration: 0.4, animations: {
            self.updateSnackbarFrame()
            Timer.scheduledTimer(
                timeInterval: TimeInterval(timerLength),
                target: self,
                selector: #selector(self.hide),
                userInfo: nil,
                repeats: false
            )
        })
    }

    private func updateSnackbarFrame() {
        snackbarView.frame = CGRect(
            x: 0,
            y: window.bounds.height - snackbarHeight - kbSize.height,
            width: window.frame.width,
            height: snackbarHeight
        )
    }

    // MARK: Selectors

    @objc private func actionButtonPress() {
        action!()
        hide()
    }

    @objc private func hide() {
        showingSnackbar = false
        UIView.animate(withDuration: 0.4, animations: {
            self.snackbarView.frame = CGRect(
                x: 0,
                y: self.window.frame.height,
                width: self.window.frame.width,
                height: self.snackbarHeight
            )
        })
    }

    @objc private func rotate() {
        DispatchQueue.main.async {
            if self.showingSnackbar {
                self.updateSnackbarFrame()
            } else {
                self.hide()
            }
            self.btn.frame = CGRect(
                x: self.window.frame.width * 73 / 100,
                y: 0,
                width: self.window.frame.width * 25 / 100,
                height: self.snackbarHeight
            )
        }
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        let info = notification.userInfo
        kbSize = (info![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.size
        if showingSnackbar {
            updateSnackbarFrame()
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        kbSize = CGSize.zero
        if showingSnackbar {
            updateSnackbarFrame()
        }
    }
}
