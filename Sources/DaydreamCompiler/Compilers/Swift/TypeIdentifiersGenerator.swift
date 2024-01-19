//
//  TypeIdentifiersGenerator.swift
//
//
//  Created by Dr. Brandon Wiley on 1/7/24.
//

import Foundation

import Gardener
import Text

import Daydream

extension SwiftCompiler
{
    func writeTypeIdentifiers(_ inputName: Text, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        let outputPath = outputDirectory.appending(path: "TypeIdentifiers.swift")

        let template = """
        //
        //  TypeIdentifiers.swift
        //
        //
        //  Created by the Daydream Compiler on \(Date()).
        //

        import Foundation

        import BigNumber
        import Datable
        import Daydream
        import SwiftHexTools
        import Text
        import Transmission

        public enum TypeIdentifiers: Int
        {
            public var bint: BInt
            {
                return BInt(self.rawValue)
            }

            public init?(bint: BInt)
            {
                guard let int = bint.asInt() else
                {
                    return nil
                }

                self.init(rawValue: int)
            }

        \(self.generateTypeIdentifiersCases(builtins, identifiers))
        }

        extension TypeIdentifiers: Daydreamable
        {
            public init(daydream connection: Transmission.Connection) throws
            {
                let bint = try BInt(daydream: connection)

                guard let type = Self(bint: bint) else
                {
                    throw DaydreamError.conversionFailed
                }

                self = type
            }

            public func saveDaydream(_ connection: Transmission.Connection) throws
            {
                try self.bint.saveDaydream(connection)
            }
        }

        public enum Value: Equatable, Codable
        {
        \(try self.generateTypeDefinitionCases(builtins, identifiers, namespace))
        }

        \(try self.generateStructs(identifiers, namespace))

        \(try self.generateDatables(identifiers, namespace))

        public enum DaydreamError: Error
        {
            case conversionFailed
            case readFailed
            case writeFailed
        }
        """

        let data = template.data
        try data.write(to: outputPath)
    }

    func generateTypeIdentifiersCases(_ builtins: [Identifier], _ identifiers: [Identifier]) -> String
    {
        let builtinCases = builtins.map
        {
            builtin in

            "    case \(builtin.name)Type = \(builtin.identifier)"
        }.joined(separator: "\n")

        let identifierCases = identifiers.map
        {
            identifier in

            "    case \(identifier.name)Type = \(identifier.identifier)"
        }.joined(separator: "\n")

        return """
        \(builtinCases)
        \(identifierCases)
        """
    }

    func generateTypeDefinitionCases(_ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace) throws -> String
    {
        return try identifiers.map
        {
            identifier in

            if identifier.name == "Varint"
            {
                return "    case Varint(BInt)"
            }

            guard let definition = namespace.bindings[identifier.name] else
            {
                throw DaydreamCompilerError.doesNotExist(identifier.name.string)
            }

            switch definition
            {
                case .SingletonType(name: let name):
                    return "    case \(name)"

                case .Record(name: let name, fields: _):
                    return "    case \(name)(\(name)Value)"

                case .Enum(name: let name, cases: _):
                    return "    case \(name)(\(name)Value)"

                case .List(name: let name, type: let type):
                    guard let listDefinition = namespace.bindings[type] else
                    {
                        throw DaydreamCompilerError.doesNotExist(type.string)
                    }

                    switch listDefinition
                    {
                        case .Builtin(name: _):
                            return "    case \(name)([\(type)])"

                        default:
                            if type == "Varint"
                            {
                                return "    case \(name)([BInt])"
                            }
                            else
                            {
                                return "    case \(name)([\(type)Value])"
                            }
                    }

                case .Builtin(name: let name, representation: _):
                    return "    case \(name)Builtin(\(name))"
            }
        }.joined(separator: "\n")
    }

