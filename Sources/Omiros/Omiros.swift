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

    private let connection: SQLiteConnection

    private init(connection: SQLiteConnection) {
        self.connection = connection
    }

    public init(named name: String, logger: Logger? = nil) {
        let connection = SQLiteConnectionToFile(named: name)
        connection.logger = logger
        self.init(connection: connection)
    }

    public static func inMemory(logger: Logger? = nil) -> Omiros {
        let connection = SQLiteConnectionToMemory()
        connection.logger = logger
        return Omiros(connection: connection)
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> T? {
        let db = try connection.setup()
        let entity = try T.init(in: db, options: options)
        return entity
    }

    public func fetch<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> [T] {
        let db = try connection.setup()
        let entities = try [T].init(in: db, options: options) ?? []
        return entities
    }

    public func count<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> Int {
        let db = try connection.setup()
        let count = try T.count(in: db, options: options)
        return count
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
        try T.delete(in: db, options: options)
    }

    public func deleteAll() throws {
        switch connection {
        case let connection as SQLiteConnectionToFile:
            try SQLite.deleteFile(named: connection.name)
        case let connection as SQLiteConnectionToMemory:
            connection.reset()
        default:
            break
        }
    }

}

// MARK: - SQLiteConnection

private protocol SQLiteConnection: AnyObject {
    var logger: Logger? { get set }
    func setup() throws -> SQLite
}

private final class SQLiteConnectionToFile: SQLiteConnection {

    var logger: Logger?

    let name: String

    init(named name: String) {
        self.name = name
    }

    func setup() throws -> SQLite {
        let db = try SQLite(in: .file(name: name), logger: logger)
        return db
    }

}

private final class SQLiteConnectionToMemory: SQLiteConnection {

    var logger: Logger? {
        didSet { db?.logger = logger }
    }

    private var db: SQLite?

    init() {

    }

    func setup() throws -> SQLite {
        if let db = db {
            return db
        } else {
            let db = try SQLite(in: .memory, logger: logger)
            self.db = db
            return db
        }
    }

    func reset() {
        db = nil
    }

}
