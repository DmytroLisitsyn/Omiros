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

// MARK: - AnyOmirable

public protocol AnyOmirable {
    static var omirosName: String { get }

    init?(in db: SQLite, options: AnyOmirosQueryOptions) throws
    func save(in db: SQLite) throws
    static func count(in db: SQLite, options: AnyOmirosQueryOptions) throws -> Int
    static func delete(in db: SQLite, options: AnyOmirosQueryOptions) throws
    static func isSetup(in db: SQLite) throws -> Bool
}

extension AnyOmirable {

    public static func count(in db: SQLite, options: AnyOmirosQueryOptions) throws -> Int {
        guard try isSetup(in: db) else {
            return 0
        }

        let query = "SELECT COUNT(*) FROM \(omirosName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()
        let count: Int = statement.column(at: 0)
        return count
    }

    public static func delete(in db: SQLite, options: AnyOmirosQueryOptions) throws {
        guard try isSetup(in: db) else { return }

        try db.execute("DELETE FROM \(omirosName)\(options.sqlWhereClause());")
    }

    public static func isSetup(in db: SQLite) throws -> Bool {
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(omirosName)';"
        let statement = try db.prepare(query).step()
        return statement.hasMoreRows
    }

}

// MARK: - AnyOmirosKey

public protocol AnyOmirosKey: CodingKey {

}

// MARK: - Omirable

public protocol Omirable: AnyOmirable {
    associatedtype OmirosKey: AnyOmirosKey

    init(container: OmirosOutput<Self>) throws
    func fill(container: inout OmirosInput<Self>)
}

extension Omirable {

    public static var omirosName: String {
        return "\(self)"
    }

    public init?(in db: SQLite, options: AnyOmirosQueryOptions) throws {
        guard try Self.isSetup(in: db) else {
            return nil
        }

        var options = options
        options.limit = 1
        let query = "SELECT * FROM \(Self.omirosName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()

        if statement.hasMoreRows {
            let container = OmirosOutput<Self>(statement)
            self = try .init(container: container)
        } else {
            return nil
        }
    }

    public func save(in db: SQLite) throws {
        try [self].save(in: db)
    }

}

// MARK: - Optional

extension Optional: AnyOmirable where Wrapped: Omirable {

    public static var omirosName: String {
        return Wrapped.omirosName
    }

    public init(in db: SQLite, options: AnyOmirosQueryOptions) throws {
        self = try Wrapped.init(in: db, options: options)
    }

    public func save(in db: SQLite) throws {
        try self?.save(in: db)
    }

}

// MARK: - Array

extension Array: AnyOmirable where Element: Omirable {

    public static var omirosName: String {
        return Element.omirosName
    }

    public init?(in db: SQLite, options: AnyOmirosQueryOptions) throws {
        guard try Element.isSetup(in: db) else {
            return nil
        }

        let query = "SELECT * FROM \(Element.omirosName)\(options.sqlWhereClause());"
        let statement = try db.prepare(query).step()

        self.init()

        while statement.hasMoreRows {
            let container = OmirosOutput<Element>(statement)
            let entity = try Element(container: container)
            append(entity)
            try statement.step()
        }
    }

    public func save(in db: SQLite) throws {
        guard count > 0 else { return }

        var index = 0
        var container = OmirosInput<Element>()
        self[index].fill(container: &container)

        let columnKeys = container.columns.keys
        let joinedColumnList = columnKeys.joined(separator: ",")
        let formatString = [String](repeating: "?", count: columnKeys.count).joined(separator: ",")
        var query = "INSERT INTO \(Self.omirosName)(\(joinedColumnList)) VALUES(\(formatString))"

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

        try setup(in: db, with: container)

        while true {
            let statement = try db.prepare(query)
            for (index, columnKey) in columnKeys.enumerated() {
                try statement.bind(container.columns[columnKey]!, at: Int32(index + 1))
            }
            try statement.step()

            for (_ , enclosedEntities) in container.enclosed {
                for (enclosedEntity, deleteOptions) in enclosedEntities {
                    if let options = deleteOptions {
                        try type(of: enclosedEntity).delete(in: db, options: options)
                    }

                    try enclosedEntity.save(in: db)
                }
            }

            index += 1
            guard index < count else { break }

            container = OmirosInput<Element>()
            self[index].fill(container: &container)
        }
    }

    private func setup(in db: SQLite, with container: OmirosInput<Element>) throws {
        if try Self.isSetup(in: db) {
            var existingColumns: Set<String> = []

            var statement = try db.prepare("PRAGMA table_info(\(Self.omirosName))").step()
            while statement.hasMoreRows {
                let column = String.column(at: 1, statement: statement)
                existingColumns.insert(column)

                try statement.step()
            }

            for (column, value) in container.columns where !existingColumns.contains(column) {
                existingColumns.insert(column)

                try db.execute("ALTER TABLE \(Self.omirosName) ADD \(column) \(type(of: value).sqLiteName);")

                if let relation = container.relations[column] {
                    try db.execute("ALTER TABLE \(Self.omirosName) ADD FOREIGN KEY(\(column)) REFERENCES \(relation.type.omirosName)(\(relation.key)) ON DELETE CASCADE;")
                }
            }

            var existingIndices: Set<String> = []
            statement = try db.prepare("PRAGMA index_list(\(Self.omirosName));").step()
            while statement.hasMoreRows {
                let name = String.column(at: 1, statement: statement)
                if name.hasPrefix("omiros_") {
                    existingIndices.insert(name)
                }

                try statement.step()
            }

            for index in container.indices {
                if existingIndices.contains(index.name) {
                    existingIndices.remove(index.name)
                } else {
                    try db.execute("CREATE INDEX \(index.name) ON \(Self.omirosName)(\(index.keys.joined(separator: ",")));")
                }
            }

            for existingIndex in existingIndices {
                try db.execute("DROP INDEX \(existingIndex);")
            }
        } else {
            var components: [String] = []

            for (key, sqlType) in container.columns {
                components.append("\(key) \(type(of: sqlType).sqLiteName)")
            }

            for (key, relation) in container.relations {
                components.append("FOREIGN KEY(\(key)) REFERENCES \(relation.type.omirosName)(\(relation.key)) ON DELETE CASCADE")
            }

            if !container.primaryKeys.isEmpty {
                components.append("PRIMARY KEY (\(container.primaryKeys.joined(separator: ",")))")
            }

            try db.execute("CREATE TABLE \(Self.omirosName)(\(components.joined(separator: ",")));")

            for index in container.indices {
                try db.execute("CREATE INDEX \(index.name) ON \(Self.omirosName)(\(index.keys.joined(separator: ",")));")
            }
        }
    }

}
