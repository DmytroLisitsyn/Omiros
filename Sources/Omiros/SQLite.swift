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
import os

public final class SQLite {

    private let path: String
    private let logger: os.Logger?

    private let pointer: OpaquePointer

    public init(path: String, flags: Int32, logger: os.Logger? = nil) throws(SQLiteError) {
        self.path = path
        self.logger = logger

        var pointer: OpaquePointer!
        let result = sqlite3_open_v2("file:\(path)", &pointer, flags, nil)
        self.pointer = pointer
        try processResult(result)

        logger?.log("SQLite opened: \(self.path)")
    }

    deinit {
        sqlite3_close(pointer)
        logger?.log("SQLite closed: \(self.path)")
    }

    public func prepare(_ query: String) throws(SQLiteError) -> Statement {
        logger?.log("\(query)")
        return try Statement(query, db: self)
    }

    public func execute(_ query: String) throws(SQLiteError) {
        try prepare(query).step()
    }

    private func processResult(_ result: Int32) throws(SQLiteError) {
        switch result {
        case SQLITE_ROW, SQLITE_DONE, SQLITE_OK:
            break
        default:
            let errorCode = sqlite3_errcode(pointer)
            let message = String(cString: sqlite3_errmsg(pointer))
            throw SQLiteError(code: errorCode, message: message)
        }
    }

}

extension SQLite {

    public final class Statement {

        public var hasMoreRows = false

        let db: SQLite
        let pointer: OpaquePointer

        init(_ query: String, db: SQLite) throws(SQLiteError) {
            var pointer: OpaquePointer?
            let result = sqlite3_prepare_v2(db.pointer, NSString(string: query).utf8String, -1, &pointer, nil)

            try db.processResult(result)

            self.pointer = pointer!
            self.db = db
        }

        deinit {
            sqlite3_finalize(pointer)
        }

        @discardableResult
        public func step() throws(SQLiteError) -> Statement {
            let result = sqlite3_step(pointer)
            hasMoreRows = (result == SQLITE_ROW)
            try db.processResult(result)
            return self
        }

        @discardableResult
        public func bind(_ value: SQLiteType, at index: Int32) throws(SQLiteError) -> Statement {
            let result = value.sqLiteBind(at: index, statement: self)
            try db.processResult(result)
            return self
        }

        public func value<T: SQLiteType>(at index: Int32, type: T.Type = T.self) -> T {
            return T.sqLiteValue(at: index, statement: self)
        }

        public func columnName(at index: Int32) -> String {
            return sqlite3_column_name(pointer, index).flatMap({ String(cString: $0) })!
        }

        public func columnCount() -> Int32 {
            return sqlite3_data_count(pointer)
        }

    }

}
