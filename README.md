# Odysee iOS
[![GitHub license](https://img.shields.io/github/license/lbryio/odysee-ios)](https://github.com/lbryio/odysee-ios/blob/master/LICENSE)

The Odysee iOS app with wallet functionality.

## Installation
The minimum supported iOS version is 13.0. You can install the app from the [Apple App Store](https://apps.apple.com/us/app/odysee/id1539444143). You can also obtain early access releases by joining the [TestFlight beta program](https://testflight.apple.com/join/8VLNhU79). 

## Usage
The app can be launched by opening **Odysee** from the app list on your device. 

## Running from Source
Clone the repository and open the project in XCode. Click the Build and run current scheme button to build the project and launch the app in one of the available simulators or a connected device.

## Style and Formatting
We use [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) to enforce a consistent format for all Swift code. You can see our custom configuration in this repo’s `.swiftformat` file.

`swiftformat . --lint` must pass before merging to `master`. To run it locally, first install it using [`Mint](https://github.com/yonaskolb/Mint) and `mint bootstrap --link`, and then run `swiftformat .` which will automatically format all of your Swift code. If any of your default Xcode text editing preferences are inconsistent with SwiftFormat, you can update those on your machine under Xcode > Preferences > Text Editing. You can also optionally install the SwiftFormat Xcode plugin and bind that to a custom key binding or to the file-save event.

## Contributing
Contributions to this project are welcome, encouraged, and compensated. For more details, see https://lbry.com/faq/contributing

## License
This project is MIT licensed. For the full license, see [LICENSE](LICENSE).

## Security
We take security seriously. Please contact security@lbry.com regarding any security issues. Our PGP key is [here](https://lbry.com/faq/gpg-key) if you need it.

## Contact
The primary contact for this project is [@akinwale](https://github.com/akinwale) (akinwale@lbry.com)
