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

public final class Omiros {

    public let connection: SQLiteConnection

    public convenience init(_ name: String = "Omiros", inMemory: Bool = false, logger: Logger? = nil) {
        self.init(file: .name(name), inMemory: inMemory, logger: logger)
    }

    public convenience init(path: String, inMemory: Bool = false, logger: Logger? = nil) {
        self.init(file: .path(path), inMemory: inMemory, logger: logger)
    }

    private init(file: FileReference, inMemory: Bool = false, logger: Logger? = nil) {
        if inMemory {
            connection = SQLiteConnectionToMemory(file: file, logger: logger)
        } else {
            connection = SQLiteConnectionToFile(file: file, logger: logger)
        }
    }

    public func count<T: Omirable>(_ type: T.Type = T.self, with query: OmirosQuery<T> = .init()) async throws -> Int {
        return try await connection.read { db in
            return try T.count(in: db, with: query)
        }
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with query: OmirosQuery<T> = .init()) async throws -> T? {
        return try await connection.read { db in
            return try T.init(in: db, with: query)
        }
    }

    public func fetch<T: Omirable>(_ type: T.Type = T.self, with query: OmirosQuery<T> = .init()) async throws -> [T] {
        return try await connection.read { db in
            return try [T].init(in: db, with: query)
        }
    }

    public func save<T: Omirable>(_ entity: T) async throws {
        try await connection.write(entity.save)
    }

    public func save<T: Omirable>(_ entities: [T]) async throws {
        try await connection.write(entities.save)
    }

    public func delete<T: Omirable>(_ type: T.Type = T.self, with query: OmirosQuery<T> = .init()) async throws {
        try await connection.write { db in
            try T.delete(in: db, with: query)
        }
    }

    public func deleteFile() async throws {
        try await connection.deleteFile()
    }

}
