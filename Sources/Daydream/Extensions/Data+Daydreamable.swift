//
//  Data+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

//
//  String+Daydreamable.swift
//
//
//  Created by Dr. Brandon Wiley on 1/12/24.
//

import Foundation

import BigNumber
import Transmission

extension Data: Daydreamable
{
    public init(daydream connection: TransmissionTypes.Connection) throws
    {
        let data = try connection.read(compression: false)
        self = data
    }

    public func saveDaydream(_ connection: TransmissionTypes.Connection) throws
    {
        try connection.write(self, compression: false)
    }
}
