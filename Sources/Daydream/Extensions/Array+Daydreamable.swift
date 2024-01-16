//
//  Array+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

import Transmission

extension Array: Daydreamable where Self.Element: Daydreamable
{
    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        let limbCountData = try connection.read(compression: true)

        guard let limbCountUInt64 = UInt64(maybeNetworkData: limbCountData) else
        {
            throw ArrayError.conversionFailed
        }

        let count = Int(limbCountUInt64)

        guard count > 0 else
        {
            self = []
            return
        }

        var temp: Self = []
        for _ in 0..<count
        {
            let element = try Self.Element(daydream: connection)
            temp.append(element)
        }

        self = temp
    }

    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        if self.isEmpty
        {
            guard connection.write(data: Data(array: [0x00])) else
            {
                throw ArrayError.writeFailed
            }

            return
        }

        let countData = UInt64(self.count).maybeNetworkData!

        try connection.write(countData, compression: true)

        for element in self
        {
            try element.saveDaydream(connection)
        }
    }
}

public enum ArrayError: Error
{
    case conversionFailed
    case writeFailed
    case readFailed
}
