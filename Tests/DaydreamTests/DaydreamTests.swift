import XCTest
@testable import DaydreamCompiler
import BigNumber
import TransmissionData

final class DaydreamTests: XCTestCase
{
    public func testBIntZero() throws
    {
        let zero = BInt(0)

        let buffer = TransmissionData()

        try zero.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let bint = try BInt(daydream: buffer)

        XCTAssertEqual(bint, zero)
    }

    public func testBIntOne() throws
    {
        let one = BInt(1)

        let buffer = TransmissionData()

        try one.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let bint = try BInt(daydream: buffer)

        XCTAssertEqual(bint, one)
    }

    public func testBIntTwo() throws
    {
        let two = BInt(2)

        let buffer = TransmissionData()

        try two.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let bint = try BInt(daydream: buffer)

        XCTAssertEqual(bint, two)
    }

    public func testBIntMaxInt() throws
    {
        let maxint = BInt(Int.max)

        let buffer = TransmissionData()

        try maxint.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let bint = try BInt(daydream: buffer)

        XCTAssertEqual(bint, maxint)
    }

    public func testBIntMaxIntPlus() throws
    {
        let maxintplus = BInt(Int.max) + BInt(1)

        let buffer = TransmissionData()

        try maxintplus.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let bint = try BInt(daydream: buffer)

        XCTAssertEqual(bint, maxintplus)
    }

    public func testStringEmpty() throws
    {
        let string: String = ""

        let buffer = TransmissionData()

        try string.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let string2 = try String(daydream: buffer)

        XCTAssertEqual(string2, string)
    }

    public func testStringHello() throws
    {
        let string: String = "hello"

        let buffer = TransmissionData()

        try string.saveDaydream(buffer)

        buffer.flip()

        print(buffer.description)

        let string2 = try String(daydream: buffer)

        XCTAssertEqual(string2, string)
    }
}
