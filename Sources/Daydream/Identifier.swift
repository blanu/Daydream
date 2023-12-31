//
//  Identifier.swift
//
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import Foundation

import Text

public struct Identifier
{
    public let name: Text
    public let identifier: Int

    public init(name: Text, identifier: Int)
    {
        self.name = name
        self.identifier = identifier
    }
}
