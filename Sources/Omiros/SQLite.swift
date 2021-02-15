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

public struct SQLiteError: Error, Equatable {

    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.code == rhs.code
    }

}

public final class SQLite {
        
    let pointer: OpaquePointer
    
    public init(named name: String) throws {
        let fileManager = FileManager.default
        let fileURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("\(name).sqlite")

        var pointer: OpaquePointer!
        let result = sqlite3_open(fileURL.path, &pointer)

        self.pointer = pointer

        try processResult(result)
    }
    
    deinit {
        sqlite3_close(pointer)
    }
    
    public func prepare(_ query: String) throws -> Statement {
        try Statement(query, database: self)
    }

    public func execute(_ query: String) throws {
        try prepare(query).step()
    }
    
    public static func delete(named name: String) throws {
        let fileManager = FileManager.default
        let fileURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("\(name).sqlite")

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(atPath: fileURL.path)
        }
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
        
        let pointer: OpaquePointer
        
        public var hasMoreRows = false
        
        public var columnCount: Int32 {
            return sqlite3_data_count(pointer)
        }
        
        private let database: SQLite

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
