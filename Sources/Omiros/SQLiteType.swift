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
import SQLite3

public protocol SQLiteType {

    static var sqLiteName: String { get }
    var sqLiteValue: String { get }

    init()
    func bind(at index: Int32, statement: SQLite.Statement) -> Int32
    static func column(at index: Int32, statement: SQLite.Statement) -> Self

}

extension Optional: SQLiteType where Wrapped: SQLiteType {

    public static var sqLiteName: String {
        return "NULL"
    }

    public var sqLiteValue: String {
        return "NULL"
    }

    public init() {
        self = nil
    }

    public func bind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        switch self {
        case .some(let value):
            return value.bind(at: index, statement: statement)
        case .none:
            return sqlite3_bind_null(statement.pointer, index)
        }
    }

    public static func column(at index: Int32, statement: SQLite.Statement) -> Wrapped? {
        if sqlite3_column_type(statement.pointer, index) != SQLITE_NULL {
            return Wrapped.column(at: index, statement: statement)
        } else {
            return nil
        }
    }

}

extension Int: SQLiteType {

    public static var sqLiteName: String {
        return "INTEGER"
    }

    public var sqLiteValue: String {
        return "\(self)"
    }

    public func bind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_int64(statement.pointer, index, Int64(self))
    }

    public static func column(at index: Int32, statement: SQLite.Statement) -> Int {
        return Int(sqlite3_column_int64(statement.pointer, index))
    }

}

extension Double: SQLiteType {

    public static var sqLiteName: String {
        return "REAL"
    }

    public var sqLiteValue: String {
        return "\(self)"
    }

    public func bind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_double(statement.pointer, index, self)
    }

    public static func column(at index: Int32, statement: SQLite.Statement) -> Double {
        return sqlite3_column_double(statement.pointer, index)
    }

}

extension String: SQLiteType {

    public static var sqLiteName: String {
        return "TEXT"
    }

    public var sqLiteValue: String {
        return "'\(self)'"
    }

    public func bind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_text(statement.pointer, index, NSString(string: self).utf8String, -1, nil)
    }

    public static func column(at index: Int32, statement: SQLite.Statement) -> String {
        return sqlite3_column_text(statement.pointer, index).flatMap({ String(cString: $0) }) ?? ""
    }

}

extension Date: SQLiteType {

    public static var sqLiteName: String {
        return "REAL"
    }

    public var sqLiteValue: String {
        return "\(timeIntervalSince1970)"
    }

    public func bind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_double(statement.pointer, index, timeIntervalSince1970)
    }

    public static func column(at index: Int32, statement: SQLite.Statement) -> Date {
        let timeIntervalSince1970 = sqlite3_column_double(statement.pointer, index)
        return Date(timeIntervalSince1970: timeIntervalSince1970)
    }

}

extension Omirable {

    public static var sqLiteName: String {
        return "\(Self.self)"
    }

    public var sqLiteValue: String {
        return ""
    }

    public init() {
        let container = OmirosOutput<Self>(nil)
        self.init(container: container)
    }

    public func bind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return SQLITE_OK
    }

    public static func column(at index: Int32, statement: SQLite.Statement) -> Self {
        fatalError()
    }

}
