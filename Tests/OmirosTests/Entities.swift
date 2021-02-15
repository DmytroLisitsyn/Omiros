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

    @OmirosField("name") var name: String
    @OmirosField("surname") var surname: String?
    @OmirosField("height") var height: Double
    @OmirosField("dateOfBirth") var dateOfBirth: Date

    init(name: String = "John Doe", surname: String? = nil, height: Double = 172, dateOfBirth: Date = Date(timeIntervalSince1970: 30)) {
        self.height = height
        self.surname = surname
        self.name = name
        self.dateOfBirth = dateOfBirth
    }

    init(container: OmirosOutput) {
        self.init()

        _name.fill(from: container)
        _surname.fill(from: container)
        _height.fill(from: container)
        _dateOfBirth.fill(from: container)
    }

    func fill(container: OmirosInput) {
        container.fill(from: _name)
        container.fill(from: _surname)
        container.fill(from: _height)
        container.fill(from: _dateOfBirth)
    }

}
