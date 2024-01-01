////
////  GoCompiler.swift
////  
////
////  Created by Dr. Brandon Wiley on 12/23/23.
////
//
//import Foundation
//
//import Gardener
//import Text
//
//import Daydream
//
//public class GoCompiler
//{
//    func compile(_ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
//    {
//        try self.writeTypeIdentifiers(builtins, identifiers, namespace, outputDirectory)
//    }
//
//    func writeTypeIdentifiers(_ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
//    {
//        let outputPath = outputDirectory.appending(path: "TypeIdentifiers.swift")
//
//        let template = """
//        //
//        //  types.go
//        //
//        //
//        //  Created by the Daydream Compiler on \(Date()).
//        //
//
//        import (
//            "encoding/binary"
//            "enoding/hex"
//            "fmt"
//            "math/big"
//        )
//
//        func New(varint []byte) *TypeIdentifier {
//            (bint, _) := PopVarint(varint)
//
//            uint64 := bint.UInt64()
//            return uint64
//        }
//
//        public enum TypeIdentifier: Int
//        {
//            \(self.generateTypeIdentifiersCases(builtins, identifiers))
//        }
//
//        public var varint: Data
//        {
//            let bint = BInt(self.rawValue)
//            return bint.varint
//        }
//
//        public init?(varint: Data)
//        {
//            guard let bint = BInt(varint: varint) else
//            {
//                return nil
//            }
//
//            guard let int = bint.asInt() else
//            {
//                return nil
//            }
//
//            self.init(rawValue: int)
//        }
//
//        public enum Value: Equatable, Codable
//        {
//        \(try self.generateTypeDefinitionCases(builtins, identifiers, namespace))
//        }
//
//        \(try self.generateStructs(identifiers, namespace))
//
//        \(try self.generateDatables(identifiers, namespace))
//        """
//
//        let data = template.data
//        try data.write(to: outputPath)
//    }
//
//    func generateVarintUtilities() -> String
//    {
//        return """
//        func PopVarint(data []byte) (*Int, []byte)
//        {
//            working := data
//
//            if (len(working) == 0) {
//                var result Int
//                return result
//            }
//
//            firstByte := working[0]
//            working = working[1:]
//
//            count := int(firstByte)
//
//            if (count < 0) {
//                return null
//            }
//
//            if (count > 8) {
//                return null
//            }
//
//            if (count == 0) {
//                var result Int
//                return result
//            }
//
//            if len(working) < count {
//                return null
//            }
//
//            gap := 8 - count
//
//            uint64Bytes := make([]byte, 8)
//            copy(uint64Bytes[gap:], working[0:count])
//            working := working[count:]
//
//            uint64 := binary.BigEndian.Uint64(uint64Bytes)
//            bint := NewInt(uint64)
//
//            return (&bint, working)
//        }
//        """
//    }
//
//    func generateTypeIdentifiersCases(_ builtins: [Identifier], _ identifiers: [Identifier]) -> String
//    {
//        let builtinCases = builtins.map
//        {
//            builtin in
//
//            "    case \(builtin.name)Type = \(builtin.identifier)"
//        }.joined(separator: "\n")
//
//        let identifierCases = identifiers.map
//        {
//            identifier in
//
//            "    case \(identifier.name)Type = \(identifier.identifier)"
//        }.joined(separator: "\n")
//
//        return """
//        \(builtinCases)
//        \(identifierCases)
//        """
//    }
//
//    func generateTypeDefinitionCases(_ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace) throws -> String
//    {
//        return try identifiers.map
//        {
//            identifier in
//
//            if identifier.name == "Varint"
//            {
//                return "    case Varint(BInt)"
//            }
//
//            guard let definition = namespace.bindings[identifier.name] else
//            {
//                throw DaydreamCompilerError.doesNotExist(identifier.name.string)
//            }
//
//            switch definition
//            {
//                case .SingletonType(name: let name):
//                    return "    case \(name)"
//
//                case .Record(name: let name, fields: _):
//                    return "    case \(name)(\(name)Value)"
//
//                case .Enum(name: let name, cases: _):
//                    return "    case \(name)(\(name)Value)"
//
//                case .List(name: let name, type: let type):
//                    return "    case \(name)([\(type)Value])"
//            }
//        }.joined(separator: "\n")
//    }
//
//    func generateStructs(_ identifiers: [Identifier], _ namespace: Namespace) throws -> String
//    {
//        return try identifiers.compactMap
//        {
//            identifier in
//
//            if identifier.name == "Varint"
//            {
//                return nil
//            }
//
//            guard let definition = namespace.bindings[identifier.name] else
//            {
//                throw DaydreamCompilerError.doesNotExist(identifier.name.string)
//            }
//
//            switch definition
//            {
//                case .SingletonType(name: _):
//                    return nil
//
//                case .Record(name: let name, fields: let fields):
//                    return """
//                    public struct \(name)Value: Equatable, Codable
//                    {
//                        // Public computed properties
//                        public var data: Data
//                        {
//                            return \(self.structToData(name, fields))
//                        }
//
//                        // Public Fields
//                    \(try fields.enumerated().map
//                    {
//                        index, type in
//
//                        if type == "This"
//                        {
//                            return "    public let field\(index+1): \(name)"
//                        }
//                        else if type == "Varint"
//                        {
//                            return "    public let field\(index+1): BInt"
//                        }
//                        else
//                        {
//                            guard let fieldDefinition = namespace.bindings[type] else
//                            {
//                                throw DaydreamCompilerError.doesNotExist(identifier.name.string)
//                            }
//
//                            switch fieldDefinition
//                            {
//                                case .List(name: _, type: let listType):
//                                    return "    public let field\(index+1): [\(listType)Value]"
//
//                                default:
//                                    return "    public let field\(index+1): \(type)Value"
//                            }
//                        }
//                    }.joined(separator: "\n")
//                    )
//
//                        // Public Inits
//                        public init?(data: Data)
//                        {
//                            var working: Data = data
//
//                    \(try self.dataToStruct(name, fields, namespace))
//                        }
//
//                        public init(\(try fields.enumerated().map
//                        {
//                            index, type in
//
//                            if type == "This"
//                            {
//                                return "_ field\(index+1): \(name)"
//                            }
//                            else if type == "Varint"
//                            {
//                                return "_ field\(index+1): BInt"
//                            }
//                            else
//                            {
//                                guard let fieldDefinition = namespace.bindings[type] else
//                                {
//                                    throw DaydreamCompilerError.doesNotExist(identifier.name.string)
//                                }
//
//                                switch fieldDefinition
//                                {
//                                    case .List(name: _, type: let listType):
//                                        return "_ field\(index+1): [\(listType)Value]"
//
//                                    default:
//                                        return "_ field\(index+1): \(type)Value"
//                                }
//                            }
//                        }.joined(separator: ", ")))
//                        {
//                    \(fields.enumerated().map { index, type in "        self.field\(index+1) = field\(index+1)"}.joined(separator: "\n"))
//                        }
//                    }
//                    """
//
//                case .Enum(name: let name, cases: let cases):
//                    return try """
//                    public enum \(name)Value: Equatable, Codable
//                    {
//                        public var data: Data
//                        {
//                            switch self
//                            {
//                    \(cases.map
//                      {
//                        name in
//
//                        guard let subtype = namespace.bindings[name] else
//                        {
//                            throw DaydreamCompilerError.doesNotExist(name.string)
//                        }
//
//                        switch subtype
//                        {
//                            case .SingletonType(name: _):
//                                return """
//                                            case .\(name):
//                                                return TypeIdentifiers.\(name)Type.varint
//                                """
//
//                            case .Record(name: _, fields: _):
//                                return """
//                                            case .\(name)(let subtype):
//                                                return TypeIdentifiers.\(name)Type.varint + subtype.data
//                                """
//
//                            case .Enum(name: _, cases: _):
//                                return """
//                                            case .\(name)(let subtype):
//                                                return TypeIdentifiers.\(name)Type.varint + subtype.data
//                                """
//
//                            case .List(name: _, type: _):
//                                return """
//                                            case .\(name)(let subtype):
//                                                return TypeIdentifiers.\(name)Type.varint + subtype.data
//                                """
//                        }
//                      }.joined(separator: "\n\n")
//                     )
//                            }
//                        }
//
//                        public init?(data: Data)
//                        {
//                            guard let (bint, rest) = data.popVarint() else
//                            {
//                                return nil
//                            }
//
//                            guard let int = bint.asInt() else
//                            {
//                                return nil
//                            }
//
//                            guard let type = TypeIdentifiers(rawValue: int) else
//                            {
//                                return nil
//                            }
//
//                            switch type
//                            {
//                    \(cases.map
//                      {
//                        name in
//
//                        guard let subtype = namespace.bindings[name] else
//                        {
//                            throw DaydreamCompilerError.doesNotExist(name.string)
//                        }
//
//                        switch subtype
//                        {
//                            case .SingletonType(name: _):
//                                return """
//                                            case .\(name)Type:
//                                                self = .\(name)
//                                """
//
//                            case .Record(name: _, fields: _):
//                                return """
//                                            case .\(name)Type:
//                                                guard let value = \(name)Value(data: rest) else
//                                                {
//                                                    return nil
//                                                }
//
//                                                self = .\(name)(value)
//                                                return
//                                """
//
//                            case .Enum(name: _, cases: _):
//                                return """
//                                            case .\(name)Type:
//                                                guard let value = \(name)Value(data: rest) else
//                                                {
//                                                    return nil
//                                                }
//
//                                                self = .\(name)(value)
//                                                return
//                                """
//
//                            case .List(name: _, type: _):
//                                return """
//                                            case .\(name)Type:
//                                                result.append(\(name).data)
//                                """
//                        }
//                      }.joined(separator: "\n\n")
//                     )
//
//                                default:
//                                    return nil
//                            }
//                        }
//
//                    \(cases.map
//                    {
//                        type in
//
//                        guard let subtype = namespace.bindings[type] else
//                        {
//                            throw DaydreamCompilerError.doesNotExist(type.string)
//                        }
//
//                        switch subtype
//                        {
//                            case .SingletonType(name: _):
//                                return "    case \(type)"
//
//                            case .Record(name: _, fields: _):
//                                return "    case \(type)(\(type)Value)"
//
//                            case .Enum(name: _, cases: _):
//                                return "    case \(type)(\(type)Value)"
//
//                            case .List(name: _, type: _):
//                                return "    case \(type)([\(type)Value])"
//                        }
//                    }.joined(separator: "\n"))
//                    }
//                    """
//
//                case .List(name: let name, type: let type):
//                    return """
//                    extension [\(type)Value]
//                    {
//                        public var data: Data
//                        {
//                            var result: Data = Data()
//                            result.append(TypeIdentifiers.\(name)Type.varint)
//                            result.append(BInt(self.count).varint)
//
//                            for item in self
//                            {
//                                result.append(item.data)
//                            }
//
//                            return result
//                        }
//
//                        public init?(data: Data)
//                        {
//                            var results: [\(type)Value] = []
//                            var working = data
//
//                            while working.count > 0
//                            {
//                                guard let (valueData, rest) = working.popLengthAndSlice() else
//                                {
//                                    self = results
//                                    return
//                                }
//
//                                guard let value = \(type)Value(data: valueData) else
//                                {
//                                    return nil
//                                }
//
//                                results.append(value)
//                                working = rest
//                            }
//
//                            self = results
//                        }
//                    }
//                    """
//            }
//        }.joined(separator: "\n\n")
//    }
//
//    func structToData(_ name: Text, _ fields: [Text]) -> String
//    {
//        if fields.count == 1
//        {
//            let type = fields[0]
//
//            if type == "Varint"
//            {
//                return "self.field1.varint"
//            }
//            else
//            {
//                return "self.field1.data"
//            }
//        }
//        else
//        {
//            return fields.enumerated().map
//            {
//                index, type in
//
//                if type == "Varint"
//                {
//                    return "self.field\(index+1).varint.pushLength()"
//                }
//                else
//                {
//                    return "self.field\(index+1).data.pushLength()"
//                }
//            }
//            .joined(separator: " + ")
//        }
//    }
//
//    func dataToStruct(_ name: Text, _ fields: [Text], _ namespace: Namespace) throws -> String
//    {
//        if fields.count == 1
//        {
//            let type = fields[0]
//
//            if type == "Varint"
//            {
//                return """
//                        guard let fieldValue = BInt(varint: working) else
//                        {
//                            return nil
//                        }
//
//                        self.field1 = fieldValue
//                        working = Data()
//                """
//            }
//            else
//            {
//                return """
//                        guard let fieldValue = \(type)Value(data: working) else
//                        {
//                            return nil
//                        }
//
//                        self.field1 = fieldValue
//                        working = Data()
//                """
//            }
//        }
//        else
//        {
//            return try fields.enumerated().map
//            {
//                index, type in
//
//                guard let subtype = namespace.bindings[type] else
//                {
//                    throw DaydreamCompilerError.doesNotExist(name.string)
//                }
//
//                let canonicalTypeName: Text
//                if type == "Varint"
//                {
//                    canonicalTypeName = "BInt"
//
//                    return """
//                                            guard let (payload\(index+1), rest\(index+1)) = working.popLengthAndSlice() else
//                                            {
//                                                return nil
//                                            }
//
//                                            guard let fieldValue\(index+1) = BInt(varint: payload\(index+1)) else
//                                            {
//                                                return nil
//                                            }
//
//                                            self.field\(index+1) = fieldValue\(index+1)
//                                            working = rest\(index+1)
//                                    """
//                }
//                else
//                {
//                    switch subtype
//                    {
//                        case .List(name: _, type: let listType):
//                            canonicalTypeName = Text(fromUTF8String: "[\(listType)Value]")
//
//                        default:
//                            canonicalTypeName = Text(fromUTF8String: "\(type)Value")
//                    }
//
//                    return """
//                                            guard let (payload\(index+1), rest\(index+1)) = working.popLengthAndSlice() else
//                                            {
//                                                return nil
//                                            }
//
//                                            guard let fieldValue\(index+1) = \(canonicalTypeName)(data: payload\(index+1)) else
//                                            {
//                                                return nil
//                                            }
//
//                                            self.field\(index+1) = fieldValue\(index+1)
//                                            working = rest\(index+1)
//                                    """
//                }
//            }.joined(separator: "\n\n")
//        }
//    }
//
//    func generateDatables(_ identifiers: [Identifier], _ namespace: Namespace) throws -> String
//    {
//        return """
//        extension Value
//        {
//            public var data: Data
//            {
//                switch self
//                {
//        \(
//            try identifiers.compactMap
//            {
//                identifier in
//
//                if identifier.name == "Varint"
//                {
//                    return """
//                                case .Varint(let bignum):
//                                    let typeData = TypeIdentifiers.VarintType.varint
//                                    let valueData = bignum.varint
//                                    return typeData + valueData
//                    """
//                }
//
//                guard let definition = namespace.bindings[identifier.name] else
//                {
//                    throw DaydreamCompilerError.doesNotExist(identifier.name.string)
//                }
//
//                switch definition
//                {
//                    case .SingletonType(name: _):
//                        return """
//                                    case .\(identifier.name):
//                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
//                                        return typeData
//                        """
//
//                    case .Record(name: _, fields: _):
//                        return """
//                                    case .\(identifier.name)(let subtype):
//                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
//                                        let valueData = subtype.data
//                                        print("typeData: \\(typeData.hex)")
//                                        print("valueData: \\(valueData.hex)")
//                                        return typeData + valueData
//                        """
//
//                    case .Enum(name: _, cases: _):
//                        return """
//                                    case .\(identifier.name)(let subtype):
//                                        let typeData = TypeIdentifiers.\(identifier.name)Type.varint
//                                        let valueData = subtype.data
//                                        print("typeData: \\(typeData.hex)")
//                                        print("valueData: \\(valueData.hex)")
//                                        return typeData + valueData
//                        """
//
//                    case .List(name: _, type: _):
//                        return """
//                                    case .\(identifier.name):
//                                        return self.data.pushLength()
//                        """
//                }
//            }.joined(separator: "\n\n")
//        )
//                }
//            }
//
//            public init?(data: Data)
//            {
//                guard let (bint, working) = data.popVarint() else
//                {
//                    return nil
//                }
//
//                guard let int = bint.asInt() else
//                {
//                    return nil
//                }
//
//                guard let type = TypeIdentifiers(rawValue: int) else
//                {
//                    return nil
//                }
//
//                switch type
//                {
//        \(
//            try identifiers.compactMap
//            {
//                identifier in
//
//                if identifier.name == "Varint"
//                {
//                    return """
//                                case .VarintType:
//                                    guard let bignum = BInt(varint: working) else
//                                    {
//                                        return nil
//                                    }
//
//                                    self = .Varint(bignum)
//                    """
//                }
//
//                guard let definition = namespace.bindings[identifier.name] else
//                {
//                    throw DaydreamCompilerError.doesNotExist(identifier.name.string)
//                }
//
//                switch definition
//                {
//                    case .SingletonType(name: _):
//                        return """
//                                    case .\(identifier.name)Type:
//                                        self = .\(identifier.name)
//                        """
//
//                    case .Record(name: _, fields: _):
//                        return """
//                                    case .\(identifier.name)Type:
//                                        guard let subtype = \(identifier.name)Value(data: working) else
//                                        {
//                                            return nil
//                                        }
//                                        self = .\(identifier.name)(subtype)
//                        """
//
//                    case .Enum(name: _, cases: _):
//                        return """
//                                    case .\(identifier.name)Type:
//                                        guard let subtype = \(identifier.name)Value(data: working) else
//                                        {
//                                            return nil
//                                        }
//                                        self = .\(identifier.name)(subtype)
//                        """
//
//                    case .List(name: _, type: let listType):
//                        return """
//                                        guard let subtype = [\(listType)Value](data: working) else
//                                        {
//                                            return nil
//                                        }
//                                        self = .\(identifier.name)(subtype)
//                        """
//                }
//            }.joined(separator: "\n\n")
//        )
//
//                    default:
//                        return nil
//                }
//            }
//        }
//        """
//    }
//
//}
//
//public enum GoCompilerError: Error
//{
//}
