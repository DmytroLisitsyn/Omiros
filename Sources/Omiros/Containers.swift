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

@propertyWrapper
public struct _OmirosField<T: Omirable, U: SQLiteType>: CustomDebugStringConvertible {

    public let key: T.OmirosKey
    public var wrappedValue: U

    public init(_ key: T.OmirosKey, initialValue: U = .init()) {
        self.key = key
        self.wrappedValue = initialValue
    }

    public mutating func fill(from container: OmirosOutput<T>) {
        wrappedValue = container.get(key)
    }

    public var debugDescription: String {
        return "\(wrappedValue)"
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

    public subscript<U: SQLiteType>(_ key: T.OmirosKey) -> U? {
        get { content[key.stringValue] as? U }
        set { content[key.stringValue] = newValue }
    }

    public func fill<U: SQLiteType>(from field: _OmirosField<T, U>) {
        content[field.key.stringValue] = field.wrappedValue
    }

    public func set<U: SQLiteType>(_ value: U, for key: T.OmirosKey) {
        content[key.stringValue] = value
    }

    public func set<U: AnyOmirable>(_ value: U) {
        enclosed[U.omirosName] = value
    }

    public func fill<U: SQLiteType, V: Omirable>(from field: _OmirosField<T, U>, as relation: OmirosRelation<V>) {
        content[field.key.stringValue] = field.wrappedValue
        relations[field.key.stringValue] = relation
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

    public subscript<U: SQLiteType>(_ key: T.OmirosKey) -> U {
        return get(key)
    }

    public func get<U: SQLiteType>(_ key: T.OmirosKey) -> U {
        guard let index = indexPerColumnName[key.stringValue], let statement = statement else {
            return U.init()
        }

        return statement.column(at: index, type: U.self)
    }

    public func get<U: Omirable>(with options: OmirosQueryOptions<U>) -> U {
        do {
            guard let statement = statement else { throw SQLiteError() }

            return try .init(with: options, db: statement.database)
        } catch {
            return .init()
        }
    }

    public func get<U: Omirable>(with options: OmirosQueryOptions<U>) -> U? {
        do {
            guard let statement = statement else { throw SQLiteError() }

            return try .init(with: options, db: statement.database)
        } catch {
            return nil
        }
    }

    public func get<U: Omirable>(with options: OmirosQueryOptions<U>) -> [U] {
        do {
            guard let statement = statement else { throw SQLiteError() }

            return try .init(with: options, db: statement.database)
        } catch {
            return []
        }
    }

}
