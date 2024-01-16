//
//  BInt+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/12/24.
//

import Foundation

import BigNumber
import Transmission

extension BInt: Daydreamable
{
    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        let limbCountData = try connection.read(compression: true)

        guard let limbCountUInt64 = UInt64(maybeNetworkData: limbCountData) else
        {
            throw BIntError.conversionFailed
        }

        let limbCount = Int(limbCountUInt64)

        guard limbCount > 0 else
        {
            self = BInt.zero
            return
        }

        var limbs: Limbs = []
        for _ in 0..<limbCount
        {
            let limbData = try connection.read(compression: true)

            guard let uint64 = UInt64(maybeNetworkData: limbData) else
            {
                throw BIntError.conversionFailed
            }

            limbs.append(uint64)
        }

        let bint = BInt(limbs: limbs)
        self = bint
    }

    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        if self == 0
        {
            guard connection.write(data: Data(array: [0x00])) else
            {
                throw BIntError.writeFailed
            }

            return
        }


        let count = self.limbs.count
        let countData = count.data

        try connection.write(countData, compression: true)

        for limb in self.limbs
        {
            try connection.write(UInt64(limb).maybeNetworkData!, compression: true)
        }
    }
}

public enum BIntError: Error
{
    case conversionFailed
    case writeFailed
    case readFailed
}
