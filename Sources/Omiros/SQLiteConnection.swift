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
import os

public protocol SQLiteConnection: AnyObject {
    func setup() throws -> SQLite
}

extension SQLiteConnection {

    func deleteFile(path: String) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }

    func makeFilePath(name: String) throws -> String {
        let fileManager = FileManager.default
        let fileURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("\(name).db")
        return fileURL.path
    }

}

final class SQLiteConnectionToFile: SQLiteConnection {

    private let name: String
    private let logger: Logger?

    init(named name: String, logger: Logger?) {
        self.name = name
        self.logger = logger
    }

    public func setup() throws -> SQLite {
        let filePath = try makeFilePath(name: name)
        let db = try SQLite(path: filePath, logger: logger)
        return db
    }

    func deleteDatabase() throws {
        let filePath = try makeFilePath(name: name)
        try deleteFile(path: filePath)
    }

}

final class SQLiteConnectionToMemory: SQLiteConnection {

    private let name: String
    private let logger: Logger?

    private var db: SQLite?

    init(named name: String, logger: Logger?) {
        self.name = name
        self.logger = logger
    }

    public func setup() throws -> SQLite {
        let filePath = try makeFilePath(name: name)

        if db == nil {
            db = try SQLite(path: filePath, inMemory: true, logger: logger)
        }

        let db = try SQLite(path: filePath, inMemory: true, logger: logger)
        return db
    }

    func deleteDatabase() {
        db = nil
    }
    
}
