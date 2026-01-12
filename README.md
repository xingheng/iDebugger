# iDebugger

An iOS debugging utility library written in Objective-C, distributed via Swift Package Manager and CocoaPods.

## Installation

### CocoaPods

iDebugger is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'iDebugger'
```

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/iDebugger.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. Go to File → Add Packages...
2. Enter the repository URL: `https://github.com/yourusername/iDebugger.git`
3. Select the version you want to use

## Building

Since this is an iOS-only library that depends on UIKit, you need to build it specifically for iOS:

```bash
# Build for iOS
swift build --sdk $(xcrun --sdk iphoneos --show-sdk-path) --triple arm64-apple-ios13.0
```

**Note:** This package currently does not include automated tests. Testing should be performed manually or through your application's test suite.

## Requirements

- iOS 13.0+
- Xcode 14.0+
- Swift 6.0+

## Usage

```objc
#import <iDebugger/iDebugger.h>

// Add a debug action
[DebugAction add:@"Clear Cache" action:^{
    // Your debug code here
}];

// Show debug window
[[DebugWindow sharedInstance] show];
```

## Author

Will Han, xingheng907@hotmail.com

## License

iDebugger is available under the MIT license. See the LICENSE file for more info.
