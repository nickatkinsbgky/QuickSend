# QuickSend

Cross-platform app similar to Apple AirDrop for quickly sending and receiving files between iPhone, Android, and PCs using Wi-Fi or Bluetooth.

## Goal
Enable fast, private, peer-to-peer file transfer over local networks (Wi-Fi) or nearby Bluetooth without cloud intermediaries, accounts, or subscriptions.

## Tech Stack
- **Flutter** for UI and cross-platform code (iOS, Android, Windows, macOS, Linux)
- Local network discovery via mDNS / NSD (Wi-Fi)
- Bluetooth Low Energy (BLE) discovery and transfer via `flutter_blue_plus`
- Direct transfer over local HTTP (Wi-Fi) or BLE characteristics (Bluetooth)
- Planned: Rust core for high-performance networking (via flutter_rust_bridge) in later phases

## Architecture Overview
```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── device.dart           # Nearby device model
│   └── transfer.dart         # File transfer session model
├── services/
│   ├── discovery_service.dart # Wi-Fi (mDNS) + Bluetooth discovery
│   └── transfer_service.dart  # File send/receive (Wi-Fi HTTP + Bluetooth BLE)
├── screens/
│   ├── home_screen.dart      # Nearby devices + received files list
│   └── transfer_screen.dart  # Send progress UI
└── widgets/
    ├── device_card.dart      # Reusable device UI component
    └── file_thumbnail.dart   # Image thumbnail preview
```

## Features
- [x] Wi-Fi mDNS device discovery and registration (phones, tablets, and PCs)
- [x] Bluetooth Low Energy (BLE) scanning for nearby devices
- [x] Bluetooth file send with filename header + EOF marker
- [x] Bluetooth receive protocol (parses FILENAME: header, buffers data, saves on EOF)
- [x] Home screen listing nearby devices with platform identification
- [x] Platform permissions for local network and Bluetooth discovery
- [x] Multi-file selection and sequential send
- [x] Receive and save incoming files to app documents directory (Wi-Fi)
- [x] Accept/reject dialog for incoming transfers
- [x] Progress indication during send
- [x] Simple list of received files
- [x] Small image thumbnails for files being transferred
- [ ] Full production Bluetooth GATT server advertising (platform-specific)
- [ ] Optional QR code pairing for devices not on the same network
- [ ] End-to-end encryption for transfers
- [ ] Folder support

## Getting Started
```bash
flutter pub get
flutter run
```

**Platform permissions (already added):**
- **Android** (`android/app/src/main/AndroidManifest.xml`): Network + Bluetooth permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, etc.)
- **iOS** (`ios/Runner/Info.plist`): `NSLocalNetworkUsageDescription`, `NSBonjourServices`, and `NSBluetoothAlwaysUsageDescription`

> Note: If you clone this repo, run `flutter create .` inside the project directory to generate the remaining platform scaffolding (build.gradle, Xcode project, etc.), then the permission files will be in place.

### Bluetooth Protocol
Transfers over Bluetooth use this simple protocol:
1. `FILENAME:original-name.ext\n`
2. File data in chunks (~180 bytes)
3. `EOF`

The send side writes these in order. The receive side parses the header, buffers the data, and saves the file with the original name when `EOF` arrives.

You can select multiple files at once. They are sent sequentially with progress shown for each file.

Received files are saved to the app's documents directory. A list of received files appears at the bottom of the home screen. Image files show a small thumbnail preview on the transfer screen and in the accept dialog.

## Inspiration
LocalSend, BIShare, and similar open-source projects.

## License
MIT (to be added)
