# ZTNav Documentation

## Introduction
`ZTNav` is a lightweight and flexible navigation management system for iOS applications that abstracts away direct URL handling. It provides a way to manage navigation between view controllers and logic handlers using a unified schema. By using custom URL schemes and middleware, `ZTNav` can streamline navigation flows without the native code directly interacting with web URLs.

### Key Features
- **Path-based Navigation**: Supports native and web URL navigation using custom schemas.
- **View Controller and Logic Handlers**: Handles both view controllers and logic flows with reusable handlers.
- **Middleware System**: Allows for processing and modifying paths and parameters before navigation.
- **Error Handling**: Provides mechanisms for handling navigation failures.

## Requirements
- iOS 13.0+
- Swift 5.0+

## Installation

### Swift Package Manager
You can also use Swift Package Manager to integrate ZTNav into your Xcode project. Simply add it as a dependency in your `Package.swift` file:

```swift
dependencies: [
.package(url: "https://github.com/willonboy/ZTNav.git", from: "0.1.0")
]
```

## Usage

```swift

```

## License
ZTNav is available under the MPL-2.0 license. See the [LICENSE](LICENSE) file for more information.
