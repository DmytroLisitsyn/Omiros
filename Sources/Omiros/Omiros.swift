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

public actor Omiros {

    private let connection: SQLiteConnection

    private init(connection: SQLiteConnection) {
        self.connection = connection
    }

    public init(named name: String) {
        self.init(connection: SQLiteConnectionToFile(named: name))
    }

    public static func inMemory() -> Omiros {
        return Omiros(connection: SQLiteConnectionToMemory())
    }

    public func save<T: Omirable>(_ entity: T) throws {
        let db = try connection.setup()
        try db.execute("BEGIN TRANSACTION;")

        try entity.setup(in: db)
        try entity.save(in: db)

        try db.execute("END TRANSACTION;")
    }
    
    public func save<T: Omirable>(_ list: [T]) throws {
        let db = try connection.setup()
        try db.execute("BEGIN TRANSACTION;")

        try list.first?.setup(in: db)
        try list.save(in: db)

        try db.execute("END TRANSACTION;")
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> T? {
        let db = try connection.setup()
        let entity = try T.init(with: options, db: db)
        return entity
    }

    public func fetch<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> [T] {
        let db = try connection.setup()
        let entities = try Array<T>.init(with: options, db: db) ?? []
        return entities
    }

    public func count<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> Int {
        let db = try connection.setup()

        guard try T.isSetup(in: db) else {
            return 0
        }

        let query = "SELECT COUNT(*) FROM \(T.omirosName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()
        let count: Int = statement.column(at: 0)
        return count
    }

    public func delete<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws {
        let db = try connection.setup()

        guard try T.isSetup(in: db) else { return }

        try db.execute("DELETE FROM \(T.omirosName)\(options.sqlWhereClause());")
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

private protocol SQLiteConnection {
    func setup() throws -> SQLite
}

private final class SQLiteConnectionToFile: SQLiteConnection {

    let name: String

    init(named name: String) {
        self.name = name
    }

    func setup() throws -> SQLite {
        return try SQLite(in: .file(name: name))
    }

}

private final class SQLiteConnectionToMemory: SQLiteConnection {

    private var db: SQLite?

    init() {

    }

    func setup() throws -> SQLite {
        if let db = db {
            return db
        } else {
            let db = try SQLite(in: .memory)
            self.db = db
            return db
        }
    }

    func reset() {
        db = nil
    }

}
