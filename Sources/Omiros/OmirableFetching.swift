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

public struct OmirableFetching<T: Omirable> {

    private weak var statement: SQLite.Statement?
    private var columnIndexByName: [String: Int32] = [:]

    public init(_ statement: SQLite.Statement) {
        self.statement = statement

        for columnIndex in 0..<statement.columnCount() {
            columnIndexByName[statement.columnName(at: columnIndex)] = Int32(columnIndex)
        }
    }

    public func get<U: SQLiteType>(_ valueType: U.Type = U.self, for key: T.OmirableKey) throws -> U {
        guard let columnIndex = columnIndexByName[key.stringValue] else {
            throw OmirosError.noColumnForKey(key.stringValue)
        }

        return statement!.value(at: columnIndex, type: valueType)
    }

    public func get<U: Omirable>(_ entityType: U.Type = U.self, with query: OmirosQuery<U>) throws -> U? {
        return try entityType.init(in: statement!.db, with: query)
    }

    public func get<U: Omirable>(_ entityType: [U].Type = [U].self, with query: OmirosQuery<U>) throws -> [U] {
        return try entityType.init(in: statement!.db, with: query)
    }

}
