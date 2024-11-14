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

public struct OmirosQueryOptions<T: Omirable> {

    public indirect enum Condition {
        case equal(_ key: T.OmirableKey, _ value: SQLiteType?)
        case greaterThan(_ key: T.OmirableKey, _ value: SQLiteType)
        case lessThan(_ key: T.OmirableKey, _ value: SQLiteType)
        case greaterThanOrEqual(_ key: T.OmirableKey, _ value: SQLiteType)
        case lessThanOrEqual(_ key: T.OmirableKey, _ value: SQLiteType)
        case like(_ key: T.OmirableKey, _ value: String)
        case all([Condition])
        case any([Condition])
        case not(Condition)
    }

    public enum Order {
        case ascending([T.OmirableKey])
        case descending([T.OmirableKey])
    }

    public var condition: Condition?
    public var order: Order
    public var offset: Int
    public var limit: Int

    public init(_ condition: Condition? = nil, order: Order = .ascending([]), offset: Int = 0, limit: Int = 0) {
        self.condition = condition
        self.order = order
        self.offset = offset
        self.limit = limit
    }

    public func sqlWhereClause() -> String {
        var subquery = ""

        if let condition = condition {
            let clause = sqlWhereClause(for: condition)
            subquery += " WHERE \(clause)"
        }

        var orderConstraints: [T.OmirableKey]
        var orderDirection: String

        switch order {
        case .ascending(let constraints):
            orderConstraints = constraints
            orderDirection = "ASC"
        case .descending(let constraints):
            orderConstraints = constraints
            orderDirection = "DESC"
        }

        if orderConstraints.count > 0 {
            let clause = orderConstraints.map({ $0.stringValue }).joined(separator: ",")
            subquery += " ORDER BY \(clause) \(orderDirection)"
        }

        if limit > 0 {
            subquery += " LIMIT \(limit)"
        }

        if offset > 0 {
            if !(limit > 0) {
                subquery += " LIMIT -1"
            }

            subquery += " OFFSET \(offset)"
        }

        return subquery
    }

    private func sqlWhereClause(for condition: OmirosQueryOptions.Condition) -> String {
        switch condition {
        case .equal(let key, let value):
            if let value = value {
                return "\(key.stringValue) = \(value.sqLiteQueryValue)"
            } else {
                return "\(key.stringValue) IS NULL"
            }
        case .greaterThan(let key, let value):
            return "\(key.stringValue) > \(value.sqLiteQueryValue)"
        case .lessThan(let key, let value):
            return "\(key.stringValue) < \(value.sqLiteQueryValue)"
        case .greaterThanOrEqual(let key, let value):
            return "\(key.stringValue) >= \(value.sqLiteQueryValue)"
        case .lessThanOrEqual(let key, let value):
            return "\(key.stringValue) <= \(value.sqLiteQueryValue)"
        case .like(let key, let value):
            return "\(key.stringValue) LIKE \(value.sqLiteQueryValue)"
        case .all(let conditions):
            let clause = conditions.map(sqlWhereClause).joined(separator: " AND ")
            return "(\(clause))"
        case .any(let conditions):
            let clause = conditions.map(sqlWhereClause).joined(separator: " OR ")
            return "(\(clause))"
        case .not(let condition):
            return reversedSQLWhereClause(for: condition)
        }
    }

    private func reversedSQLWhereClause(for condition: OmirosQueryOptions.Condition) -> String {
        switch condition {
        case .equal(let key, let value):
            if let value = value {
                return "\(key.stringValue) != \(value.sqLiteQueryValue)"
            } else {
                return "\(key.stringValue) IS NOT NULL"
            }
        case .greaterThan(let key, let value):
            return sqlWhereClause(for: .lessThanOrEqual(key, value))
        case .lessThan(let key, let value):
            return sqlWhereClause(for: .greaterThanOrEqual(key, value))
        case .greaterThanOrEqual(let key, let value):
            return sqlWhereClause(for: .lessThan(key, value))
        case .lessThanOrEqual(let key, let value):
            return sqlWhereClause(for: .greaterThan(key, value))
        case .like(let key, let value):
            return "\(key.stringValue) NOT LIKE \(value.sqLiteQueryValue)"
        case .all(let conditions):
            return sqlWhereClause(for: .any(conditions.map(Condition.not)))
        case .any(let conditions):
            return sqlWhereClause(for: .all(conditions.map(Condition.not)))
        case .not(let condition):
            return reversedSQLWhereClause(for: condition)
        }
    }

}
