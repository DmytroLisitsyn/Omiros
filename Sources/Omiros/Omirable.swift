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

public protocol Omirable {

    associatedtype OmirosKey: CodingKey

    typealias OmirosField<T: SQLiteType> = AnyOmirosField<Self, T>

    init(container: OmirosOutput<Self>)
    func fill(container: OmirosInput<Self>)

}

@propertyWrapper
public struct AnyOmirosField<Entity: Omirable, Value: SQLiteType>: CustomDebugStringConvertible {

    public let key: String

    public var wrappedValue: Value

    public init(_ key: Entity.OmirosKey, initialValue: Value = .default()) {
        self.key = key.stringValue
        self.wrappedValue = initialValue
    }

    public mutating func fill<Entity>(from container: OmirosOutput<Entity>) {
        wrappedValue = container.get(key)
    }

    public var debugDescription: String {
        return "\(wrappedValue)"
    }

}

public final class OmirosInput<Entity: Omirable> {

    typealias Content = [String: SQLiteType]

    var content = Content()

    public func fill<Value: SQLiteType>(from field: AnyOmirosField<Entity, Value>) {
        content[field.key] = field.wrappedValue
    }

    public func set<Value: SQLiteType>(_ value: Value, for key: Entity.OmirosKey) {
        content[key.stringValue] = value
    }

}

public final class OmirosOutput<Entity: Omirable> {

    private weak var statement: SQLite.Statement?
    private var indexPerColumnName: [String: Int32] = [:]

    init(_ statement: SQLite.Statement) {
        self.statement = statement

        let columns = (0..<statement.columnCount).map(statement.columnName)
        for (index, column) in columns.enumerated() {
            indexPerColumnName[column] = Int32(index)
        }
    }

    public func get<Value: SQLiteType>(_ key: Entity.OmirosKey) -> Value {
        return get(Value.self, for: key)
    }

    public func get<Value: SQLiteType>(_ type: Value.Type, for key: Entity.OmirosKey) -> Value {
        return get(type, for: key.stringValue)
    }

    func get<Value: SQLiteType>(_ key: String) -> Value {
        return get(Value.self, for: key)
    }

    func get<Value: SQLiteType>(_ type: Value.Type, for key: String) -> Value {
        let index = indexPerColumnName[key]
        let value = index.flatMap { statement?.column(at: $0, type: Value.self) }
        return value ?? Value.default()
    }

}
