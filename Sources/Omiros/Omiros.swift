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
        try save([entity])
    }

    public func save<Entity: Omirable>(_ entities: [Entity]) throws {
        guard !entities.isEmpty else { return }

        var entities = entities
        let entity = entities.removeLast()

        let container = OmirosInput<Entity>()
        entity.fill(container: container)

        let db = try SQLite(named: name)
        try setupTable(with: container, in: db)

        try db.execute("BEGIN TRANSACTION;")
        try insertEntity(entity, into: db)
        for entity in entities {
            try insertEntity(entity, into: db)
        }
        try db.execute("END TRANSACTION;")
    }

    public func fetchFirst<Entity: Omirable>(_ type: Entity.Type = Entity.self, with options: OmirosQueryOptions<Entity> = .init()) throws -> Entity? {
        var options = options
        options.limit = 1

        let fetched = try fetch(Entity.self, with: options)
        return fetched.first
    }

    public func fetch<Entity: Omirable>(_ type: Entity.Type = Entity.self, with options: OmirosQueryOptions<Entity> = .init()) throws -> [Entity] {
        let db = try SQLite(named: name)
        let entityName = self.entityName(Entity.self)

        var entities: [Entity] = []

        guard try tableExists(db, entityName: entityName) else {
            return entities
        }

        let statement = try db.prepare("SELECT * FROM \(entityName)\(options.sqlWhereClause());").step()
        while statement.hasMoreRows {
            let container = OmirosOutput<Entity>(statement)

            let entity = Entity(container: container)
            entities.append(entity)

            try statement.step()
        }

        return entities
    }

    public func delete<Entity: Omirable>(_ type: Entity.Type = Entity.self, with options: OmirosQueryOptions<Entity> = .init()) throws {
        let db = try SQLite(named: name)
        let entityName = self.entityName(Entity.self)

        guard try tableExists(db, entityName: entityName) else {
            return
        }

        try db.execute("DELETE FROM \(entityName)\(options.sqlWhereClause());")
    }

    public func deleteAll() throws {
        try SQLite.delete(named: name)
    }

}

extension Omiros {

    private func entityName<T>(_ entityType: T.Type) -> String {
        return "\(entityType)"
    }

    private func tableExists(_ db: SQLite, entityName: String) throws -> Bool {
        let statement = try db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='\(entityName)';").step()
        return statement.hasMoreRows
    }

    private func setupTable<Entity: Omirable>(with container: OmirosInput<Entity>, in db: SQLite) throws {
        let entityName = self.entityName(Entity.self)

        if try tableExists(db, entityName: entityName) {
            var existingColumns: Set<String> = []
            let statement = try db.prepare("PRAGMA table_info(\(entityName))").step()

            while statement.hasMoreRows {
                existingColumns.insert(String.column(at: 1, statement: statement))
                try statement.step()
            }

            for (column, value) in container.content where !existingColumns.contains(column) {
                let sqLiteType = type(of: value).sqLiteName
                try db.execute("ALTER TABLE \(entityName) ADD \(column) \(sqLiteType);")
                existingColumns.insert(column)
            }
        } else {
            let columns = container.content
                .map({ "\($0) \(type(of: $1).sqLiteName)" })
                .joined(separator: ",")

            try db.execute("CREATE TABLE \(entityName)(\(columns));")
        }
    }

    private func insertEntity<Entity: Omirable>(_ entity: Entity, into db: SQLite) throws {
        let entityName = self.entityName(Entity.self)

        let container = OmirosInput<Entity>()
        entity.fill(container: container)

        var columnList: [String] = []
        var valueList: [SQLiteType] = []

        for (column, value) in container.content {
            columnList.append(column)
            valueList.append(value)
        }

        let columnString = columnList.joined(separator: ",")
        let formatString = Array(repeating: "?", count: columnList.count).joined(separator: ",")

        let statement = try db.prepare("INSERT INTO \(entityName)(\(columnString)) VALUES(\(formatString));")
        for (index, value) in valueList.enumerated() {
            try statement.bind(value, at: Int32(index + 1))
        }
        try statement.step()
    }

}
