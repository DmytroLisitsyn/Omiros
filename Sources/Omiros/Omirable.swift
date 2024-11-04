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

public protocol AnyOmirosKey: CodingKey {

}

public protocol AnyOmirable {
    static var omirosName: String { get }

    init?(in db: SQLite, options: AnyOmirosQueryOptions) throws
    static func isSetup(in db: SQLite) throws -> Bool
    func setup(in db: SQLite) throws
    func save(in db: SQLite) throws
}

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

    public static func isSetup(in db: SQLite) throws -> Bool {
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(omirosName)';"
        let statement = try db.prepare(query).step()
        return statement.hasMoreRows
    }

    public func setup(in db: SQLite) throws {
        var container = OmirosInput<Self>()
        fill(container: &container)

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

    public func save(in db: SQLite) throws {
        var container = OmirosInput<Self>()
        fill(container: &container)

        let columnString = container.columns.keys.joined(separator: ",")
        let formatString = Array(repeating: "?", count: container.columns.count).joined(separator: ",")

        var query = "INSERT INTO \(Self.omirosName)(\(columnString)) VALUES(\(formatString))"

        if !container.primaryKeys.isEmpty {
            let conflictedKeysString = container.primaryKeys.joined(separator: ",")
            let keys = Set(container.columns.keys).subtracting(container.primaryKeys)

            let onConflictQuery: String
            if keys.isEmpty {
                onConflictQuery = "ON CONFLICT(\(conflictedKeysString)) DO NOTHING"
            } else {
                var updates: [String] = []
                for key in keys {
                    updates.append("\(key)=excluded.\(key)")
                }

                let updateString = updates.joined(separator: ",")
                onConflictQuery = "ON CONFLICT(\(conflictedKeysString)) DO UPDATE SET \(updateString)"
            }

            query += " \(onConflictQuery)"
        }

        query += ";"

        let statement = try db.prepare(query)
        for (index, value) in container.columns.values.enumerated() {
            try statement.bind(value, at: Int32(index + 1))
        }
        try statement.step()

        for (_ , values) in container.enclosed {
            try values.first?.setup(in: db)
            for element in values {
                try element.save(in: db)
            }
        }
    }

}

// MARK: Optional

extension Optional: AnyOmirable where Wrapped: Omirable {

    public static var omirosName: String {
        return Wrapped.omirosName
    }

    public init(in db: SQLite, options: AnyOmirosQueryOptions) throws {
        self = try Wrapped.init(in: db, options: options)
    }

    public static func isSetup(in db: SQLite) throws -> Bool {
        return try Wrapped.isSetup(in: db)
    }

    public func setup(in db: SQLite) throws {
        try self?.setup(in: db)
    }

    public func save(in db: SQLite) throws {
        switch self {
        case .some(let value):
            try value.save(in: db)
        case .none:
            break
        }
    }

}

// MARK: Array

extension Array: AnyOmirable where Element: Omirable {

    public static var omirosName: String {
        return Element.omirosName
    }

    public init?(in db: SQLite, options: AnyOmirosQueryOptions) throws {
        guard try Element.isSetup(in: db) else {
            return nil
        }

        var query = "SELECT COUNT(*) FROM \(Element.omirosName)\(options.sqlWhereClause());"
        var statement = try db.prepare(query).step()
        let count: Int = statement.column(at: 0)

        self.init()
        reserveCapacity(count)

        query = "SELECT * FROM \(Element.omirosName)\(options.sqlWhereClause());"
        statement = try db.prepare(query).step()

        while statement.hasMoreRows {
            let container = OmirosOutput<Element>(statement)
            let entity = try Element(container: container)
            append(entity)

            try statement.step()
        }
    }

    public static func isSetup(in db: SQLite) throws -> Bool {
        return try Element.isSetup(in: db)
    }

    public func setup(in db: SQLite) throws {
        try first?.setup(in: db)
    }

    public func save(in db: SQLite) throws {
        for element in self {
            try element.save(in: db)
        }
    }

}
