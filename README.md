# StoreKitTheKit

A lightweight wrapper for StoreKit2 that makes implementing in-app purchases simple.

## Features

1. **Fast Integration** - Set up StoreKit in minutes, not days
2. **Seamless Offline Support** - Robust local storage ensures purchases work even without internet
3. **Intelligent Connection Management** - Automatically handles transitions between online and offline states of the Store
4. **Focused Simplicity** - Currently only available for non-consumable IAPs (with more coming soon)

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/StoreKitTheKit.git", from: "1.0.0")
]
```

## Quick Start

### 1. Register your items
```swift
PurchasableManager.shared.register(purchasableItems: [
    Purchasable(bundleId: "com.example.premium", type: .nonConsumable)
])
```

### 2. Initialize the store
```swift
await PurchasableManager.shared.begin()
```

### 3. Make purchases
```swift
let result = await PurchasableManager.shared.purchaseElement(element: premiumItem)
```

### 4. Check purchase status
```swift
let isPremium = PurchasableManager.shared.elementWasPurchased(element: premiumItem)
```

### 5. Restore purchases
```swift
await PurchasableManager.shared.restorePurchases()
```

## Price Formatting

```swift
// Get price for an item
let price = PurchasableManager.shared.getPriceFormatted(for: item)

// Compare prices
let (savings, percentage) = PurchasableManager.shared.comparePrice(
    for: [item1, item2], with: bundleItem
)
```

## Requirements
- iOS 15.0+
- Swift 5.5+
