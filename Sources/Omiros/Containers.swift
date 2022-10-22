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

public final class OmirosInput<T: Omirable> {

    var primaryKeys: Set<String> = []
    var content: [String: SQLiteType] = [:]
    var relations: [String: AnyOmirosRelation] = [:]
    var enclosed: [String: AnyOmirable] = [:]

    public func setPrimaryKey(_ key: T.OmirosKey) {
        primaryKeys.insert(key.stringValue)
    }

    public func set<U: SQLiteType>(_ value: U, for key: T.OmirosKey) {
        content[key.stringValue] = value
    }

    public func set<U: AnyOmirable>(_ value: U) {
        enclosed[U.omirosName] = value
    }

    public func set<U: SQLiteType, V: Omirable>(_ value: U, for key: T.OmirosKey, as relation: OmirosRelation<V>) {
        content[key.stringValue] = value
        relations[key.stringValue] = relation
    }

}

public final class OmirosOutput<T: Omirable> {

    private weak var statement: SQLite.Statement?
    private var indexPerColumnName: [String: Int32] = [:]

    init(_ statement: SQLite.Statement?) {
        self.statement = statement

        guard let statement = statement else { return }

        let columns = (0..<statement.columnCount).map(statement.columnName)

        for (index, column) in columns.enumerated() {
            indexPerColumnName[column] = Int32(index)
        }
    }

    public func get<U: SQLiteType>(_ key: T.OmirosKey) throws -> U {
        guard let index = indexPerColumnName[key.stringValue], let statement = statement else {
            throw SQLiteError()
        }

        return statement.column(at: index, type: U.self)
    }

    public func get<U: Omirable>(with options: OmirosQueryOptions<U>) throws -> U? {
        guard let statement = statement else { throw SQLiteError() }

        return try .init(with: options, db: statement.database)
    }

    public func get<U: Omirable>(with options: OmirosQueryOptions<U>) throws -> [U] {
        guard let statement = statement else { throw SQLiteError() }

        return try .init(with: options, db: statement.database) ?? []
    }

}
