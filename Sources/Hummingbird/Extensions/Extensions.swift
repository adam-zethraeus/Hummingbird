import Logging

/// Extend objects with additional member variables
///
/// If you have only one instance of a type to attach you can extend it to conform to `StorageKey`
/// ```
/// struct Object {
///     var extensions: Extensions<Object>
/// }
///
/// extension Object {
///     var extra: Extra? {
///         get { return extensions.get(\.extra) }
///         set { extensions.set(\.extra, value: newValue) }
///     }
/// }
/// ```
public struct HBExtensions<ParentObject> {
    public init() {
        self.items = [:]
    }

    public func get<Type>(_ key: KeyPath<ParentObject, Type>) -> Type? {
        self.items[key]?.value as? Type
    }

    public func get<Type>(_ key: KeyPath<ParentObject, Type>) -> Type {
        guard let value = items[key]?.value as? Type else { preconditionFailure("Cannot get extension without having set it") }
        return value
    }

    public mutating func getOrCreate<Type>(_ key: KeyPath<ParentObject, Type>, _ createCB: @autoclosure () -> Type) -> Type {
        guard let value = items[key]?.value as? Type else {
            self.set(key, value: createCB())
            return self.items[key]!.value as! Type
        }
        return value
    }

    public mutating func set<Type>(_ key: KeyPath<ParentObject, Type>, value: Type, shutdownCallback: ((Type) throws -> Void)? = nil) {
        if let item = items[key] {
            guard item.shutdown == nil else {
                preconditionFailure("Cannot replace items with shutdown functions")
            }
        }
        self.items[key] = .init(
            value: value,
            shutdown: shutdownCallback.map { callback in
                return { item in try callback(item as! Type) }
            }
        )
    }

    mutating func shutdown() throws {
        for item in self.items.values {
            try item.shutdown?(item.value)
        }
        self.items = [:]
    }

    struct Item {
        let value: Any
        let shutdown: ((Any) throws -> Void)?
    }

    var items: [PartialKeyPath<ParentObject>: Item]
}

/// Protocol for extensible classes
public protocol HBExtensible {
    var extensions: HBExtensions<Self> { get set }
}