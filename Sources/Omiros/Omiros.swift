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

public final class Omiros {

    public let name: String

    public init(named name: String) {
        self.name = name
    }

    public func save<Entity: Omirable>(_ entity: Entity) throws {
        let db = try SQLite(named: name)
        try db.execute("BEGIN TRANSACTION;")

        try Entity.setup(in: db)
        try entity.save(in: db)

        try db.execute("END TRANSACTION;")
    }

    public func save<Entity: Omirable>(_ list: [Entity]) throws {
        let db = try SQLite(named: name)
        try db.execute("BEGIN TRANSACTION;")

        try Entity.setup(in: db)
        try list.save(in: db)

        try db.execute("END TRANSACTION;")
    }

    public func fetchOne<Entity: Omirable>(_ type: Entity.Type = Entity.self, with options: OmirosQueryOptions<Entity> = .init()) throws -> Entity? {
        let db = try SQLite(named: name)
        let entity: Entity? = try .init(with: options, db: db)
        return entity
    }

    public func fetch<Entity: Omirable>(_ type: Entity.Type = Entity.self, with options: OmirosQueryOptions<Entity> = .init()) throws -> [Entity] {
        let db = try SQLite(named: name)
        let entities: [Entity] = try .init(with: options, db: db)
        return entities
    }

    public func delete<Entity: Omirable>(_ type: Entity.Type = Entity.self, with options: OmirosQueryOptions<Entity> = .init()) throws {
        let db = try SQLite(named: name)

        guard try Entity.isSetup(in: db) else { return }

        try db.execute("DELETE FROM \(Entity.omirosName)\(options.sqlWhereClause());")
    }

    public func deleteAll() throws {
        try SQLite.delete(named: name)
    }

}
