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

public final class Omiros {

    public let name: String

    public init(named name: String) {
        self.name = name
    }

    public func save<T: Omirable>(_ entity: T) async throws {
        try await Task {
            try save(entity)
        }.value
    }

    public func save<T: Omirable>(_ entity: T) throws {
        let db = try SQLite(named: name)
        try db.execute("BEGIN TRANSACTION;")

        try entity.setup(in: db)
        try entity.save(in: db)

        try db.execute("END TRANSACTION;")
    }

    public func save<T: Omirable>(_ list: [T]) async throws {
        try await Task {
            try save(list)
        }.value
    }

    public func save<T: Omirable>(_ list: [T]) throws {
        let db = try SQLite(named: name)
        try db.execute("BEGIN TRANSACTION;")

        try list.first?.setup(in: db)
        try list.save(in: db)

        try db.execute("END TRANSACTION;")
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) async throws -> T? {
        return try await Task {
            return try fetchFirst(type, with: options)
        }.value
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> T? {
        let db = try SQLite(named: name)
        let entity: T? = try .init(with: options, db: db)
        return entity
    }

    public func fetch<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) async throws -> [T] {
        return try await Task {
            return try fetch(type, with: options)
        }.value
    }

    public func fetch<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws -> [T] {
        let db = try SQLite(named: name)
        let entities: [T] = try .init(with: options, db: db) ?? []
        return entities
    }

    public func delete<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) async throws {
        try await Task {
            try delete(type, with: options)
        }.value
    }

    public func delete<T: Omirable>(_ type: T.Type = T.self, with options: OmirosQueryOptions<T> = .init()) throws {
        let db = try SQLite(named: name)

        guard try T.isSetup(in: db) else { return }

        try db.execute("DELETE FROM \(T.omirosName)\(options.sqlWhereClause());")
    }

    public func deleteAll() async throws {
        try await Task {
            try deleteAll()
        }.value
    }

    public func deleteAll() throws {
        try SQLite.delete(named: name)
    }

}
