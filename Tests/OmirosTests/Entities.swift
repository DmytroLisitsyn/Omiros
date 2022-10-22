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

import Foundation
import Omiros

struct Person: Omirable {

    enum OmirosKey: CodingKey {
        case id
        case name
        case surname
        case height
        case dateOfBirth
    }

    var id = ""
    var name = ""
    var surname: String?
    var height: Double
    var dateOfBirth: Date

    init(id: String = UUID().uuidString, name: String = "John Doe", surname: String? = nil, height: Double = 172, dateOfBirth: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.name = name
        self.surname = surname
        self.height = height
        self.dateOfBirth = dateOfBirth
    }

    init(container: OmirosOutput<Person>) throws {
        self.init()

        id = try container.get(.id)
        name = try container.get(.name)
        surname = try container.get(.surname)
        height = try container.get(.height)
        dateOfBirth = try container.get(.dateOfBirth)
    }

    func fill(container: OmirosInput<Person>) {
        container.set(id, for: .id)
        container.set(name, for: .name)
        container.set(surname, for: .surname)
        container.set(height, for: .height)
        container.set(dateOfBirth, for: .dateOfBirth)
    }

}

struct Owner: Omirable {

    enum OmirosKey: CodingKey {
        case id
        case name
        case dogs
    }

    var id = ""
    var name = ""
    var dogs: [Dog] = []

    init(id: String = UUID().uuidString) {
        self.id = id
    }

    init(container: OmirosOutput<Owner>) throws {
        self.init(id: try container.get(.id))

        name = try container.get(.name)
        dogs = try container.get(with: .init(.equal(.ownerID, id)))
    }

    func fill(container: OmirosInput<Owner>) {
        container.setPrimaryKey(.id)

        container.set(id, for: .id)
        container.set(name, for: .name)
        container.set(dogs)
    }

}

struct Dog: Omirable, Equatable {

    enum OmirosKey: CodingKey {
        case id
        case ownerID
        case name
        case collarCaption
    }

    var id: String {
        return "\(ownerID)_\(name)"
    }

    var ownerID = ""
    var name = ""
    var collarCaption = ""

    init(ownerID: String, name: String) {
        self.ownerID = ownerID
        self.name = name
    }

    init(container: OmirosOutput<Dog>) throws {
        self.init(ownerID: try container.get(.ownerID), name: try container.get(.name))

        collarCaption = try container.get(.collarCaption)
    }

    func fill(container: OmirosInput<Dog>) {
        container.setPrimaryKey(.id)

        container.set(id, for: .id)
        container.set(name, for: .name)
        container.set(collarCaption, for: .collarCaption)
        container.set(ownerID, for: .ownerID, as: OmirosRelation<Owner>(.id))
    }

}
