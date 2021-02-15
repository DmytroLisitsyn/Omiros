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
    init(container: OmirosOutput)
    func fill(container: OmirosInput)
}

public final class OmirosInput {

    typealias Content = [String: SQLiteType]

    var content = Content()

    public func set<T: SQLiteType>(_ value: T, for key: String) {
        content[key] = value
    }

    public func fill<T: SQLiteType>(from field: OmirosField<T>) {
        content[field.key] = field.wrappedValue
    }

}

public final class OmirosOutput {

    private weak var statement: SQLite.Statement?
    private var indexPerColumnName: [String: Int32] = [:]

    init(_ statement: SQLite.Statement) {
        self.statement = statement

        let columns = (0..<statement.columnCount).map(statement.columnName)
        for (index, column) in columns.enumerated() {
            indexPerColumnName[column] = Int32(index)
        }
    }

    public func get<T: SQLiteType>(_ key: String) -> T {
        return get(T.self, for: key)
    }

    public func get<T: SQLiteType>(_ type: T.Type, for key: String) -> T {
        let index = indexPerColumnName[key]
        let value = index.flatMap { statement?.column(at: $0, type: T.self) }
        return value ?? T.default()
    }

}

@propertyWrapper
public struct OmirosField<T: SQLiteType>: CustomDebugStringConvertible {

    public let key: String

    public var wrappedValue: T

    public init(_ key: String, initialValue: T = .default()) {
        self.key = key
        self.wrappedValue = initialValue
    }

    public mutating func fill(from container: OmirosOutput) {
        wrappedValue = container.get(key)
    }

    public var debugDescription: String {
        return "\(wrappedValue)"
    }

}
