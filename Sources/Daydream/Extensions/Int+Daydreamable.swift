//
//  Int+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

import BigNumber
import Transmission

// FIXME - support negative integers
extension Int: Daydreamable
{
    public var bint: BInt
    {
        return BInt(self)
    }

    public init?(bint: BInt)
    {
        guard let int = bint.asInt() else
        {
            return nil
        }

        self = int
    }

    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        let bint = try BInt(daydream: connection)

        guard let int = Int(bint: bint) else
        {
            throw IntError.conversionFailed
        }

        self = int
    }
    
    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        try self.bint.saveDaydream(connection)
    }
}

public enum IntError: Error
{
    case conversionFailed
}
