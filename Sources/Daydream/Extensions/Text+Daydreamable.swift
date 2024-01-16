//
//  String+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/12/24.
//

import Foundation

import BigNumber
import Text
import Transmission

extension Text: Daydreamable
{
    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        let string = try String(daydream: connection)
        let temp = Text(fromUTF8String: string)
        self = temp
    }

    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        if self.string.isEmpty
        {
            guard connection.write(data: Data(array: [0x00])) else
            {
                throw BIntError.writeFailed
            }

            return
        }

        try self.string.saveDaydream(connection)
    }
}
