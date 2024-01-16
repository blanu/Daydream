//
//  Data+Utilities.swift
//  
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

import BigNumber

extension Data
{
    public func popVarint() -> (BInt, Data)?
    {
        var working: Data = data

        guard working.count > 0 else
        {
            return nil
        }

        guard let firstByte = working.first else
        {
            return nil
        }
        working = working.dropFirst()

        let count = Int(firstByte)

        guard working.count >= count else
        {
            return nil
        }

        let next: Data
        if count == 1
        {
            guard let first = working.first else
            {
                return nil
            }

            next = Data(array: [first])

            working = working.dropFirst()
        }
        else
        {
            next = Data(working[0..<count])
            working = Data(working[count...])
        }

        let varintBytes = Data(array: [firstByte] + next)
        guard let bint = BInt(varint: varintBytes) else
        {
            return nil
        }

        return (bint, working)
    }

    public func popLength() -> (Int, Data)?
    {
        guard let (bint, rest) = self.popVarint() else
        {
            return nil
        }

        guard let int = bint.asInt() else
        {
            return nil
        }

        return (int, rest)
    }

    public func popLengthAndSlice() -> (Data, Data)?
    {
        guard let (length, rest) = self.popLength() else
        {
            return nil
        }

        guard length <= rest.count else
        {
            return nil
        }

        let head = Data(rest[0..<length])
        let tail = Data(rest[length...])

        return (head, tail)
    }

    public func pushVarint(bint: BInt) -> Data
    {
        return bint.varint + self
    }

    public func pushLength() -> Data
    {
        let bint = BInt(self.count)
        return self.pushVarint(bint: bint)
    }
}
