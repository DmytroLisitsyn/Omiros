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

public protocol Omirable: SQLiteType {

    associatedtype OmirosKey: CodingKey

    typealias OmirosField<T: SQLiteType> = _OmirosField<Self, T>

    init(container: OmirosOutput<Self>)
    func fill(container: OmirosInput<Self>)

}

@propertyWrapper
public struct _OmirosField<Entity: Omirable, Value: SQLiteType>: CustomDebugStringConvertible {

    public let key: String

    public var wrappedValue: Value

    public init(_ key: Entity.OmirosKey, initialValue: Value = .init()) {
        self.key = key.stringValue
        self.wrappedValue = initialValue
    }

    public mutating func fill<Entity>(from container: OmirosOutput<Entity>) {
        wrappedValue = container.get(Value.self, for: key)
    }

    public var debugDescription: String {
        return "\(wrappedValue)"
    }

}

public final class OmirosInput<Entity: Omirable> {

    var content: [String: SQLiteType] = [:]
    var relations: [String: AnyOmirosRelation] = [:]

    public subscript<Value: SQLiteType>(_ key: Entity.OmirosKey) -> Value? {
        get { content[key.stringValue] as? Value }
        set { content[key.stringValue] = newValue }
    }

    public func fill<Value: SQLiteType>(from field: _OmirosField<Entity, Value>) {
        content[field.key] = field.wrappedValue
    }

    public func set<Value: SQLiteType>(_ value: Value, for key: Entity.OmirosKey) {
        content[key.stringValue] = value
    }

    public func set<Value: SQLiteType, Related: Omirable>(_ value: Value, for key: Entity.OmirosKey, as relation: OmirosRelation<Related>) {
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

    public subscript<Value: SQLiteType>(_ key: Entity.OmirosKey) -> Value {
        return get(key)
    }

    public func get<Value: SQLiteType>(_ key: Entity.OmirosKey) -> Value {
        return get(Value.self, for: key)
    }

    public func get<Value: SQLiteType>(_ type: Value.Type, for key: Entity.OmirosKey) -> Value {
        return get(type, for: key.stringValue)
    }

    func get<Value: SQLiteType>(_ type: Value.Type, for key: String) -> Value {
        if let index = indexPerColumnName[key], let statement = statement {
            return statement.column(at: index, type: Value.self)
        } else {
            return Value.init()
        }
    }

}
