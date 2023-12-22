//
//  WordZie.swift
//
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import Foundation

public enum WordSize: UInt8
{
    case byte = 1
    case short = 2
    case int = 4
    case long = 8
}

extension WordSize
{
    public var max: Int
    {
        switch self
        {
            case .byte:
                return Int(UInt8.max)

            case .short:
                return Int(UInt16.max)

            case .int:
                return Int(Int.max)

            case .long:
                return Int(Int.max)
        }
    }
}

extension WordSize
{
    public var typeName: String
    {
        switch self
        {
            case .byte:
                return "UInt8"

            case .short:
                return "UInt16"

            case .int:
                return "UInt32"

            case .long:
                return "UInt64"
        }
    }
}
