//
//  WeakDictionary.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Foundation

// NSMapTable, but the keys can be any Hashable (if they're
// objects, they are held strongly).
struct WeakDictionary<Key: Hashable, Value: AnyObject> {
    struct WeakRef {
        weak var value: Value?
    }

    private var storage: [Key: WeakRef]

    init() {
        storage = [:]
    }

    subscript(key: Key) -> Value? {
        mutating get {
            if let ref = storage[key] {
                return ref.value
            } else {
                storage.removeValue(forKey: key)
                return nil
            }
        }

        set {
            if let newValue = newValue {
                storage[key] = WeakRef(value: newValue)
            } else {
                storage.removeValue(forKey: key)
            }
        }
    }
}
