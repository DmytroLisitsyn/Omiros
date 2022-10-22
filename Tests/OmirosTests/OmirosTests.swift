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

        entities.shuffle()

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
        options.order = .ascending([.name, .surname])
        options.offset = 200
        options.limit = 100

        let fetched = try? omiros.fetch(Person.self, with: options)
        XCTAssertEqual(fetched?.count, 100)

        XCTAssertEqual(fetched?.first?.name, "Jack")
        XCTAssertEqual(fetched?.first?.surname, "White")

        XCTAssertEqual(fetched?.last?.name, "Jack")
        XCTAssertEqual(fetched?.last?.surname, "White")
    }

    func testNotInQueryParameters() async throws {
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

        try await omiros.save(entities)

        var options = OmirosQueryOptions<Person>(
            .not(.equal(.name, "Jack")),
            .not(.equal(.name, "Rihanna"))
        )
        var fetched = try? await omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 11)

        options = OmirosQueryOptions<Person>(
            .not(.all([
                .equal(.name, "Jack"),
                .equal(.surname, "Black")
            ]))
        )
        fetched = try? await omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 31)

        options = OmirosQueryOptions<Person>(.not(.equal(.surname, nil)))
        fetched = try? await omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 31)

        options = OmirosQueryOptions<Person>(.not(.greaterThanOrEqual(.height, 180)))
        fetched = try? await omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 30)

        options = OmirosQueryOptions<Person>(.not(.like(.surname, "Wh%")))
        fetched = try? await omiros.fetch(Person.self, with: options)

        XCTAssertEqual(fetched?.count, 20)
    }

    func testSavingAndFetchingWithRelations() async throws {
        var entity = Owner()
        entity.dogs.append(Dog(ownerID: entity.id, name: "Ebony"))
        entity.dogs.append(Dog(ownerID: entity.id, name: "Ivory"))

        try await omiros.save(entity)

        let fetched: Owner? = try await omiros.fetchFirst()

        XCTAssertEqual(entity.id, fetched?.id)
        XCTAssertEqual(entity.dogs.count, fetched?.dogs.count)
        XCTAssertEqual(entity.dogs.first?.ownerID, fetched?.dogs.first?.ownerID)
        XCTAssertEqual(entity.dogs.first?.name, fetched?.dogs.first?.name)
        XCTAssertEqual(entity.dogs.last?.ownerID, fetched?.dogs.last?.ownerID)
        XCTAssertEqual(entity.dogs.last?.name, fetched?.dogs.last?.name)
    }

    func testSavingAndDeletingWithRelations() async throws {
        var entity = Owner()
        entity.dogs.append(Dog(ownerID: entity.id, name: "Ebony"))
        entity.dogs.append(Dog(ownerID: entity.id, name: "Ivory"))

        try await omiros.save(entity)

        var fetchedDogs: [Dog] = try await omiros.fetch()
        XCTAssertEqual(fetchedDogs.count, entity.dogs.count)

        try await omiros.delete(Owner.self)

        let fetchedOwner: Owner? = try await omiros.fetchFirst()
        XCTAssertNil(fetchedOwner)

        fetchedDogs = try await omiros.fetch()
        XCTAssertTrue(fetchedDogs.isEmpty)
    }

    func testSavingExisting() throws {
        var owner = Owner(id: "owner_0")
        owner.name = "Ievgen"

        owner.dogs.append(Dog(ownerID: owner.id, name: "Ebony"))
        owner.dogs.append(Dog(ownerID: owner.id, name: "Ivory"))

        try omiros.save(owner)

        owner.name = "Jack"

        try omiros.save(owner)

        let owners = try omiros.fetch(Owner.self)
        let dogs = try omiros.fetch(Dog.self)

        XCTAssertEqual(owners.first?.name, owner.name)
        XCTAssertEqual(owners.count, 1)
        XCTAssertEqual(dogs.count, 2)
    }

}