    func generateStructs(_ identifiers: [Identifier], _ namespace: Namespace) throws -> String
    {
        return try identifiers.compactMap
        {
            identifier in

            if identifier.name == "Varint"
            {
                return nil
            }

            guard let definition = namespace.bindings[identifier.name] else
            {
                throw DaydreamCompilerError.doesNotExist(identifier.name.string)
            }

            switch definition
            {
                case .SingletonType(name: _):
                    return nil

                case .Builtin(name: _):
                    return nil

                case .Record(name: let name, fields: let fields):
                    return """
                    public struct \(name)Value: Equatable, Codable, Daydreamable
                    {
                        // Public computed properties
                        public func saveDaydream(_ connection: Transmission.Connection) throws
                        {
                    \(self.structToDaydream(name, fields))
                        }

                        // Public Fields
                    \(try fields.enumerated().map
                    {
                        index, type in

                        if type == "This"
                        {
                            return "    public let field\(index+1): \(name)"
                        }
                        else if type == "Varint"
                        {
                            return "    public let field\(index+1): BInt"
                        }
                        else
                        {
                            guard let fieldDefinition = namespace.bindings[type] else
                            {
                                throw DaydreamCompilerError.doesNotExist(identifier.name.string)
                            }

                            switch fieldDefinition
                            {
                                case .List(name: _, type: let listType):
                                    guard let subtype = namespace.bindings[listType] else
                                    {
                                        throw DaydreamCompilerError.doesNotExist(listType.string)
                                    }

                                    let typeName: String
                                    switch subtype
                                    {
                                        case .Builtin(name: _, representation: _):
                                            typeName = "[\(listType)]"

                                        default:
                                            typeName = "[\(listType)Value]"
                                    }

                                    return "    public let field\(index+1): \(typeName)"

                                case .Builtin(name: _, representation: _):
                                    return "    public let field\(index+1): \(type)"

                                default:
                                    return "    public let field\(index+1): \(type)Value"
                            }
                        }
                    }.joined(separator: "\n")
                    )

                        // Public Inits
                        public init(daydream connection: Transmission.Connection) throws
                        {
                    \(try self.daydreamToStruct(name, fields, namespace))
                        }

                        public init(\(try fields.enumerated().map
                        {
                            index, type in

                            if type == "This"
                            {
                                return "_ field\(index+1): \(name)"
                            }
                            else if type == "Varint"
                            {
                                return "_ field\(index+1): BInt"
                            }
                            else
                            {
                                guard let fieldDefinition = namespace.bindings[type] else
                                {
                                    throw DaydreamCompilerError.doesNotExist(identifier.name.string)
                                }

                                switch fieldDefinition
                                {
                                    case .List(name: _, type: let listType):
                                        guard let subtype = namespace.bindings[listType] else
                                        {
                                            throw DaydreamCompilerError.doesNotExist(listType.string)
                                        }

                                        let typeName: String
                                        switch subtype
                                        {
                                            case .Builtin(name: _, representation: _):
                                                typeName = "[\(listType)]"

                                            default:
                                                typeName = "[\(listType)Value]"
                                        }

                                        return "_ field\(index+1): \(typeName)"

                                    case .Builtin(name: _, representation: _):
                                        return "_ field\(index+1): \(type)"

                                    default:
                                        return "_ field\(index+1): \(type)Value"
                                }
                            }
                        }.joined(separator: ", ")))
                        {
                    \(fields.enumerated().map { index, type in "        self.field\(index+1) = field\(index+1)"}.joined(separator: "\n"))
                        }
                    }
                    """

                case .Enum(name: let name, cases: let cases):
                    return try """
                    public enum \(name)Value: Equatable, Codable, Daydreamable
                    {
                        public func saveDaydream(_ connection: Transmission.Connection) throws
                        {
                            switch self
                            {
                    \(cases.map
                      {
                        name in

                        guard let subtype = namespace.bindings[name] else
                        {
                            throw DaydreamCompilerError.doesNotExist(name.string)
                        }

                        switch subtype
                        {
                            case .SingletonType(name: _):
                                return """
                                            case .\(name):
                                                try TypeIdentifiers.\(name)Type.saveDaydream(connection)
                                """

                            case .Builtin(name: _, representation: _):
                                return """
                                            case .\(name)Value(let subtype):
                                                try TypeIdentifiers.\(name)Type.saveDaydream(connection)
                                                try subtype.saveDaydream(connection)
                                """

                            case .Record(name: _, fields: _):
                                return """
                                            case .\(name)(let subtype):
                                                try TypeIdentifiers.\(name)Type.saveDaydream(connection)
                                                try subtype.saveDaydream(connection)
                                """

                            case .Enum(name: _, cases: _):
                                return """
                                            case .\(name)(let subtype):
                                                try TypeIdentifiers.\(name)Type.saveDaydream(connection)
                                                try subtype.saveDaydream(connection)
                                """

                            case .List(name: _, type: _):
                                return """
                                            case .\(name)(let subtype):
                                                try TypeIdentifiers.\(name)Type.saveDaydream(connection)
                                                try subtype.saveDaydream(connection)
                                """
                        }
                      }.joined(separator: "\n\n")
                     )
                            }
                        }

                        public init(daydream connection: Transmission.Connection) throws
                        {
                            let bint = try BInt(daydream: connection)

                            guard let int = bint.asInt() else
                            {
                                throw DaydreamError.conversionFailed
                            }

                            guard let type = TypeIdentifiers(rawValue: int) else
                            {
                                throw DaydreamError.conversionFailed
                            }

                            switch type
                            {
                    \(cases.map
                      {
                        name in

                        guard let subtype = namespace.bindings[name] else
                        {
                            throw DaydreamCompilerError.doesNotExist(name.string)
                        }

                        switch subtype
                        {
                            case .SingletonType(name: _):
                                return """
                                            case .\(name)Type:
                                                self = .\(name)
                                """

                            case .Builtin(name: _, representation: _):
                                return """
                                            case .\(name)Type:
                                                let value = try \(name)(daydream: connection)
                                                self = .\(name)Value(value)
                                """

                            case .Record(name: _, fields: _):
                                return """
                                            case .\(name)Type:
                                                let value = try \(name)Value(daydream: connection)

                                                self = .\(name)(value)
                                                return
                                """

                            case .Enum(name: _, cases: _):
                                return """
                                            case .\(name)Type:
                                                let value = try \(name)Value(daydream: connection)

                                                self = .\(name)(value)
                                                return
                                """

                            case .List(name: _, type: _):
                                return """
                                            case .\(name)Type:
                                                result.append(\(name).daydream)
                                """
                        }
                      }.joined(separator: "\n\n")
                     )

                                default:
                                    throw DaydreamError.conversionFailed
                            }
                        }

                    \(cases.map
                    {
                        type in

                        guard let subtype = namespace.bindings[type] else
                        {
                            throw DaydreamCompilerError.doesNotExist(type.string)
                        }

                        switch subtype
                        {
                            case .SingletonType(name: _):
                                return "    case \(type)"

                            case .Builtin(name: _, representation: _):
                                return "    case \(type)Value(\(type))"

                            case .Record(name: _, fields: _):
                                return "    case \(type)(\(type)Value)"

                            case .Enum(name: _, cases: _):
                                return "    case \(type)(\(type)Value)"

                            case .List(name: _, type: let subtype):
                                if subtype == "Varint"
                                {
                                    return "    case \(type)([BInt])"
                                }
                                else
                                {
                                    return "    case \(type)([\(type)Value])"
                                }
                        }
                    }.joined(separator: "\n"))
                    }
                    """

                case .List(name: _, type: _):
                    return ""
            }
        }.joined(separator: "\n\n")
    }

