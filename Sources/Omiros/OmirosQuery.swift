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
        case equal(_ key: T.OmirableKey, _ value: SQLiteValue?)
        case greaterThan(_ key: T.OmirableKey, _ value: SQLiteValue)
        case lessThan(_ key: T.OmirableKey, _ value: SQLiteValue)
        case greaterThanOrEqual(_ key: T.OmirableKey, _ value: SQLiteValue)
        case lessThanOrEqual(_ key: T.OmirableKey, _ value: SQLiteValue)
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

    public func sqlSubqueryV2() -> (string: String, values: [SQLiteValue]) {
        var components: [String] = []
        var values: [SQLiteValue] = []

        if let condition = condition, let format = sqlWhereConditionsV2(from: condition, values: []) {
            components.append("WHERE \(format.string)")
            values = format.values
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

        return (components.joined(separator: " "), values)
    }

    private func sqlWhereConditionsV2(from condition: OmirosQuery.Condition?, values: [SQLiteValue]) -> (string: String, values: [SQLiteValue])? {
        switch condition {
        case .equal(let key, let value):
            if let value = value {
                return ("\(key.stringValue) = ?", values + [value])
            } else {
                return ("\(key.stringValue) IS NULL", values)
            }
        case .greaterThan(let key, let value):
            return ("\(key.stringValue) > ?", values + [value])
        case .lessThan(let key, let value):
            return ("\(key.stringValue) < ?", values + [value])
        case .greaterThanOrEqual(let key, let value):
            return ("\(key.stringValue) >= ?", values + [value])
        case .lessThanOrEqual(let key, let value):
            return ("\(key.stringValue) <= ?", values + [value])
        case .like(let key, let value):
            return ("\(key.stringValue) LIKE ?", values + [value])
        case .not(let condition):
            return reversedSQLWhereConditionsV2(from: condition, values: values)
        case .all(let conditions):
            guard conditions.count > 0 else {
                return nil
            }

            var conditionStrings: [String] = []
            var values = values
            for condition in conditions {
                if let format = sqlWhereConditionsV2(from: condition, values: []) {
                    conditionStrings.append(format.string)
                    values += format.values
                }
            }

            return ("(\(conditionStrings.joined(separator: " AND ")))", values)
        case .any(let conditions):
            guard conditions.count > 0 else {
                return nil
            }

            var conditionStrings: [String] = []
            var values = values
            for condition in conditions {
                if let format = sqlWhereConditionsV2(from: condition, values: []) {
                    conditionStrings.append(format.string)
                    values += format.values
                }
            }

            return ("(\(conditionStrings.joined(separator: " OR ")))", values)
        case .none:
            return nil
        }
    }

    private func reversedSQLWhereConditionsV2(from condition: OmirosQuery.Condition?, values: [SQLiteValue]) -> (String, [SQLiteValue])? {
        switch condition {
        case .equal(let key, let value):
            if let value = value {
                return ("\(key.stringValue) != ?", values + [value])
            } else {
                return ("\(key.stringValue) IS NOT NULL", values)
            }
        case .greaterThan(let key, let value):
            return sqlWhereConditionsV2(from: .lessThanOrEqual(key, value), values: values)
        case .lessThan(let key, let value):
            return sqlWhereConditionsV2(from: .greaterThanOrEqual(key, value), values: values)
        case .greaterThanOrEqual(let key, let value):
            return sqlWhereConditionsV2(from: .lessThan(key, value), values: values)
        case .lessThanOrEqual(let key, let value):
            return sqlWhereConditionsV2(from: .greaterThan(key, value), values: values)
        case .like(let key, let value):
            return ("\(key.stringValue) NOT LIKE ?", values + [value])
        case .all(let conditions):
            return sqlWhereConditionsV2(from: .any(conditions.map(Condition.not)), values: values)
        case .any(let conditions):
            return sqlWhereConditionsV2(from: .all(conditions.map(Condition.not)), values: values)
        case .not(let condition):
            return reversedSQLWhereConditionsV2(from: condition, values: values)
        case .none:
            return nil
        }
    }

}
