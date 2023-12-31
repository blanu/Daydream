//
//  Kind.swift
//
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import Foundation

import Text

public enum Kind: Text
{
    case SingletonType = "Singleton"
    case Record        = "Record"
    case Enum          = "Enum"
    case List          = "List"
}

public indirect enum TypeDefinition
{
    case SingletonType(name: Text)
    case Record(name: Text, fields: [Text])
    case Enum(name: Text, cases: [Text])
    case List(name: Text, type: Text)
}

extension TypeDefinition: CustomStringConvertible
{
    public var description: String
    {
        switch self
        {
            case .SingletonType(name: let name):
                return "\(name): Singleton"

            case .Record(name: let name, fields: let fields):
                let fieldsString = Text.join(fields, " ")
                return "\(name): Record \(fieldsString)"

            case .Enum(name: let name, cases: let cases):
                let casesString = Text.join(cases, " ")
                return "\(name): Enum \(casesString)"

            case .List(name: let name, type: let type):
                return "\(name): List \(type)"
        }
    }
}

public struct Type
{
    let name: Text
    let definition: TypeDefinition
}
