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
    @inlinable static var sqLiteType: String { get }
    var sqLiteQueryValue: String { get }

    func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32
    static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Self
}

extension Optional: SQLiteType where Wrapped: SQLiteType {

    public static var sqLiteType: String {
        return "NULL"
    }

    public var sqLiteQueryValue: String {
        return "NULL"
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        switch self {
        case .some(let value):
            return value.sqLiteBind(at: index, statement: statement)
        case .none:
            return sqlite3_bind_null(statement.pointer, index)
        }
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Wrapped? {
        if sqlite3_column_type(statement.pointer, index) != SQLITE_NULL {
            return Wrapped.sqLiteValue(at: index, statement: statement)
        } else {
            return nil
        }
    }

}

extension Bool: SQLiteType {

    public static var sqLiteType: String {
        return "INTEGER"
    }

    public var sqLiteQueryValue: String {
        return "\(self ? 1 : 0)"
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_int(statement.pointer, index, self ? 1 : 0)
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Bool {
        return sqlite3_column_int(statement.pointer, index) != 0
    }

}

extension Int: SQLiteType {

    public static var sqLiteType: String {
        return "INTEGER"
    }

    public var sqLiteQueryValue: String {
        return "\(self)"
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_int64(statement.pointer, index, Int64(self))
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Int {
        return Int(sqlite3_column_int64(statement.pointer, index))
    }

}

extension Double: SQLiteType {

    public static var sqLiteType: String {
        return "REAL"
    }

    public var sqLiteQueryValue: String {
        return "\(self)"
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_double(statement.pointer, index, self)
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Double {
        return sqlite3_column_double(statement.pointer, index)
    }

}

extension String: SQLiteType {

    public static var sqLiteType: String {
        return "TEXT"
    }

    public var sqLiteQueryValue: String {
        return "'\(self)'"
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_text(statement.pointer, index, NSString(string: self).utf8String, -1, nil)
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> String {
        return sqlite3_column_text(statement.pointer, index).flatMap(String.init(cString:)) ?? ""
    }

}

extension Data: SQLiteType {

    public static var sqLiteType: String {
        return "BLOB"
    }

    public var sqLiteQueryValue: String {
        fatalError("Not supported BLOB query.")
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        let data = self as NSData
        return sqlite3_bind_blob(statement.pointer, index, data.bytes, Int32(data.length), nil)
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Data {
        let bytes = sqlite3_column_blob(statement.pointer, index)
        let length = sqlite3_column_bytes(statement.pointer, index)
        return NSData(bytes: bytes, length: Int(length)) as Data
    }

}

extension Date: SQLiteType {

    public static var sqLiteType: String {
        return TimeInterval.sqLiteType
    }

    public var sqLiteQueryValue: String {
        return timeIntervalSince1970.sqLiteQueryValue
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return sqlite3_bind_double(statement.pointer, index, timeIntervalSince1970)
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> Date {
        return Date(timeIntervalSince1970: sqlite3_column_double(statement.pointer, index))
    }

}

extension URL: SQLiteType {

    public static var sqLiteType: String {
        return String.sqLiteType
    }

    public var sqLiteQueryValue: String {
        return absoluteString.sqLiteQueryValue
    }

    public func sqLiteBind(at index: Int32, statement: SQLite.Statement) -> Int32 {
        return absoluteString.sqLiteBind(at: index, statement: statement)
    }

    public static func sqLiteValue(at index: Int32, statement: SQLite.Statement) -> URL {
        return URL(string: .sqLiteValue(at: index, statement: statement))!
    }

}
