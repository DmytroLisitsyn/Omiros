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
        
}
