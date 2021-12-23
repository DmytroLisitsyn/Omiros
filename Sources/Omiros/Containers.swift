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

public struct OmirosRelation<Entity: Omirable>: AnyOmirosRelation {

    public let key: String
    public let type: AnyOmirable.Type

    public init(_ key: Entity.OmirosKey) {
        self.key = key.stringValue
        self.type = Entity.self
    }

}

@propertyWrapper
public struct _OmirosField<Entity: Omirable, T: SQLiteType>: CustomDebugStringConvertible {

    public let key: Entity.OmirosKey
    public var wrappedValue: T

    public init(_ key: Entity.OmirosKey, initialValue: T = .init()) {
        self.key = key
        self.wrappedValue = initialValue
    }

    public mutating func fill(from container: OmirosOutput<Entity>) {
        wrappedValue = container.get(key)
    }

    public var debugDescription: String {
        return "\(wrappedValue)"
    }

}

public final class OmirosInput<Entity: Omirable> {

    var primaryKeys: Set<String> = []
    var content: [String: SQLiteType] = [:]
    var relations: [String: AnyOmirosRelation] = [:]
    var enclosed: [String: AnyOmirable] = [:]

    public func setPrimaryKey(_ key: Entity.OmirosKey) {
        primaryKeys.insert(key.stringValue)
    }

    public subscript<T: SQLiteType>(_ key: Entity.OmirosKey) -> T? {
        get { content[key.stringValue] as? T }
        set { content[key.stringValue] = newValue }
    }

    public func fill<T: SQLiteType>(from field: _OmirosField<Entity, T>) {
        content[field.key.stringValue] = field.wrappedValue
    }

    public func set<T: SQLiteType>(_ value: T, for key: Entity.OmirosKey) {
        content[key.stringValue] = value
    }

    public func set<T: AnyOmirable>(_ value: T) {
        enclosed[T.omirosName] = value
    }

    public func fill<T: SQLiteType, U: Omirable>(from field: _OmirosField<Entity, T>, as relation: OmirosRelation<U>) {
        content[field.key.stringValue] = field.wrappedValue
        relations[field.key.stringValue] = relation
    }

    public func set<T: SQLiteType, U: Omirable>(_ value: T, for key: Entity.OmirosKey, as relation: OmirosRelation<U>) {
        content[key.stringValue] = value
        relations[key.stringValue] = relation
    }

}

public final class OmirosOutput<Entity: Omirable> {

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

    public subscript<T: SQLiteType>(_ key: Entity.OmirosKey) -> T {
        return get(key)
    }

    public func get<T: SQLiteType>(_ key: Entity.OmirosKey) -> T {
        guard let index = indexPerColumnName[key.stringValue], let statement = statement else {
            return T.init()
        }

        return statement.column(at: index, type: T.self)
    }

    public func get<T: Omirable>(with options: OmirosQueryOptions<T>) -> T {
        do {
            guard let statement = statement else { throw SQLiteError() }

            return try .init(with: options, db: statement.database)
        } catch {
            return .init()
        }
    }

    public func get<T: Omirable>(with options: OmirosQueryOptions<T>) -> T? {
        do {
            guard let statement = statement else { throw SQLiteError() }

            return try .init(with: options, db: statement.database)
        } catch {
            return nil
        }
    }

    public func get<T: Omirable>(with options: OmirosQueryOptions<T>) -> [T] {
        do {
            guard let statement = statement else { throw SQLiteError() }

            return try .init(with: options, db: statement.database)
        } catch {
            return []
        }
    }

}
