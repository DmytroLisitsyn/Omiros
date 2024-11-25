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

public struct OmirosQuery<T: Omirable> {

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
        case asc(T.OmirableKey)
        case desc(T.OmirableKey)
    }

    public var condition: Condition?
    public var order: [Order]
    public var offset: Int
    public var limit: Int

    public init(where condition: Condition? = nil, order: [Order] = [], offset: Int = 0, limit: Int = 0) {
        self.condition = condition
        self.order = order
        self.offset = offset
        self.limit = limit
    }

    public func sqlSubquery() -> String {
        var components: [String] = []

        if let condition = condition, let conditionsString = sqlWhereConditions(from: condition) {
            components.append("WHERE \(conditionsString)")
        }

        if !order.isEmpty {
            let orderStrings = order.map({ order in
                switch order {
                case .asc(let omirableKey):
                    return "\(omirableKey.stringValue) ASC"
                case .desc(let omirableKey):
                    return "\(omirableKey.stringValue) DESC"
                }
            })

            components.append("ORDER BY \(orderStrings.joined(separator: ", "))")
        }

        if limit > 0 {
            components.append("LIMIT \(limit)")
        }

        if offset > 0 {
            if !(limit > 0) {
                components.append("LIMIT -1")
            }

            components.append("OFFSET \(offset)")
        }

        return components.joined(separator: " ")
    }

    private func sqlWhereConditions(from condition: OmirosQuery.Condition?) -> String? {
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
            let conditionStrings = conditions.compactMap(sqlWhereConditions)
            if conditionStrings.isEmpty {
                return nil
            } else {
                return "(\(conditionStrings.joined(separator: " AND ")))"
            }
        case .any(let conditions):
            let conditionStrings = conditions.compactMap(sqlWhereConditions)
            if conditionStrings.isEmpty {
                return nil
            } else {
                return "(\(conditionStrings.joined(separator: " OR ")))"
            }
        case .not(let condition):
            return reversedSQLWhereConditions(from: condition)
        case .none:
            return nil
        }
    }

    private func reversedSQLWhereConditions(from condition: OmirosQuery.Condition?) -> String? {
        switch condition {
        case .equal(let key, let value):
            if let value = value {
                return "\(key.stringValue) != \(value.sqLiteQueryValue)"
            } else {
                return "\(key.stringValue) IS NOT NULL"
            }
        case .greaterThan(let key, let value):
            return sqlWhereConditions(from: .lessThanOrEqual(key, value))
        case .lessThan(let key, let value):
            return sqlWhereConditions(from: .greaterThanOrEqual(key, value))
        case .greaterThanOrEqual(let key, let value):
            return sqlWhereConditions(from: .lessThan(key, value))
        case .lessThanOrEqual(let key, let value):
            return sqlWhereConditions(from: .greaterThan(key, value))
        case .like(let key, let value):
            return "\(key.stringValue) NOT LIKE \(value.sqLiteQueryValue)"
        case .all(let conditions):
            return sqlWhereConditions(from: .any(conditions.map(Condition.not)))
        case .any(let conditions):
            return sqlWhereConditions(from: .all(conditions.map(Condition.not)))
        case .not(let condition):
            return reversedSQLWhereConditions(from: condition)
        case .none:
            return nil
        }
    }

}