    func structToDaydream(_ name: Text, _ fields: [Text]) -> String
    {
        if fields.count == 1
        {
            let type = fields[0]

            if type == "Varint"
            {
                return """
                    try self.field1.varint.saveDaydream(connection)
                """
            }
            else if type == "Data"
            {
                return """
                    try self.field1.saveDaydream(connection)
                """
            }
            else
            {
                return """
                    try self.field1.saveDaydream(connection)
                """
            }
        }
        else
        {
            return fields.enumerated().map
            {
                index, type in

                if type == "Varint"
                {
                    return """
                            try self.field\(index+1).saveDaydream(connection)
                    """
                }
                else
                {
                    return """
                            try self.field\(index+1).saveDaydream(connection)
                    """
                }
            }
            .joined(separator: "\n")
        }
    }

    func daydreamToStruct(_ name: Text, _ fields: [Text], _ namespace: Namespace) throws -> String
    {
        if fields.count == 1
        {
            let type = fields[0]

            guard let subtype = namespace.bindings[type] else
            {
                throw DaydreamCompilerError.doesNotExist(name.string)
            }

            let typeName: Text
            switch subtype
            {
                case .Builtin(name: _, representation: _):
                    typeName = type

                case .List(name: _, type: let type):
                    guard let listDefinition = namespace.bindings[type] else
                    {
                        throw DaydreamCompilerError.doesNotExist(type.string)
                    }

                    switch listDefinition
                    {
                        case .Builtin(name: _):
                            typeName = "[\(type)]".text

                        default:
                            if type == "Varint"
                            {
                                typeName = "[BInt]".text
                            }
                            else
                            {
                                typeName = "[\(type)Value]".text
                            }
                    }

                default:
                    typeName = "\(type)Value".text
            }

            if type == "Varint"
            {
                return """
                        let fieldValue = try BInt(daydream: connection)
                        self.field1 = fieldValue
                """
            }
            else
            {
                if typeName == "Data"
                {
                    return """
                            self.field1 = try Data(daydream: connection)
                    """
                }
                else if typeName == "String"
                {
                    return """
                            self.field1 = try \(typeName)(daydream: connection)
                    """
                }
                else
                {
                    return """
                            self.field1 = try \(typeName)(daydream: connection)
                    """
                }
            }
        }
        else
        {
            return try fields.enumerated().map
            {
                index, type in

                guard let subtype = namespace.bindings[type] else
                {
                    throw DaydreamCompilerError.doesNotExist(name.string)
                }

                let canonicalTypeName: Text
                if type == "Varint"
                {
                    canonicalTypeName = "BInt"

                    return """
                            self.field\(index+1) = try BInt(daydream: connection)
                    """
                }
                else
                {
                    switch subtype
                    {
                        case .List(name: _, type: let listType):
                            canonicalTypeName = Text(fromUTF8String: "[\(listType)Value]")

                        case .Builtin(name: _, representation: _):
                            canonicalTypeName = "\(type)".text

                        default:
                            canonicalTypeName = Text(fromUTF8String: "\(type)Value")
                    }

                    return """
                            self.field\(index+1) = try \(canonicalTypeName)(daydream: connection)
                    """
                }
            }.joined(separator: "\n")
        }
    }

