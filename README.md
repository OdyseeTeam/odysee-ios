# Odysee iOS
[![GitHub license](https://img.shields.io/github/license/OdyseeTeam/odysee-ios?style=for-the-badge)](https://github.com/OdyseeTeam/odysee-ios/blob/master/LICENSE)

The Odysee iOS app with wallet functionality.

## Installation
The minimum supported iOS version is 13.0. You can install the app from the [Apple App Store](https://apps.apple.com/us/app/odysee/id1539444143). You can also obtain early access releases by joining the [TestFlight beta program](https://testflight.apple.com/join/Nms3EXZ9). 

## Usage
The app can be launched by opening **Odysee** from the app list on your device. 

## Running from Source
Clone the repository and open the project in XCode. Click the Build and run current scheme button to build the project and launch the app in one of the available simulators or a connected device.

### Setup Firebase
We use Firebase for analytics calls throughout the codebase. You'll need the `Odysee/GoogleService-Info.plist` file to exist for the Xcode project to compile. However, this file is in `.gitignore`, so you’ll need your own local copy after you clone this repo. Create it from the provided sample by running this command in the root directory:

```
cp ./Odysee/GoogleService-Info.plist.sample ./Odysee/GoogleService-Info.plist
```

## Style and Formatting
We use [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) to enforce a consistent format for all Swift code. You can see our custom configuration in this repo’s `.swiftformat` file.

`swiftformat . --lint` must pass before merging to `master`. To run it locally, first install it using [Mint](https://github.com/yonaskolb/Mint) and `mint bootstrap --link`, and then run `swiftformat .` which will automatically format all of your Swift code. If any of your default Xcode text editing preferences are inconsistent with SwiftFormat, you can update those on your machine under Xcode > Preferences > Text Editing. You can also optionally install the SwiftFormat Xcode plugin and bind that to a custom key binding or to the file-save event.

## Contributing
We :heart: contributions from everyone and contributions to this project are encouraged, and compensated. We welcome [bug reports](https://github.com/OdyseeTeam/odysee-ios/issues/), [bug fixes](https://github.com/OdyseeTeam/odysee-ios/pulls) and feedback is always appreciated. For more details, see [CONTRIBUTING.md](CONTRIBUTING.md).

## [![contributions welcome](https://img.shields.io/github/issues/OdyseeTeam/odysee-ios?style=for-the-badge&color=informational)](https://github.com/OdyseeTeam/odysee-ios/issues) [![GitHub contributors](https://img.shields.io/github/contributors/OdyseeTeam/odysee-ios?style=for-the-badge)](https://gitHub.com/OdyseeTeam/odysee-ios/graphs/contributors/)

## License
This project is MIT licensed. For the full license, see [LICENSE](LICENSE).

## Security
We take security seriously. Please contact security@odysee.com.

## Contact
The primary contact for this project is [@akinwale](https://github.com/akinwale) (akinwale.ariwodola@odysee.com)
