//
//  Unicode.Scalar+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

import BigNumber
import Transmission

extension Unicode.Scalar: Daydreamable
{
    public init(daydream connection: Transmission.Connection) throws
    {
        let bint = try BInt(daydream: connection)

        guard let int = bint.asInt() else
        {
            throw UnicodeScalarError.conversionFailed
        }

        let uint32 = UInt32(int)

        guard let scalar = Unicode.Scalar(uint32) else
        {
            throw UnicodeScalarError.conversionFailed
        }

        self = scalar
    }
    
    public func saveDaydream(_ connection: Transmission.Connection) throws
    {
        let int = Int(self.value)

        let bint = BInt(int)

        try bint.saveDaydream(connection)
    }
}

public enum UnicodeScalarError: Error
{
    case conversionFailed
}
