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

public protocol Omirable {
    associatedtype OmirableKey: CodingKey
    @inlinable static var omirableName: String { get }
    init(container: OmirosFetching<Self>) throws
    func fill(container: inout OmirosSaving<Self>)
}

extension Omirable {

    public static var omirableName: String {
        return "\(self)"
    }

    init?(in db: SQLite, with options: OmirosQueryOptions<Self>) throws {
        guard try Self.isSetup(in: db) else {
            return nil
        }

        var options = options
        options.limit = 1
        let query = "SELECT * FROM \(Self.omirableName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()

        if statement.hasMoreRows {
            let container = OmirosFetching<Self>(statement)
            self = try .init(container: container)
        } else {
            return nil
        }
    }

    static func count(in db: SQLite, with options: OmirosQueryOptions<Self>) throws -> Int {
        guard try isSetup(in: db) else { return 0 }

        let query = "SELECT COUNT(*) FROM \(omirableName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()
        return statement.value(at: 0)
    }

    static func delete(in db: SQLite, with options: OmirosQueryOptions<Self>) throws {
        guard try isSetup(in: db) else { return }

        try db.execute("DELETE FROM \(omirableName)\(options.sqlWhereClause());")
    }

    static func isSetup(in db: SQLite) throws -> Bool {
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(omirableName)';"
        let statement = try db.prepare(query).step()
        return statement.hasMoreRows
    }

    static func setup(in db: SQLite, with container: OmirosSaving<Self>) throws {
        if try isSetup(in: db) {
            var existingColumns: Set<String> = []

            var statement = try db.prepare("PRAGMA table_info(\(omirableName))").step()
            while statement.hasMoreRows {
                let column = String.sqLiteValue(at: 1, statement: statement)
                existingColumns.insert(column)

                try statement.step()
            }

            for (column, value) in container.columns where !existingColumns.contains(column) {
                existingColumns.insert(column)

                try db.execute("ALTER TABLE \(omirableName) ADD \(column) \(type(of: value).sqLiteType);")

                if let relation = container.relations[column] {
                    try db.execute("ALTER TABLE \(omirableName) ADD FOREIGN KEY(\(column)) REFERENCES \(relation.typeString)(\(relation.key)) ON DELETE CASCADE;")
                }
            }

            var existingIndices: Set<String> = []
            statement = try db.prepare("PRAGMA index_list(\(omirableName));").step()
            while statement.hasMoreRows {
                let name = String.sqLiteValue(at: 1, statement: statement)
                if name.hasPrefix("\(omirableName)_") {                    existingIndices.insert(name)
                }

                try statement.step()
            }

            for index in container.indices {
                if existingIndices.contains(index.name) {
                    existingIndices.remove(index.name)
                } else {
                    try db.execute("CREATE INDEX \(index.name) ON \(omirableName)(\(index.keys.joined(separator: ",")));")
                }
            }

            for existingIndex in existingIndices {
                try db.execute("DROP INDEX \(existingIndex);")
            }
        } else {
            var components: [String] = []

            for (key, sqlType) in container.columns {
                components.append("\(key) \(type(of: sqlType).sqLiteType)")
            }

            for (key, relation) in container.relations {
                components.append("FOREIGN KEY(\(key)) REFERENCES \(relation.typeString)(\(relation.key)) ON DELETE CASCADE")
            }

            if !container.primaryKeys.isEmpty {
                components.append("PRIMARY KEY (\(container.primaryKeys.joined(separator: ",")))")
            }

            try db.execute("CREATE TABLE \(omirableName)(\(components.joined(separator: ",")));")

            for index in container.indices {
                try db.execute("CREATE INDEX \(index.name) ON \(omirableName)(\(index.keys.joined(separator: ",")));")
            }
        }
    }

}

extension Array where Element: Omirable {

    init(in db: SQLite, with options: OmirosQueryOptions<Element>) throws {
        guard try Element.isSetup(in: db) else {
            self = []
            return
        }

        let query = "SELECT * FROM \(Element.omirableName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()
        let container = OmirosFetching<Element>(statement)

        self.init()

        while statement.hasMoreRows {
            append(try Element(container: container))
            try statement.step()
        }
    }

    func save(in db: SQLite) throws {
        guard count > 0 else { return }

        var index = 0
        var container = OmirosSaving<Element>()
        self[index].fill(container: &container)

        let columnKeys = container.columns.keys
        let joinedColumnList = columnKeys.joined(separator: ",")
        let formatString = [String](repeating: "?", count: columnKeys.count).joined(separator: ",")
        var query = "INSERT INTO \(Element.omirableName)(\(joinedColumnList)) VALUES(\(formatString))"

        if !container.primaryKeys.isEmpty {
            let conflictedKeysString = container.primaryKeys.joined(separator: ",")
            let keys = Set(columnKeys).subtracting(container.primaryKeys)
            if keys.isEmpty {
                query += " ON CONFLICT(\(conflictedKeysString)) DO NOTHING"
            } else {
                let updateString = keys.map({ "\($0)=excluded.\($0)" }).joined(separator: ",")
                query += " ON CONFLICT(\(conflictedKeysString)) DO UPDATE SET \(updateString)"
            }
        }

        query += ";"

        try Element.setup(in: db, with: container)

        while true {
            let statement = try db.prepare(query)
            for (index, columnKey) in columnKeys.enumerated() {
                try statement.bind(container.columns[columnKey]!, at: Int32(index + 1))
            }
            try statement.step()

            for enclosedEntityList in container.enclosed {
                try enclosedEntityList.save(in: db)
            }

            index += 1
            guard index < count else { break }

            container = OmirosSaving<Element>()
            self[index].fill(container: &container)
        }
    }

}
