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

public protocol AnyOmirosRelation {
    var key: String { get }
    var type: AnyOmirable.Type { get }
}

public struct OmirosRelation<T: Omirable>: AnyOmirosRelation {

    public let key: String
    public let type: AnyOmirable.Type

    public init(_ key: T.OmirosKey) {
        self.key = key.stringValue
        self.type = T.self
    }

}

public struct OmirosInput<T: Omirable> {

    var primaryKeys: Set<String> = []
    var indices: [(name: String, keys: [String])] = []
    var content: [String: SQLiteType] = [:]
    var relations: [String: AnyOmirosRelation] = [:]
    var enclosed: [String: [AnyOmirable]] = [:]

    public mutating func setPrimaryKey(_ key: T.OmirosKey) {
        primaryKeys.insert(key.stringValue)
    }

    public mutating func setIndex(_ keys: [T.OmirosKey]) {
        let keys = keys.map(\.stringValue)
        let name = "omiros_\(keys.joined(separator: "_"))"
        indices.append((name, keys))
    }

    public mutating func set<U: SQLiteType>(_ value: U, for key: T.OmirosKey) {
        content[key.stringValue] = value
    }

    public mutating func set<U: SQLiteType, V: Omirable>(_ value: U, for key: T.OmirosKey, as relation: OmirosRelation<V>) {
        content[key.stringValue] = value
        relations[key.stringValue] = relation
    }

    public mutating func set<U: AnyOmirable>(_ value: U) {
        enclosed[U.omirosName, default: []].append(value)
    }

}

public struct OmirosOutput<T: Omirable> {

    private weak var statement: SQLite.Statement?
    private var indexForColumnName: [String: Int32] = [:]

    init(_ statement: SQLite.Statement) {
        self.statement = statement

        for columnIndex in 0..<statement.columnCount {
            let columnName = statement.columnName(at: columnIndex)
            indexForColumnName[columnName] = Int32(columnIndex)
        }
    }

    public func get<U: SQLiteType>(_ valueType: U.Type = U.self, for key: T.OmirosKey) throws -> U {
        guard let statement = statement else {
            throw OmirosError.unavailableSQLiteStatement
        }

        guard let index = indexForColumnName[key.stringValue] else {
            throw OmirosError.missingColumnIndex
        }

        return statement.column(at: index, type: valueType)
    }

    public func get<U: Omirable>(_ valueType: U.Type = U.self, with options: OmirosQueryOptions<U>) throws -> U? {
        guard let statement = statement else {
            throw OmirosError.unavailableSQLiteStatement
        }

        return try valueType.init(in: statement.database, options: options)
    }

    public func get<U: Omirable>(_ valueType: [U].Type = [U].self, with options: OmirosQueryOptions<U>) throws -> [U] {
        guard let statement = statement else {
            throw OmirosError.unavailableSQLiteStatement
        }
        
        return try valueType.init(in: statement.database, options: options) ?? []
    }

}
