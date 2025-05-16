import SwiftUI

/// Extends `Binding` for optional values (`ExpressibleByNilLiteral`).
extension Binding where Value: ExpressibleByNilLiteral {
    /// Creates a non-optional `Binding` from an optional `Binding`.
    ///
    /// This is useful for SwiftUI views like `Picker` that often work more easily with non-optional bindings.
    /// When the optional binding's value is `nil`, the `get` returns the provided `defaultValue`.
    /// When setting a value, it's assigned directly to the original optional binding.
    ///
    /// - Parameter defaultValue: The value to use when the wrapped optional value is `nil`.
    /// - Returns: A `Binding` to a non-optional value `T`.
    func toUnwrapped<T>(defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}