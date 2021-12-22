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
        try db.execute("BEGIN TRANSACTION;")

        try setupTable(with: container, in: db)

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

        guard try tableExists(Entity.self, in: db) else { return [] }

        var entities: [Entity] = []

        let statement = try db.prepare("SELECT * FROM \(Entity.sqLiteName)\(options.sqlWhereClause());").step()
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

        guard try tableExists(Entity.self, in: db) else { return }

        try db.execute("DELETE FROM \(Entity.sqLiteName)\(options.sqlWhereClause());")
    }

    public func deleteAll() throws {
        try SQLite.delete(named: name)
    }

}

extension Omiros {

    private func tableExists<Entity: Omirable>(_ entity: Entity.Type, in db: SQLite) throws -> Bool {
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(Entity.sqLiteName)';"
        let statement = try db.prepare(query).step()
        return statement.hasMoreRows
    }

    private func setupTable<Entity: Omirable>(with container: OmirosInput<Entity>, in db: SQLite) throws {
        let entityName = Entity.sqLiteName

        if try tableExists(Entity.self, in: db) {
            var existingColumns: Set<String> = []
            let statement = try db.prepare("PRAGMA table_info(\(entityName))").step()

            while statement.hasMoreRows {
                existingColumns.insert(String.column(at: 1, statement: statement))
                try statement.step()
            }

            for (column, value) in container.content where !existingColumns.contains(column) {
                existingColumns.insert(column)

                var sqLiteName = type(of: value).sqLiteName
                try db.execute("ALTER TABLE \(entityName) ADD \(sqLiteName) \(sqLiteName);")

                guard let relation = container.relations[column] else { continue }

                sqLiteName = relation.type.sqLiteName
                try db.execute("ALTER TABLE \(entityName) ADD FOREIGN KEY(\(column)) REFERENCES \(sqLiteName)(\(relation.key));")
            }
        } else {
            var columns: [String] = []

            for (key, sqlType) in container.content {
                let sqLiteName = type(of: sqlType).sqLiteName
                columns.append("\(key) \(sqLiteName)")
            }

            for (key, relation) in container.relations {
                let sqLiteName = relation.type.sqLiteName
                columns.append("FOREIGN KEY(\(key)) REFERENCES \(sqLiteName)(\(relation.key))")
            }

            let description = columns.joined(separator: ",")
            try db.execute("CREATE TABLE \(entityName)(\(description));")
        }
    }

    private func insertEntity<Entity: Omirable>(_ entity: Entity, into db: SQLite) throws {
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
        let statement = try db.prepare("INSERT INTO \(Entity.sqLiteName)(\(columnString)) VALUES(\(formatString));")

        for (index, value) in valueList.enumerated() {
            try statement.bind(value, at: Int32(index + 1))
        }

        try statement.step()
    }

}
