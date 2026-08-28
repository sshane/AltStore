> ### Fork note — macOS 26/27 support
>
> This branch (`macos-26-27`) is [AltStore Classic](https://github.com/altstoreio/AltStore/tree/classic)
> with the minimum changes needed to build and sign in on current macOS. Upstream's issue tracker
> is not currently maintained ([#1610](https://github.com/altstoreio/AltStore/issues/1610)), so
> these fixes live here.
>
> **What's fixed**
>
> - **Anisette on macOS 26+.** `adid` no longer generates one-time passwords for unentitled apps,
>   so AOSKit returns an empty dictionary and AltServer can't produce anisette itself
>   ([#1751](https://github.com/altstoreio/AltStore/issues/1751)). Includes jslay88's server support
>   from [#1770](https://github.com/altstoreio/AltStore/pull/1770); set an anisette server with
>   `ALTSERVER_ANISETTE_SERVER` or the `AnisetteServerURL` default.
> - **The two-factor loop.** AltSign presented an Xcode 11.2 (2019) client identity that Apple no
>   longer grants HSA2 trust to: a code is accepted with HTTP 200, then the next login is challenged
>   again ([#1737](https://github.com/altstoreio/AltStore/issues/1737),
>   [#1772](https://github.com/altstoreio/AltStore/issues/1772)). AltServer now derives the identity
>   from the running Mac; AltStore uses a fixed one whose OS and Xcode versions agree.
> - **Building with Xcode 27.** The vendored `libcurl.a` predates 8-byte alignment and can no longer
>   be linked, `-ld_classic` is gone, and `AltSign-Dynamic` couldn't resolve the `alt_cc*` wrappers.
>
> **Building**
>
> ```sh
> git submodule update --init --recursive
> Scripts/fetch-idevice-xcframework.sh
>
> xcodebuild -workspace AltStore.xcworkspace -scheme AltStore \
>   -configuration Release -destination 'generic/platform=iOS' \
>   IPHONEOS_DEPLOYMENT_TARGET=17.4
>
> xcodebuild -workspace AltStore.xcworkspace -scheme AltServer \
>   -configuration Release MACOSX_DEPLOYMENT_TARGET=13.0
> ```
>
> `IPHONEOS_DEPLOYMENT_TARGET` is required because the vendored pods and Roxas still declare
> 12.0–14.0. `IDevice.xcframework` is built from Rust and isn't committed, so the script fetches
> the prebuilt one.
>
> **For on-device sideloading**, AltStore also needs a pairing file (Settings → *Configure Remote
> AltServer…*, which requires AltServer over USB once) and [StosVPN](https://apps.apple.com/app/id6744003051)
> running — it provides the `10.7.0.1` loopback AltStore uses to reach the device.
>
> **Known limitation:** the OTA patch path is compiled out (`NO_FRAGMENTZIP`) because fragmentzip
> links against the unusable `libcurl.a`.

# AltStore

> AltStore is an alternative app store for non-jailbroken iOS devices. 

[![Swift Version](https://img.shields.io/badge/swift-5.0-orange.svg)](https://swift.org/)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

AltStore is an iOS application that allows you to sideload other apps (.ipa files) onto your iOS device with just your Apple ID. AltStore resigns apps with your personal development certificate and sends them to a desktop app, AltServer, which installs the resigned apps back to your device using iTunes WiFi sync. To prevent apps from expiring, AltStore will also periodically refresh your apps in the background when on the same WiFi as AltServer.

For the initial release, I focused on building a solid foundation for distributing my own apps — primarily Delta, [my all-in-one emulator for iOS](https://github.com/rileytestut/Delta). Now that Delta has been released, however, I'm beginning work on adding support for *anyone* to list and distribute their apps through AltStore (contributions welcome! 🙂).

## Features
- Installs apps over WiFi using AltServer
- Resigns and installs any app with your Apple ID
- Refreshes apps periodically in the background to prevent them from expiring (when on same WiFi as AltServer)
- Handles app updates directly through AltStore 

## Minimum Project Requirements
- Xcode 15
- Swift 5.9
- iOS 14.0 (AltStore)
- macOS 11.0 (AltServer)

## Project Overview

### AltStore
AltStore is a just regular, sandboxed iOS application. The AltStore app target contains the vast majority of AltStore's functionality, including all the logic for downloading and updating apps through AltStore. AltStore makes heavy use of standard iOS frameworks and technologies most iOS developers are familiar with, such as:
* Core Data
* Storyboards/Nibs
* Auto Layout
* Background App Refresh
* Network.framework (new in iOS 12)

### AltServer
AltServer is also just a regular, sandboxed macOS application. AltServer is significantly less complex than AltStore though, and for that reason consists of only a handful of files.

### AltKit
AltKit is a shared framework that includes common code between AltStore and AltServer.

### AltSign
AltSign is my internal framework used by both AltStore and AltServer to communicate with Apple's servers and resign apps. For more info, check the [AltSign repo](https://github.com/rileytestut/altsign).

### Roxas
Roxas is my internal framework used across all my iOS projects, developed to simplify a variety of common tasks used in iOS development. For more info, check the [Roxas repo](https://github.com/rileytestut/roxas).

## Compilation Instructions
AltStore and AltServer are both fairly straightforward to compile and run if you're already an iOS or macOS developer. To compile AltStore and/or AltServer:

1. Clone the repository 
	``` 
	git clone https://github.com/rileytestut/AltStore.git
	```
2. Update submodules: 
	```
	cd AltStore 
	git submodule update --init --recursive
	```
3. Open `AltStore.xcworkspace` and select the AltStore project in the project navigator. On the `Signing & Capabilities` tab, change the team from `Yvette Testut` to your own account.
4. **(AltStore only)** Change the value for `ALTDeviceID` in the Info.plist to your device's UDID. Normally, AltServer embeds the device's UDID in AltStore's Info.plist during installation. When running through Xcode you'll need to set the value yourself or else AltStore won't resign (or even install) apps for the proper device.
5. **(AltStore only)** Change the value for `ALTServerID` in the Info.plist to your AltServer's serverID. This is embedded by AltServer during installation to help AltStore distinguish between multiple AltServers on the same network, and you can find this by using a Bonjour browsing application and noting the serverID advertised by AltServer. This isn't strictly necessary, because if AltStore can't find the AltServer with the embedded serverID it still falls back to trying another AltServer. However, this will help in cases where there are multiple AltServers running (plus the error messages are more helpful).
6. Build + run app! 🎉

## Licensing

Due to the licensing of some dependencies used by AltStore, I have no choice but to distribute AltStore under the **AGPLv3 license**. That being said, my goal for AltStore is for it to be an open source project *anyone* can use without restrictions, so I explicitly give permission for anyone to use, modify, and distribute all *my* original code for this project in any form, with or without attribution, without fear of legal consequences (dependencies remain under their original licenses, however).

## Contact Me

* Email: riley@altstore.io
* Mastodon (Preferred): [@rileytestut@mastodon.social](https://mastodon.social/@rileytestut)
* Twitter (Less active nowadays): [@rileytestut](https://twitter.com/rileytestut)

Questions about AltStore in general? Make sure to read the FAQ at https://altstore.io/faq/
