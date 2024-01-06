//
//  SwiftCompiler.swift
//  
//
//  Created by Dr. Brandon Wiley on 12/23/23.
//

import Foundation

import Gardener
import Text

import Daydream

public class SwiftCompiler
{
    func compile(_ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        print("Builtins:")
        for builtin in builtins
        {
            print(builtin)
        }

        print("====================")

        print("Identifiers:")
        for identifier in identifiers
        {
            print(identifier)
        }

        print("====================")

        print("Saving to \(outputDirectory)")

        try self.writeTypeIdentifiers(builtins, identifiers, namespace, outputDirectory)
    }

    func writeTypeIdentifiers(_ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
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
        import SwiftHexTools
        import Text

        extension Bool: MaybeDatable
        {
            public var data: Data
            {
                if self
                {
                    return UInt8(0).data
                }
                else
                {
                    return UInt8(1).data
                }
            }

            public init?(data: Data)
            {
                guard data.count == 1 else
                {
                    return nil
                }

                if data.count == 0
                {
                    self = false
                }
                else if data.count == 1
                {
                    self = true
                }
                else
                {
                    return nil
                }
            }
        }

        extension Data
        {
            public func popVarint() -> (BInt, Data)?
            {
                var working: Data = data

                guard working.count > 0 else
                {
                    return nil
                }

                guard let firstByte = working.first else
                {
                    return nil
                }
                working = working.dropFirst()

                let count = Int(firstByte)

                guard working.count >= count else
                {
                    return nil
                }

                let next: Data
                if count == 1
                {
                    guard let first = working.first else
                    {
                        return nil
                    }

                    next = Data(array: [first])

                    working = working.dropFirst()
                }
                else
                {
                    next = Data(working[0..<count])
                    working = Data(working[count...])
                }

                let varintBytes = Data(array: [firstByte] + next)
                guard let bint = BInt(varint: varintBytes) else
                {
                    return nil
                }

                return (bint, working)
            }

            public func popLength() -> (Int, Data)?
            {
                guard let (bint, rest) = self.popVarint() else
                {
                    return nil
                }

                guard let int = bint.asInt() else
                {
                    return nil
                }

                return (int, rest)
            }

            public func popLengthAndSlice() -> (Data, Data)?
            {
                guard let (length, rest) = self.popLength() else
                {
                    return nil
                }

                guard length <= rest.count else
                {
                    return nil
                }

                let head = Data(rest[0..<length])
                let tail = Data(rest[length...])

                return (head, tail)
            }

            public func pushVarint(bint: BInt) -> Data
            {
                return bint.varint + self
            }

            public func pushLength() -> Data
            {
                let bint = BInt(self.count)
                return self.pushVarint(bint: bint)
            }
        }

        public enum TypeIdentifiers: Int
        {
            public var varint: Data
            {
                let bint = BInt(self.rawValue)
                return bint.varint
            }

            public init?(varint: Data)
            {
                guard let bint = BInt(varint: varint) else
                {
                    return nil
                }

                guard let int = bint.asInt() else
                {
                    return nil
                }

                self.init(rawValue: int)
            }

        \(self.generateTypeIdentifiersCases(builtins, identifiers))
        }

        public enum Value: Equatable, Codable
        {
        \(try self.generateTypeDefinitionCases(builtins, identifiers, namespace))
        }

        \(try self.generateStructs(identifiers, namespace))

        \(try self.generateDatables(identifiers, namespace))
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
                    public struct \(name)Value: Equatable, Codable
                    {
                        // Public computed properties
                        public var data: Data
                        {
                            return \(self.structToData(name, fields))
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
                        public init?(data: Data)
                        {
                            var working: Data = data

                    \(try self.dataToStruct(name, fields, namespace))

                            working = Data()
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
                    public enum \(name)Value: Equatable, Codable
                    {
                        public var data: Data
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
                                                return TypeIdentifiers.\(name)Type.varint
                                """

                            case .Builtin(name: _, representation: _):
                                return """
                                            case .\(name):
                                                return TypeIdentifiers.\(name)Type.varint
                                """

                            case .Record(name: _, fields: _):
                                return """
                                            case .\(name)(let subtype):
                                                return TypeIdentifiers.\(name)Type.varint + subtype.data
                                """

                            case .Enum(name: _, cases: _):
                                return """
                                            case .\(name)(let subtype):
                                                return TypeIdentifiers.\(name)Type.varint + subtype.data
                                """

                            case .List(name: _, type: _):
                                return """
                                            case .\(name)(let subtype):
                                                return TypeIdentifiers.\(name)Type.varint + subtype.data
                                """
                        }
                      }.joined(separator: "\n\n")
                     )
                            }
                        }

                        public init?(data: Data)
                        {
                            guard let (bint, rest) = data.popVarint() else
                            {
                                return nil
                            }

                            guard let int = bint.asInt() else
                            {
                                return nil
                            }

                            guard let type = TypeIdentifiers(rawValue: int) else
                            {
                                return nil
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
                                                guard rest.isEmpty else
                                                {
                                                    return nil
                                                }

                                                self = .\(name)
                                """

                            case .Builtin(name: _, representation: _):
                                return """
                                            case .\(name)Type:
                                                guard rest.isEmpty else
                                                {
                                                    return nil
                                                }

                                                self = .\(name)
                                """

                            case .Record(name: _, fields: _):
                                return """
                                            case .\(name)Type:
                                                guard let value = \(name)Value(data: rest) else
                                                {
                                                    return nil
                                                }

                                                self = .\(name)(value)
                                                return
                                """

                            case .Enum(name: _, cases: _):
                                return """
                                            case .\(name)Type:
                                                guard let value = \(name)Value(data: rest) else
                                                {
                                                    return nil
                                                }

                                                self = .\(name)(value)
                                                return
                                """

                            case .List(name: _, type: _):
                                return """
                                            case .\(name)Type:
                                                result.append(\(name).data)
                                """
                        }
                      }.joined(separator: "\n\n")
                     )

                                default:
                                    return nil
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
                                return "    case \(type)"

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

                case .List(name: let name, type: let type):
                    let typeName: String
                    if type == "Varint"
                    {
                        typeName = "BInt"
                    }
                    else
                    {
                        guard let subtype = namespace.bindings[type] else
                        {
                            throw DaydreamCompilerError.doesNotExist(type.string)
                        }

                        switch subtype
                        {
                            case .Builtin(name: _, representation: _):
                                typeName = type.string

                            default:
                                typeName = "\(type)Value"
                        }
                    }

                    return """
                    extension [\(typeName)]
                    {
                        public var data: Data
                        {
                            var result: Data = Data()
                            result.append(TypeIdentifiers.\(name)Type.varint)
                            result.append(BInt(self.count).varint)

                            for item in self
                            {
                                result.append(item.data)
                            }

                            return result
                        }

                        public init?(data: Data)
                        {
                            var results: [\(typeName)] = []
                            var working = data

                            while working.count > 0
                            {
                                guard let (valueData, rest) = working.popLengthAndSlice() else
                                {
                                    self = results
                                    return
                                }

                                guard let value = \(typeName)(data: valueData) else
                                {
                                    return nil
                                }

                                results.append(value)
                                working = rest
                            }

                            self = results
                        }
                    }
                    """
            }
        }.joined(separator: "\n\n")
    }

    func structToData(_ name: Text, _ fields: [Text]) -> String
    {
        if fields.count == 1
        {
            let type = fields[0]

            if type == "Varint"
            {
                return "self.field1.varint"
            }
            else if type == "Data"
            {
                return "self.field1"
            }
            else
            {
                return "self.field1.data"
            }
        }
        else
        {
            return fields.enumerated().map
            {
                index, type in

                if type == "Varint"
                {
                    return "self.field\(index+1).varint.pushLength()"
                }
                else
                {
                    return "self.field\(index+1).data.pushLength()"
                }
            }
            .joined(separator: " + ")
        }
    }

    func dataToStruct(_ name: Text, _ fields: [Text], _ namespace: Namespace) throws -> String
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
                        guard let fieldValue = BInt(varint: working) else
                        {
                            return nil
                        }

                        self.field1 = fieldValue
                """
            }
            else
            {
                if typeName == "Data"
                {
                    return """
                            self.field1 = working
                    """
                }
                else if typeName == "String"
                {
                    return """
                            self.field1 = \(typeName)(data: working)
                    """
                }
                else
                {
                    return """
                            guard let fieldValue = \(typeName)(data: working) else
                            {
                                return nil
                            }

                            self.field1 = fieldValue
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
                                            guard let (payload\(index+1), rest\(index+1)) = working.popLengthAndSlice() else
                                            {
                                                return nil
                                            }

                                            guard let fieldValue\(index+1) = BInt(varint: payload\(index+1)) else
                                            {
                                                return nil
                                            }

                                            self.field\(index+1) = fieldValue\(index+1)
                                            working = rest\(index+1)
                                    """
                }
                else
                {
                    switch subtype
                    {
                        case .List(name: _, type: let listType):
                            canonicalTypeName = Text(fromUTF8String: "[\(listType)Value]")

                        default:
                            canonicalTypeName = Text(fromUTF8String: "\(type)Value")
                    }

                    return """
                                            guard let (payload\(index+1), rest\(index+1)) = working.popLengthAndSlice() else
                                            {
                                                return nil
                                            }

                                            guard let fieldValue\(index+1) = \(canonicalTypeName)(data: payload\(index+1)) else
                                            {
                                                return nil
                                            }

                                            self.field\(index+1) = fieldValue\(index+1)
                                            working = rest\(index+1)
                                    """
                }
            }.joined(separator: "\n\n")
        }
    }

    func generateDatables(_ identifiers: [Identifier], _ namespace: Namespace) throws -> String
    {
        return """
        extension Value
        {
            public var data: Data
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
                                    let typeData = TypeIdentifiers.VarintType.varint
                                    let valueData = bignum.varint
                                    return typeData + valueData
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
                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
                                        return typeData
                        """

                    case .Builtin(name: _, representation: _):
                        return """
                                    case .\(identifier.name)Builtin(let subtype):
                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
                                        let valueData = subtype.data
                                        return typeData + valueData
                        """


                    case .Record(name: _, fields: _):
                        return """
                                    case .\(identifier.name)(let subtype):
                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
                                        let valueData = subtype.data
                                        print("typeData: \\(typeData.hex)")
                                        print("valueData: \\(valueData.hex)")
                                        return typeData + valueData
                        """

                    case .Enum(name: _, cases: _):
                        return """
                                    case .\(identifier.name)(let subtype):
                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
                                        let valueData = subtype.data
                                        print("typeData: \\(typeData.hex)")
                                        print("valueData: \\(valueData.hex)")
                                        return typeData + valueData
                        """

                    case .List(name: _, type: _):
                        return """
                                    case .\(identifier.name)(let subtype):
                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
                                        let valueData = subtype.data
                                        return typeData + valueData
                        """
                }
            }.joined(separator: "\n\n")
        )
                }
            }

            public init?(data: Data)
            {
                guard let (bint, working) = data.popVarint() else
                {
                    return nil
                }

                guard let int = bint.asInt() else
                {
                    return nil
                }

                guard let type = TypeIdentifiers(rawValue: int) else
                {
                    return nil
                }

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
                                    guard let bignum = BInt(varint: working) else
                                    {
                                        return nil
                                    }

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
                                            self = .\(identifier.name)Builtin(working)
                            """
                        }
                        else if identifier.name == "String"
                        {
                            return """
                                        case .\(identifier.name)Type:
                                            self = .\(identifier.name)Builtin(\(identifier.name)(data: working))
                            """
                        }
                        else
                        {
                            return """
                                        case .\(identifier.name)Type:
                                            guard let subtype = \(identifier.name)(data: working) else
                                            {
                                                return nil
                                            }
                                            self = .\(identifier.name)Builtin(subtype)
                            """
                        }

                    case .Record(name: _, fields: _):
                        return """
                                    case .\(identifier.name)Type:
                                        guard let subtype = \(identifier.name)Value(data: working) else
                                        {
                                            return nil
                                        }
                                        self = .\(identifier.name)(subtype)
                        """

                    case .Enum(name: _, cases: _):
                        return """
                                    case .\(identifier.name)Type:
                                        guard let subtype = \(identifier.name)Value(data: working) else
                                        {
                                            return nil
                                        }
                                        self = .\(identifier.name)(subtype)
                        """

                    case .List(name: _, type: _):
                        let typeName = try self.canonicalName(definition, namespace)

                        return """
                                    case .\(identifier.name)Type:
                                        guard let subtype = \(typeName)(data: working) else
                                        {
                                            return nil
                                        }
                                        self = .\(identifier.name)(subtype)
                        """
                }
            }.joined(separator: "\n\n")
        )

                    default:
                        return nil
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

public enum SwiftCompilerError: Error
{
}
