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

    override func setUp() {
        omiros = Omiros(named: "MyStorage")
    }

    override func tearDown() async throws {
        try await omiros.deleteAll()
    }

    func testFetchingAndSaving() async throws {
        let entity = Person()

        try await omiros.save(entity)

        let fetched = try await omiros.fetchFirst(Person.self)

        XCTAssertEqual(entity.name, fetched?.name)
        XCTAssertEqual(entity.surname, fetched?.surname)
        XCTAssertEqual(entity.dateOfBirth, fetched?.dateOfBirth)
        XCTAssertEqual(entity.height, fetched?.height)
        XCTAssertEqual(entity.consumedWine, fetched?.consumedWine)
        XCTAssertEqual(entity.homePageURL, fetched?.homePageURL)
    }

    func testFiltering() async throws {
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

        try await omiros.save(entities)

        let options = OmirosQueryOptions<Person>([
            .equal(.name, "Jack"),
            .any([
                .equal(.surname, "White"),
                .equal(.surname, "Black")
            ])
        ])

        let fetched = try? await omiros.fetch(Person.self, with: options)
        XCTAssertEqual(fetched?.count, 200)
    }

    func testCounting() async throws {
        var owner = Owner()

        var ebony = Dog(ownerID: owner.id, name: "Ebony")
        ebony.collarCaption = "Ebony"
        ebony.collarCaption = nil

        var ivory = Dog(ownerID: owner.id, name: "Ivory")
        ivory.collarCaption = "Evory"
        ivory.collarCaption = "Love Ivory"

        owner.dogs = [ebony, ivory]

        try await omiros.save(owner)

        let ownerCount = try await omiros.count(Owner.self)
        let dogCount = try await omiros.count(Dog.self)
        let filteredDogCount = try await omiros.count(Dog.self, with: .init(.any([.like(.collarCaption, "%love%")])))

        XCTAssertEqual(ownerCount, 1)
        XCTAssertEqual(dogCount, 2)
        XCTAssertEqual(filteredDogCount, 1)
    }

    func testOrderingAndPagination() async throws {
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

        try await omiros.save(entities)

        var options = OmirosQueryOptions<Person>()
        options.order = .ascending([.name, .surname])
        options.offset = 200
        options.limit = 100

        let fetched = try? await omiros.fetch(Person.self, with: options)
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

    func testSavingExisting() async throws {
        var owner = Owner()

        var ebony = Dog(ownerID: owner.id, name: "Ebony")
        ebony.collarCaption = "Ebony"

        var ivory = Dog(ownerID: owner.id, name: "Ivory")
        ivory.collarCaption = "Evory"

        owner.dogs = [ebony, ivory]

        try await omiros.save(owner)

        ebony.collarCaption = "Love Ebony"
        ivory.collarCaption = "Love Ivory"
        owner.dogs = [ebony, ivory]

        try await omiros.save(owner)

        let owners = try await omiros.fetch(Owner.self)
        let dogs = try await omiros.fetch(Dog.self, with: .init(order: .ascending([.collarCaption])))

        XCTAssertEqual(owners.count, 1)
        XCTAssertEqual(dogs.count, 2)
        XCTAssertEqual(owners.first?.name, owner.name)
        XCTAssertEqual(dogs[0], owner.dogs[0])
        XCTAssertEqual(dogs[1], owner.dogs[1])
    }

    func testParallelOperations() async throws {
        let saveBunchOfPeople: @Sendable () async throws -> Void = {
            var entities: [Person] = []
            for _ in 0..<100 {
                entities.append(.init())
            }

            try await self.omiros.save(entities)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask(operation: saveBunchOfPeople)
            group.addTask(operation: saveBunchOfPeople)
            group.addTask(operation: saveBunchOfPeople)

            try await group.waitForAll()
        }

        let fetched = try await omiros.fetch(Person.self)
        XCTAssertEqual(fetched.count, 300)
    }

    func testDeleteAll() async throws {
        var entities: [Person] = []
        for _ in 0..<100 {
            entities.append(.init())
        }

        try await omiros.save(entities)

        var fetched = try await omiros.fetch(Person.self)
        XCTAssertEqual(fetched.count, 100)

        try await omiros.deleteAll()

        fetched = try await omiros.fetch(Person.self)
        XCTAssertEqual(fetched.count, 0)
    }

}
