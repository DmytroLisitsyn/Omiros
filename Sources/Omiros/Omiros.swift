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

    public func save<T: Omirable>(_ entity: T) throws {
        try save([entity])
    }

    public func save<T: Omirable>(_ entities: [T]) throws {
        let db = try SQLite(named: name)
        let entityName = self.entityName(T.self)

        try db.execute("CREATE TABLE IF NOT EXISTS \(entityName)(_id INTEGER PRIMARY KEY);")

        var existingColumns: Set<String> = []
        var statement = try db.prepare("PRAGMA table_info(\(entityName))").step()
        while statement.hasMoreRows {
            existingColumns.insert(String.column(at: 1, statement: statement))
            try statement.step()
        }

        try db.execute("BEGIN TRANSACTION;")

        for entity in entities {
            let container = OmirosInput()
            entity.fill(container: container)

            var columnList: [String] = []
            var valueList: [SQLiteType] = []

            for (column, value) in container.content {
                if !existingColumns.contains(column) {
                    let sqLiteType = type(of: value).sqLiteName
                    try db.prepare("ALTER TABLE \(entityName) ADD \(column) \(sqLiteType);").step()
                    existingColumns.insert(column)
                }

                columnList.append(column)
                valueList.append(value)
            }

            let columnString = columnList.joined(separator: ",")
            let formatString = Array(repeating: "?", count: columnList.count).joined(separator: ",")

            statement = try db.prepare("INSERT INTO \(entityName)(\(columnString)) VALUES(\(formatString));")
            for (index, value) in valueList.enumerated() {
                try statement.bind(value, at: Int32(index + 1))
            }
            try statement.step()
        }
        
        try db.execute("END TRANSACTION;")
    }

    public func fetchFirst<T: Omirable>(_ type: T.Type = T.self, with parameters: OmirosQueryParameters = .init()) throws -> T? {
        var parameters = parameters
        parameters.limit = 1

        let fetched = try fetch(T.self, with: parameters)
        return fetched.first
    }
    
    public func fetch<T: Omirable>(_ type: T.Type = T.self, with parameters: OmirosQueryParameters = .init()) throws -> [T] {
        let db = try SQLite(named: name)
        let entityName = self.entityName(T.self)

        var entities: [T] = []

        guard try tableExists(db, entityName: entityName) else {
            return entities
        }

        let statement = try db.prepare("SELECT * FROM \(entityName)\(parameters.sqlWhereClause());").step()
        while statement.hasMoreRows {
            let container = OmirosOutput(statement)

            let entity = T(container: container)
            entities.append(entity)

            try statement.step()
        }

        return entities
    }

    public func delete<T: Omirable>(_ type: T.Type = T.self, with parameters: OmirosQueryParameters = .init()) throws {
        let db = try SQLite(named: name)
        let entityName = self.entityName(T.self)

        guard try tableExists(db, entityName: entityName) else {
            return
        }

        try db.execute("DELETE FROM \(entityName)\(parameters.sqlWhereClause());")
    }

    public func deleteAll() throws {
        try SQLite.delete(named: name)
    }
    
}

extension Omiros {

    private func entityName<T>(_ entityType: T) -> String {
        return "\(entityType)"
    }

    private func tableExists(_ db: SQLite, entityName: String) throws -> Bool {
        let statement = try db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='\(entityName)';").step()
        return statement.hasMoreRows
    }

}
