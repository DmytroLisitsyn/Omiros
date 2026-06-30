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

public protocol SQLiteConnection: AnyObject {
    func read<T>(_ transaction: (_ db: SQLite) throws -> T) async throws -> T
    func write(_ transaction: (_ db: SQLite) throws -> Void) async throws
    func deleteFile() async throws
}

// MARK: - SQLiteConnectionToFile

actor SQLiteConnectionToFile: SQLiteConnection {

    private var dbForWriting: SQLite?

    private let file: SQLiteFileReference
    private let logger: Logger?

    init(file: SQLiteFileReference, logger: Logger?) {
        self.file = file
        self.logger = logger
    }

    nonisolated func read<T>(_ transaction: (_ db: SQLite) throws -> T) async throws -> T {
        if await dbForWriting == nil {
            try await setupForWriting()
        }
        let db = try Self.setupForReading(file: file, logger: logger)
        return try transaction(db)
    }

    func write(_ transaction: (_ db: SQLite) throws -> Void) throws {
        let db = try setupForWriting()
        try db.execute("BEGIN TRANSACTION;")
        do {
            try transaction(db)
            try db.execute("END TRANSACTION;")
        } catch {
            try? db.execute("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    func deleteFile() async throws {
        dbForWriting = nil

        let path = try file.resolvePath()
        let filesToDelete = [path, path + "-wal", path + "-shm"]
        let fileManager = FileManager.default
        for filePath in filesToDelete where fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(atPath: filePath)
        }
    }

    private static func setupForReading(file: SQLiteFileReference, logger: Logger?) throws -> SQLite {
        let path = try file.resolvePath()
        let db = try SQLite(path: path, flags: SQLITE_OPEN_READWRITE, logger: logger)
        try db.execute("PRAGMA foreign_keys=ON;")
        try db.execute("PRAGMA busy_timeout=3000;")
        return db
    }

    @discardableResult
    private func setupForWriting() throws -> SQLite {
        if let db = dbForWriting {
            return db
        } else {
            let path = try file.resolvePath()
            let db = try SQLite(path: path, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, logger: logger)
            try db.execute("PRAGMA journal_mode=WAL;")
            try db.execute("PRAGMA synchronous=NORMAL;")
            try db.execute("PRAGMA foreign_keys=ON;")
            try db.execute("PRAGMA busy_timeout=3000;")
            dbForWriting = db
            return db
        }
    }

}

// MARK: - SQLiteConnectionToMemory

actor SQLiteConnectionToMemory: SQLiteConnection {

    private var db: SQLite!

    private let file: SQLiteFileReference
    private let logger: Logger?

    init(file: SQLiteFileReference, logger: Logger?) {
        self.file = file
        self.logger = logger
    }

    func read<T>(_ transaction: (_ db: SQLite) throws -> T) throws -> T {
        let db = try setup()
        return try transaction(db)
    }

    func write(_ transaction: (_ db: SQLite) throws -> Void) throws {
        let db = try setup()
        try db.execute("BEGIN TRANSACTION;")
        do {
            try transaction(db)
            try db.execute("END TRANSACTION;")
        } catch {
            try? db.execute("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    func deleteFile() throws {
        db = nil
    }

    private func setup() throws -> SQLite {
        if let db = db {
            return db
        } else {
            let path = try file.resolvePath()
            let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY | SQLITE_OPEN_SHAREDCACHE
            db = try SQLite(path: path, flags: flags, logger: logger)
            try db.execute("PRAGMA foreign_keys=ON;")
            return db
        }
    }
    
}
