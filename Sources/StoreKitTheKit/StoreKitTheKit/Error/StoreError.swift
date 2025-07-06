import Foundation

enum StoreError: Error {
    case productNotFound
    case purchaseNotVerifed
    case subscriptionExpired
    case subscriptionNotFound
    case subscriptionStatusUnavailable
}
