//
//  Bool+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

import BigNumber
import Transmission

// FIXME - support negative integers
extension Bool: Daydreamable
{
    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        guard let data = connection.read(size: 1) else
        {
            throw BoolError.readFailed
        }

        if data[0] == 1
        {
            self = true
        }
        else if data[0] == 0
        {
            self = false
        }
        else
        {
            throw BoolError.conversionFailed
        }
    }

    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        let data = Data(array: [self ? 1 : 0])
        guard connection.write(data: data) else
        {
            throw BoolError.conversionFailed
        }
    }
}

public enum BoolError: Error
{
    case conversionFailed
    case readFailed
    case writeFailed
}