    func generateDatables(_ identifiers: [Identifier], _ namespace: Namespace) throws -> String
    {
        return """
        extension Value: Daydreamable
        {
            public func saveDaydream(_ connection: Transmission.Connection) throws
            {
                switch self
                {
        \(
            try identifiers.compactMap
            {
                identifier in

                if identifier.name == "Varint"
                {
                    return """
                                case .Varint(let bignum):
                                    try TypeIdentifiers.VarintType.saveDaydream(connection)
                                    try bignum.saveDaydream(connection)
                    """
                }

                guard let definition = namespace.bindings[identifier.name] else
                {
                    throw DaydreamCompilerError.doesNotExist(identifier.name.string)
                }

                switch definition
                {
                    case .SingletonType(name: _):
                        return """
                                    case .\(identifier.name):
                                        try TypeIdentifiers.\(identifier.name)Type.saveDaydream(connection)
                        """

                    case .Builtin(name: _, representation: _):
                        return """
                                    case .\(identifier.name)Builtin(let subtype):
                                        try TypeIdentifiers.\(identifier.name)Type.saveDaydream(connection)
                                        try subtype.saveDaydream(connection)
                        """


                    case .Record(name: _, fields: _):
                        return """
                                    case .\(identifier.name)(let subtype):
                                        try TypeIdentifiers.\(identifier.name)Type.saveDaydream(connection)
                                        try subtype.saveDaydream(connection)
                        """

                    case .Enum(name: _, cases: _):
                        return """
                                    case .\(identifier.name)(let subtype):
                                        try TypeIdentifiers.\(identifier.name)Type.saveDaydream(connection)
                                        try subtype.saveDaydream(connection)
                        """

                    case .List(name: _, type: _):
                        return """
                                    case .\(identifier.name)(let subtype):
                                        try TypeIdentifiers.\(identifier.name)Type.saveDaydream(connection)
                                        try subtype.saveDaydream(connection)
                        """
                }
            }.joined(separator: "\n\n")
        )
                }
            }

            public init(daydream connection: Transmission.Connection) throws
            {
                let type = try TypeIdentifiers(daydream: connection)

                switch type
                {
        \(
            try identifiers.compactMap
            {
                identifier in

                if identifier.name == "Varint"
                {
                    return """
                                case .VarintType:
                                    let bignum = try BInt(daydream: connection)
                                    self = .Varint(bignum)
                    """
                }

                guard let definition = namespace.bindings[identifier.name] else
                {
                    throw DaydreamCompilerError.doesNotExist(identifier.name.string)
                }

                switch definition
                {
                    case .SingletonType(name: _):
                        return """
                                    case .\(identifier.name)Type:
                                        self = .\(identifier.name)
                        """

                    case .Builtin(name: _, representation: _):
                        if identifier.name == "Data"
                        {
                            return """
                                        case .\(identifier.name)Type:
                                            let subtype = try Data(daydream: connection)
                                            self = .\(identifier.name)Builtin(subtype)
                            """
                        }
                        else if identifier.name == "String"
                        {
                            return """
                                        case .\(identifier.name)Type:
                                            self = .\(identifier.name)Builtin(try \(identifier.name)(daydream: connection))
                            """
                        }
                        else
                        {
                            return """
                                        case .\(identifier.name)Type:
                                            let subtype = try \(identifier.name)(daydream: connection)
                                            self = .\(identifier.name)Builtin(subtype)
                            """
                        }

                    case .Record(name: _, fields: _):
                        return """
                                    case .\(identifier.name)Type:
                                        let subtype = try \(identifier.name)Value(daydream: connection)
                                        self = .\(identifier.name)(subtype)
                        """

                    case .Enum(name: _, cases: _):
                        return """
                                    case .\(identifier.name)Type:
                                        let subtype = try \(identifier.name)Value(daydream: connection)
                                        self = .\(identifier.name)(subtype)
                        """

                    case .List(name: _, type: _):
                        let typeName = try self.canonicalName(definition, namespace)

                        return """
                                    case .\(identifier.name)Type:
                                        let subtype = try \(typeName)(daydream: connection)
                                        self = .\(identifier.name)(subtype)
                        """
                }
            }.joined(separator: "\n\n")
        )

                    default:
                        throw DaydreamError.conversionFailed
                }
            }
        }
        """
    }

    public func canonicalName(_ type: TypeDefinition, _ namespace: Namespace) throws -> Text
    {
        switch type
        {
            case .Builtin(name: let name, representation: _):
                return "\(name)Builtin".text

            case .Enum(name: let name, cases: _):
                return "\(name)Value".text

            case .SingletonType(name: let name):
                return "\(name)".text

            case .Record(name: let name, fields: _):
                return "\(name)Value".text

            case .List(name: _, type: let listType):
                if listType == "Varint"
                {
                    return "[BInt]".text
                }
                else
                {
                    guard let subtype = namespace.bindings[listType] else
                    {
                        throw DaydreamCompilerError.doesNotExist(listType.string)
                    }

                    switch subtype
                    {
                        case .Builtin(name: _, representation: _):
                            return "[\(listType)]".text

                        default:
                            return "[\(listType)Value]".text
                    }
                }
        }
    }

}
