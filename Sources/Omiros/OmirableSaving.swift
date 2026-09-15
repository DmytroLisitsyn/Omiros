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

public struct OmirableSaving<T: Omirable> {

    var primaryKeys: Set<String> = []
    var indices: [(name: String, keys: [String])] = []
    var columns: [String: SQLiteValue] = [:]
    var relations: [String: (typeString: String, key: String)] = [:]
    var enclosed: [AnyEnclosedOmirableList] = []

    public init(_ entity: T) {
        entity.fill(container: &self)
    }

    public mutating func setPrimaryKey(_ key: T.OmirableKey) {
        primaryKeys.insert(key.stringValue)
    }

    public mutating func setIndex(_ keys: [T.OmirableKey]) {
        let keyStrings = keys.map(\.stringValue)
        let name = "\(T.omirableName)_\(keyStrings.joined(separator: "_"))"
        indices.append((name, keyStrings))
    }

    public mutating func set<U: SQLiteValue>(_ value: U, for key: T.OmirableKey) {
        columns[key.stringValue] = value
    }

    public mutating func set<U: SQLiteValue, V: Omirable>(_ value: U, for key: T.OmirableKey, relatedTo relatedType: V.Type = V.self, key relatedKey: V.OmirableKey) {
        columns[key.stringValue] = value
        relations[key.stringValue] = (V.omirableName, relatedKey.stringValue)
    }

    public mutating func set<U: Omirable>(_ entity: U, where condition: OmirosQuery<U>.Condition? = nil) {
        set([entity], where: condition)
    }

    public mutating func set<U: Omirable>(_ entities: [U], where condition: OmirosQuery<U>.Condition? = nil) {
        enclosed.append(EnclosedOmirableList(entities: entities, condition: condition))
    }

}

// MARK: - EnclosedOmirableList

protocol AnyEnclosedOmirableList {
    var omirableName: String { get }
    func save(in db: SQLite) throws
    mutating func append(_ other: AnyEnclosedOmirableList)
}

struct EnclosedOmirableList<T: Omirable>: AnyEnclosedOmirableList {

    var omirableName: String {
        return T.omirableName
    }

    var entities: [T]
    var condition: OmirosQuery<T>.Condition?

    func save(in db: SQLite) throws {
        if let condition = condition {
            try T.delete(in: db, with: OmirosQuery(where: condition))
        }
        try entities.save(in: db)
    }

    mutating func append(_ other: AnyEnclosedOmirableList) {
        guard let other = other as? EnclosedOmirableList<T> else { return }

        entities.append(contentsOf: other.entities)

        if let otherCondition = other.condition {
            var conditions: [OmirosQuery<T>.Condition]
            switch condition {
            case .any(let existingConditions):
                conditions = existingConditions + [otherCondition]
            case .none:
                conditions = [otherCondition]
            case .some(let existingCondition):
                conditions = [existingCondition, otherCondition]
            }
            condition = .any(conditions)
        }
    }

}
