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

    public enum Location {
        case file(name: String)
        case memory
    }

    let config: String
    let pointer: OpaquePointer

    public var logger: os.Logger?

    public init(in location: Location, logger: os.Logger? = nil) throws {
        self.logger = logger

        switch location {
        case .file(let name):
            config = try SQLite.makeFilePath(name: name)
        case .memory:
            config = ":memory:"
        }

        var pointer: OpaquePointer!
        let result = sqlite3_open(config, &pointer)
        self.pointer = pointer
        try processResult(result)

        logger?.log("SQLite connection opened: \(self.config)")

        try execute("PRAGMA foreign_keys=ON;")
    }

    deinit {
        sqlite3_close(pointer)
        logger?.log("SQLite connection closed: \(self.config)")
    }

    public func prepare(_ query: String) throws -> Statement {
        logger?.log("\(query)")
        return try Statement(query, database: self)
    }

    public func execute(_ query: String) throws {
        try prepare(query).step()
    }

    public static func deleteFile(named name: String) throws {
        let filePath = try makeFilePath(name: name)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(atPath: filePath)
        }
    }

    private static func makeFilePath(name: String) throws -> String {
        let fileManager = FileManager.default
        let fileURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("\(name).sqlite")
        return fileURL.path
    }

    private func processResult(_ result: Int32) throws {
        switch result {
        case SQLITE_ROW, SQLITE_DONE, SQLITE_OK:
            break
        default:
            let errorCode = Int(sqlite3_errcode(pointer))
            let message = String(cString: sqlite3_errmsg(pointer))
            throw SQLiteError(code: errorCode, message: message)
        }
    }

}

extension SQLite {

    public final class Statement {

        public var hasMoreRows = false

        public var columnCount: Int32 {
            return sqlite3_data_count(pointer)
        }

        let pointer: OpaquePointer
        let database: SQLite

        init(_ query: String, database: SQLite) throws {
            var pointer: OpaquePointer?
            let result = sqlite3_prepare_v2(database.pointer, NSString(string: query).utf8String, -1, &pointer, nil)

            try database.processResult(result)

            self.pointer = pointer!
            self.database = database
        }

        deinit {
            sqlite3_finalize(pointer)
        }

        @discardableResult
        public func step() throws -> Statement {
            let result = sqlite3_step(pointer)
            hasMoreRows = (result == SQLITE_ROW)
            try database.processResult(result)
            return self
        }

        @discardableResult
        public func bind(_ value: SQLiteType, at index: Int32) throws -> Statement {
            let result = value.bind(at: index, statement: self)
            try database.processResult(result)
            return self
        }

        public func column<T: SQLiteType>(at index: Int32, type: T.Type = T.self) -> T {
            return T.column(at: index, statement: self)
        }

        public func columnName(at index: Int32) -> String {
            return sqlite3_column_name(pointer, index).flatMap({ String(cString: $0) })!
        }

    }

}
