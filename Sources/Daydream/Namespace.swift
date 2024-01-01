//
//  Namespace.swift
//
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import Foundation

import Text

public class Namespace
{
    public var bindings: [Text: TypeDefinition] = [:]

    public init()
    {
    }

    public init(types: [TypeDefinition]) throws
    {
        for type in types
        {
            switch type
            {
                case .SingletonType(name: let name):
                    if let oldDefinition = self.bindings[name]
                    {
                        print("Duplicate binding: \(name)")
                        print("New definition: \(type)")
                        print("Old definition: \(oldDefinition)")
                        throw NamespaceError.duplicateBindings(name, type, oldDefinition)
                    }

                    self.bindings[name] = type

                case .Record(name: let name, fields: _):
                    if let oldDefinition = self.bindings[name]
                    {
                        print("Duplicate binding: \(name)")
                        print("New definition: \(type)")
                        print("Old definition: \(oldDefinition)")
                        throw NamespaceError.duplicateBindings(name, type, oldDefinition)
                    }

                    self.bindings[name] = type

                case .Enum(name: let name, cases: _):
                    if let oldDefinition = self.bindings[name]
                    {
                        print("Duplicate binding: \(name)")
                        print("New definition: \(type)")
                        print("Old definition: \(oldDefinition)")
                        throw NamespaceError.duplicateBindings(name, type, oldDefinition)
                    }

                    self.bindings[name] = type

                case .List(name: let name, type: _):
                    if let oldDefinition = self.bindings[name]
                    {
                        print("Duplicate binding: \(name)")
                        print("New definition: \(type)")
                        print("Old definition: \(oldDefinition)")
                        throw NamespaceError.duplicateBindings(name, type, oldDefinition)
                    }

                    self.bindings[name] = type

                case .Builtin(name: let name):
                    if let oldDefinition = self.bindings[name]
                    {
                        print("Duplicate binding: \(name)")
                        print("New definition: \(type)")
                        print("Old definition: \(oldDefinition)")
                        throw NamespaceError.duplicateBindings(name, type, oldDefinition)
                    }

                    self.bindings[name] = type
            }
        }

        try self.validate()
    }

    public func bind(name: Text, definition: TypeDefinition)
    {
        self.bindings[name] = definition
    }

    public func validate() throws
    {
        var validated = Set<Text>()

        for name in self.bindings.keys
        {
            try validate(name, &validated)
        }
    }

    func validate(_ name: Text, _ validated: inout Set<Text>) throws
    {
        if validated.contains(name)
        {
            return
        }

        guard let value = self.bindings[name] else
        {
            throw NamespaceError.undefinedType(name)
        }

        switch value
        {
            case .SingletonType(name: _):
                validated.insert(name)
                return

            case .Record(name: _, fields: let fields):
                validated.insert(name)
                for field in fields
                {
                    try self.validate(field, &validated)
                }

            case .Enum(name: _, cases: let enumCases):
                validated.insert(name)
                for enumCase in enumCases
                {
                    try self.validate(enumCase, &validated)
                }

            case .List(name: _, type: let type):
                validated.insert(name)
                try self.validate(type, &validated)

            case .Builtin(name: _):
                validated.insert(name)
                return
        }
    }

    public func sorted() -> [Text]
    {
        let keys = [Text](self.bindings.keys)
        return keys.sorted()
    }

    public func save(_ url: URL) throws
    {
        var result: String = ""

        let keys = self.sorted()
        for key in keys
        {
            if let definition = self.bindings[key]
            {
                result.append("\(definition.description)\n")
            }
        }

        let data = result.data
        try data.write(to: url)
    }
}

public enum NamespaceError: Error
{
    case duplicateBindings(Text, TypeDefinition, TypeDefinition) // name, old, new
    case undefinedType(Text)
    case templatesNotAllowedHere
}
