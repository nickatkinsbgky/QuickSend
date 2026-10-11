# QuickSend

Cross-platform app similar to Apple AirDrop for quickly sending and receiving files between iPhone and Android (and other platforms).

## Goal
Enable fast, private, peer-to-peer file transfer over local networks without cloud intermediaries, accounts, or subscriptions.

## Tech Stack
- **Flutter** for UI and cross-platform code (iOS, Android, and later desktop)
- Local network discovery via mDNS / NSD (Bonjour on iOS, Network Service Discovery on Android) using the `nsd` package
- Direct transfer over local HTTP (basic implementation started)
- Planned: Rust core for high-performance networking (via flutter_rust_bridge) in later phases

## Architecture Overview
```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── device.dart           # Nearby device model
│   └── transfer.dart         # File transfer session model
├── services/
│   ├── discovery_service.dart # Device discovery (mDNS) - basic implementation
│   └── transfer_service.dart  # File send/receive logic - HTTP skeleton
├── screens/
│   ├── home_screen.dart      # Nearby devices list
│   └── transfer_screen.dart  # Progress & confirmation UI
└── widgets/
    └── device_card.dart      # Reusable device UI component
```

## Features
- [x] Basic mDNS device discovery and registration
- [x] Home screen listing nearby devices
- [x] Platform permissions for local network discovery
- [x] File picker and basic one-tap send flow
- [ ] Receive and accept/reject incoming transfers
- [ ] Progress indication and transfer history
- [ ] Optional QR code pairing for devices not on the same network
- [ ] End-to-end encryption for transfers
- [ ] Support for multiple files and folders

## Getting Started
```bash
flutter pub get
flutter run
```

**Platform permissions (already added):**
- **Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`
- **iOS** (`ios/Runner/Info.plist`): `NSLocalNetworkUsageDescription` and `NSBonjourServices` for `_quicksend._tcp`

> Note: If you clone this repo, run `flutter create .` inside the project directory to generate the remaining platform scaffolding (build.gradle, Xcode project, etc.), then the permission files will be in place.

## Inspiration
LocalSend, BIShare, and similar open-source projects.

## License
MIT (to be added)
