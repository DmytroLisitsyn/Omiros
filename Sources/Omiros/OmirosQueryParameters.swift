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

public struct OmirosQueryParameters {

    public indirect enum Condition {
        case equal(_ key: String, _ value: SQLiteType?)
        case greaterThan(_ key: String, _ value: SQLiteType)
        case lessThan(_ key: String, _ value: SQLiteType)
        case greaterThanOrEqual(_ key: String, _ value: SQLiteType)
        case lessThanOrEqual(_ key: String, _ value: SQLiteType)
        case like(_ key: String, _ value: String)
        case or(Condition, Condition)
    }

    public var conditions: [Condition]
    public var orderBy: [String]
    public var offset: Int
    public var limit: Int

    public init(_ conditions: [Condition] = [], orderBy: [String] = [], offset: Int = 0, limit: Int = 0) {
        self.conditions = conditions
        self.orderBy = orderBy
        self.offset = offset
        self.limit = limit
    }

    func sqlWhereClause() -> String {
        var subquery = ""

        if conditions.count > 0 {
            let conditionsString = sqlWhereClauseComponent(from: conditions)
            subquery += " WHERE \(conditionsString)"
        }

        if orderBy.count > 0 {
            let orderByString = orderBy.joined(separator: ",")
            subquery += " ORDER BY \(orderByString)"
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

    private func sqlWhereClauseComponent(from conditions: [OmirosQueryParameters.Condition]) -> String {
        var components: [String] = []

        for condition in conditions {
            var c: String

            switch condition {
            case .equal(let key, let value):
                if let value = value {
                    c = "\(key) = \(value.sqLiteString())"
                } else {
                    c = "\(key) IS NULL"
                }
            case .greaterThan(let key, let value):
                c = "\(key) > \(value.sqLiteString())"
            case .lessThan(let key, let value):
                c = "\(key) < \(value.sqLiteString())"
            case .greaterThanOrEqual(let key, let value):
                c = "\(key) >= \(value.sqLiteString())"
            case .lessThanOrEqual(let key, let value):
                c = "\(key) <= \(value.sqLiteString())"
            case .like(let key, let value):
                c = "\(key) LIKE \(value.sqLiteString())"
            case .or(let lhs, let rhs):
                let lhsString = sqlWhereClauseComponent(from: [lhs])
                let rhsString = sqlWhereClauseComponent(from: [rhs])
                c = "(\(lhsString) OR \(rhsString))"
            }

            components.append(c)
        }

        return components.joined(separator: " ")
    }

}
