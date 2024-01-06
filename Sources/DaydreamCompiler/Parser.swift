//
//  Parser.swift
//
//
//  Created by Dr. Brandon Wiley on 12/17/23.
//

import Foundation

import Text

import Daydream

public class Parser
{
    public func parse(_ text: Text) -> [TypeDefinition]
    {
        return text≡ ⇢ { try parseLine($0) }
    }

    func parseLine(_ line: Text) throws -> TypeDefinition
    {
        let (untrimmedName, definition) = try ⊩line.split(" ")
        guard try untrimmedName.last() == ":" else
        {
            throw ParserError.badName
        }
        let name = untrimmedName ∩ { $0 != ":" }

        let (kindString, rest) = try ⊩definition

        guard let kindType = Kind(rawValue: kindString) else
        {
            throw OperatorsError.badConversion
        }

        switch kindType
        {
            case .SingletonType:
                guard rest.count == 0 else
                {
                    throw ParserError.badArgumentCount
                }

                return TypeDefinition.SingletonType(name: name)

            case .Record:
                guard rest.count >= 1 else
                {
                    throw ParserError.badArgumentCount
                }

                return TypeDefinition.Record(name: name, fields: [Text](rest))

            case .Enum:
                guard rest.count >= 1 else
                {
                    throw ParserError.badArgumentCount
                }

                return TypeDefinition.Enum(name: name, cases: [Text](rest))

            case .List:
                guard rest.count == 1 else
                {
                    throw ParserError.badArgumentCount
                }

                guard let type = rest.first else
                {
                    throw ParserError.badArgumentCount
                }

                return TypeDefinition.List(name: name, type: type)

            case .Builtin:
                guard rest.count == 1 else
                {
                    throw ParserError.badArgumentCount
                }

                guard let type = rest.first else
                {
                    throw ParserError.badArgumentCount
                }

                return TypeDefinition.Builtin(name: name, representation: type)
        }
    }

    func substitute(_ item: Text, _ substitution: Text) -> Text
    {
        let token = "$\(item)"
        let changed = substitution.string.replacingOccurrences(of: token, with: substitution.string)
        return Text(fromUTF8String: changed)
    }
}

public enum ParserError: Error
{
    case badArgumentCount
    case badName
}
