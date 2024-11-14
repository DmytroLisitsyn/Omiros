//
//  Omiros
//
//  Copyright (C) 2021 Dmytro Lisitsyn
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

public struct OmirosSaving<T: Omirable> {

    var primaryKeys: Set<String> = []
    var indices: [(name: String, keys: [String])] = []
    var columns: [String: SQLiteType] = [:]
    var relations: [String: (typeString: String, key: String)] = [:]
    var enclosed: [AnyEnclosedOmirableList] = []

    public mutating func setPrimaryKey(_ key: T.OmirableKey) {
        primaryKeys.insert(key.stringValue)
    }

    public mutating func setIndex(_ keys: [T.OmirableKey]) {
        let keyStrings = keys.map(\.stringValue)
        let name = "\(T.omirableName)_\(keyStrings.joined(separator: "_"))"
        indices.append((name, keyStrings))
    }

    public mutating func set<U: SQLiteType>(_ value: U, for key: T.OmirableKey) {
        columns[key.stringValue] = value
    }

    public mutating func set<U: SQLiteType, V: Omirable>(_ value: U, for key: T.OmirableKey, relatedTo relatedType: V.Type = V.self, key relatedKey: V.OmirableKey) {
        columns[key.stringValue] = value
        relations[key.stringValue] = (V.omirableName, relatedKey.stringValue)
    }

    public mutating func set<U: Omirable>(_ entity: U, with options: OmirosQueryOptions<U>? = nil) {
        set([entity], with: options)
    }

    public mutating func set<U: Omirable>(_ entities: [U], with options: OmirosQueryOptions<U>? = nil) {
        enclosed.append(EnclosedOmirableList(entities: entities, options: options))
    }

}

protocol AnyEnclosedOmirableList {
    func save(in db: SQLite) throws
}

struct EnclosedOmirableList<T: Omirable>: AnyEnclosedOmirableList {

    let entities: [T]
    let options: OmirosQueryOptions<T>?

    func save(in db: SQLite) throws {
        if let options = options {
            try T.delete(in: db, with: options)
        }

        try entities.save(in: db)
    }

}
