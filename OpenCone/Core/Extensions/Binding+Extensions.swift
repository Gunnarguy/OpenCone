import SwiftUI

extension Binding where Value: ExpressibleByNilLiteral {
    func toUnwrapped<T>(defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
