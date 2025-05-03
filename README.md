<p align="center">
    <img src="storekitthekit.png" width="1000" alt="StoreKitTheKit"/>
</p>

![Swift](https://img.shields.io/badge/Swift-5.5-orange) 
![iOS](https://img.shields.io/badge/iOS-v15%2B-blue)
![macOS](https://img.shields.io/badge/macOS-v12%2B-lightgrey)
![tvOS](https://img.shields.io/badge/tvOS-v15%2B-purple)
![License](https://img.shields.io/badge/License-MIT-green)

# StoreKitTheKit

A lightweight wrapper for StoreKit2 that makes implementing in-app purchases simple.

## Features

1. **Fast Integration** - Set up StoreKit in minutes, not days
2. **Seamless Offline Support** - Robust local storage ensures purchases work even without internet
3. **Intelligent Connection Management** - Automatically handles transitions between online and offline states of the Store
4. **Focused Simplicity** - Currently only available for non-consumable IAPs (with consumables and subscriptions coming soon)
5. **Security** - Added Receipt Validation


## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/nicolaischneider/storekitthekit.git", from: "1.0.0")
]
```

### CocoaPods

Add the ollowing line to your `Podfile`:
```ruby
pod 'StoreKitTheKit'
```
Then run `pod install` and open your `.xcworkspace`.

## Setup

### 1. Register your items
```swift
PurchasableManager.shared.register(purchasableItems: [
    Purchasable(bundleId: "com.example.premium", type: .nonConsumable)
])
```

### 2. Initialize the store
```swift
await StoreKitTheKit.shared.begin()
```

## Purchase

### 3. Make purchases
```swift
let result = await StoreKitTheKit.shared.purchaseElement(element: premiumItem)
```

### 4. Check purchase status
```swift
let isPremium = StoreKitTheKit.shared.elementWasPurchased(element: premiumItem)
```

### 5. Restore purchases
```swift
await StoreKitTheKit.shared.restorePurchases()
```

## Price Formatting

```swift
// Get price for an item
let price = StoreKitTheKit.shared.getPriceFormatted(for: item)

// get total price of multiple items
let totalPrice = StoreKitTheKit.shared.getPriceFormatted(for: [item1, item2])

// Compare prices
let (savings, percentage) = StoreKitTheKit.shared.comparePrice(
    for: [item1, item2], with: item3
)
```

## Requirements
- iOS 15.0+
- Swift 5.5+
