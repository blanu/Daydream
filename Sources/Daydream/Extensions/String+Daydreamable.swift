//
//  String+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/12/24.
//

import Foundation

import BigNumber
import Transmission

extension String: Daydreamable
{
    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        let scalars = try [Unicode.Scalar](daydream: connection)

        var temp: String = ""
        for scalar in scalars
        {
            temp.unicodeScalars.append(scalar)
        }

        self = temp
    }

    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        if self.isEmpty
        {
            guard connection.write(data: Data(array: [0x00])) else
            {
                throw BIntError.writeFailed
            }

            return
        }

        let scalars = [Unicode.Scalar](self.unicodeScalars)
        try scalars.saveDaydream(connection)
    }
}
