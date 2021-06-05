//
//  OmirosTests
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

import XCTest
@testable import Omiros

class OmirosTests: XCTestCase {

    var omiros: Omiros!

    override func setUpWithError() throws {
        omiros = Omiros(named: "MyStorage")
    }

    override func tearDownWithError() throws {
        try omiros.deleteAll()
    }

    func testFetchingAndSaving() throws {
        let entity = Person()

        try omiros.save(entity)

        let fetched = try omiros.fetchFirst(Person.self)

        XCTAssertEqual(entity.name, fetched?.name)
        XCTAssertEqual(entity.surname, fetched?.surname)
        XCTAssertEqual(entity.dateOfBirth, fetched?.dateOfBirth)
        XCTAssertEqual(entity.height, fetched?.height)
    }

    func testSavingPerformance() throws {
        var entities: [Person] = []
        for _ in 0..<10000 {
            entities.append(.init())
        }

        measure {
            try? omiros.save(entities)
        }
    }

    func testFetchingPerformance() throws {
        var entities: [Person] = []
        for _ in 0..<10000 {
            entities.append(.init())
        }

        try omiros.save(entities)

        measure {
            let fetched = try? omiros.fetch(Person.self)
            XCTAssertEqual(entities.count, fetched?.count)
        }
    }

    func testFilteringPerformance() throws {
        var entities: [Person] = []
        for _ in 0..<10000 {
            entities.append(.init())
        }
        for _ in 0..<100 {
            entities.append(Person(name: "Jack", surname: "White"))
            entities.append(Person(name: "Jack", surname: "Black"))
            entities.append(Person(name: "Jack", surname: "Gray"))
            entities.append(Person(name: "Peter", surname: "Parker"))
        }
        entities.append(Person(name: "Brandon", surname: "Smith"))

        try omiros.save(entities)

        measure {
            let options = OmirosQueryOptions<Person>([
                .equal(.name, "Jack"),
                .any([
                    .equal(.surname, "White"),
                    .equal(.surname, "Black")
                ])
            ])

            let fetched = try? omiros.fetch(Person.self, with: options)
            XCTAssertEqual(fetched?.count, 200)
        }
    }

    func testOrderingAndPagination() throws {
        var entities: [Person] = []

        for _ in 0..<100 {
            entities.append(Person(name: "Jack", surname: "White"))
        }
        for _ in 0..<100 {
            entities.append(Person(name: "Jack", surname: "Black"))
        }
        for _ in 0..<100 {
            entities.append(Person(name: "Peter", surname: "Parker"))
        }
        for _ in 0..<100 {
            entities.append(Person(name: "Brandon", surname: "Smith"))
        }

        try omiros.save(entities)

        var options = OmirosQueryOptions<Person>()
        options.orderBy = [.name, .surname]
        options.offset = 200
        options.limit = 100

        let fetched = try? omiros.fetch(Person.self, with: options)
        XCTAssertEqual(fetched?.count, 100)

        XCTAssertEqual(fetched?.first?.name, "Jack")
        XCTAssertEqual(fetched?.first?.surname, "White")

        XCTAssertEqual(fetched?.last?.name, "Jack")
        XCTAssertEqual(fetched?.last?.surname, "White")
    }

    func testNotInQueryParameters() throws {
        var entities: [Person] = []

        for _ in 0..<10 {
            entities.append(Person(name: "Jack", surname: "White"))
        }
        for _ in 0..<10 {
            entities.append(Person(name: "Jack", surname: "Black"))
        }
        for _ in 0..<10 {
            entities.append(Person(name: "Peter", surname: "Parker", height: 190))
        }
        for _ in 0..<10 {
            entities.append(Person(name: "Rihanna"))
        }
        entities.append(Person(name: "Bree", surname: "Whale", height: 180))

        try omiros.save(entities)

        var options = OmirosQueryOptions<Person>(
            .not(.equal(.name, "Jack")),
            .not(.equal(.name, "Rihanna"))
        )
        var fetched = try? omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 11)

        options = OmirosQueryOptions<Person>(
            .not(.all([
                .equal(.name, "Jack"),
                .equal(.surname, "Black")
            ]))
        )
        fetched = try? omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 31)

        options = OmirosQueryOptions<Person>(.not(.equal(.surname, nil)))
        fetched = try? omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 31)

        options = OmirosQueryOptions<Person>(.not(.greaterThanOrEqual(.height, 180)))
        fetched = try? omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 30)

        options = OmirosQueryOptions<Person>(.not(.like(.surname, "Wh%")))
        fetched = try? omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 20)
    }

}
