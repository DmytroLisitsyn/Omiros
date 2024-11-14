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
import Combine
import os

public actor Omiros {

    public let connection: SQLiteConnection

    public init(_ name: String = "Omiros", inMemory: Bool = false, logger: Logger? = nil) {
        if inMemory {
            connection = SQLiteConnectionToMemory(named: name, logger: logger)
        } else {
            connection = SQLiteConnectionToFile(named: name, logger: logger)
        }
    }

    public func count<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> Int {
        let db = try connection.setup()
        return try T.count(in: db, with: options)
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> T? {
        let db = try connection.setup()
        return try T.init(in: db, with: options)
    }

    public func fetch<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> [T] {
        let db = try connection.setup()
        return try [T].init(in: db, with: options)
    }

    public func save<T: Omirable>(_ entity: T) throws {
        try save([entity])
    }

    public func save<T: Omirable>(_ entities: [T]) throws {
        let db = try connection.setup()
        try db.execute("BEGIN TRANSACTION;")
        try entities.save(in: db)
        try db.execute("END TRANSACTION;")
    }

    public func delete<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws {
        let db = try connection.setup()
        try T.delete(in: db, with: options)
    }

    public func deleteAll() throws {
        switch connection {
        case let connection as SQLiteConnectionToFile:
            try connection.deleteDatabase()
        case let connection as SQLiteConnectionToMemory:
            connection.deleteDatabase()
        default:
            break
        }
    }

}
