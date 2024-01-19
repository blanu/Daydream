//
//  ClientGenerator.swift
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
    func writeClient(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        let outputPath = outputDirectory.appending(path: "\(inputName)Client.swift")

        let requestName = inputName.text
        guard let requestEnum = namespace.bindings[requestName] else
        {
            throw ServiceGeneratorError.notFound(requestName)
        }

        let template = """
        //
        //  \(inputName)Client.swift
        //
        //
        //  Created by the Daydream Compiler on \(Date()).
        //

        import Foundation
        import Logging

        import BigNumber
        import Datable
        import RadioWave
        import SwiftHexTools
        import Text

        public struct \(inputName)Client
        {
            let logger: Logger
            let connection: Connection<\(inputName)RequestValue, \(inputName)ResponseValue>

            public init(host: String, port: Int, logger: Logger) throws
            {
                self.logger = logger
                self.connection = try Connection<\(inputName)RequestValue, \(inputName)ResponseValue>(host: host, port: port, logger: logger)
            }

        \(try self.generateClientCases(inputName.text, requestEnum, identifiers, namespace))
        }

        public enum \(inputName)ClientError: Error
        {
            case serviceError(String)
            case wrongReturnType
        }
        """

        let data = template.data
        try data.write(to: outputPath)
    }

    func generateClientCases(_ inputName: Text, _ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace) throws -> Text
    {
        switch requestEnum
        {
            case .Enum(name: _, cases: let cases):
                return try cases.map
                {
                    enumCase in

                    return try self.generateClientEnumCase(inputName, enumCase, namespace, "\(enumCase)_request".text)
                }.joined(separator: "\n\n").text

            default:
                throw ClientGeneratorError.badFormat
        }
    }

    func generateClientEnumCase(_ inputName: Text, _ functionName: Text, _ namespace: Namespace, _ enumCase: Text) throws -> String
    {
        let argumentsTypeName = "\(functionName)_request".text
        let argumentsType = try namespace.resolve(argumentsTypeName)

        let returnTypeName = "\(functionName)_response".text

        switch argumentsType
        {
            case .SingletonType(name: _):
                return try self.generateZeroArgumentsCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Enum(name: _, cases: _):
                return try self.generateOneArgumentCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .List(name: _, type: _):
                return try self.generateOneArgumentCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Builtin(name: _, representation: _):
                return try self.generateOneArgumentCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Record(name: _, fields: let fields):
                guard fields.count > 0 else
                {
                    throw ClientGeneratorError.badFormat
                }

                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            return try self.generateOneArgumentCase(inputName, namespace, functionName, fieldType, returnTypeName, enumCase)

                        case .Enum(name: _, cases: _):
                            return try self.generateOneArgumentCase(inputName, namespace, functionName, fieldType, returnTypeName, enumCase)

                        case .List(name: _, type: _):
                            return try self.generateOneArgumentCase(inputName, namespace, functionName, fieldType, returnTypeName, enumCase)

                        case .Record(name: _, fields: let fields):
                            if fields.count == 1
                            {
                                return try self.generateOneArgumentCase(inputName, namespace, functionName, fieldType, returnTypeName, enumCase)
                            }
                            else
                            {
                                return try self.generateSeveralArgumentsCase(inputName, namespace, functionName, fieldType, returnTypeName, enumCase)
                            }

                        case .SingletonType(name: _):
                            return try self.generateOneArgumentCase(inputName, namespace, functionName, fieldType, returnTypeName, enumCase)
                    }
                }
                else
                {
                    return try self.generateSeveralArgumentsCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
        }
    }

    func generateZeroArgumentsCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let returnType = try namespace.resolve(returnTypeName)

        switch returnType
        {
            case .SingletonType(name: _):
                return try self.generateZeroArgumentsNoReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Builtin(name: _, representation: _):
                return try self.generateZeroArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Enum(name: _, cases: let cases):
                if cases == ["Nothing", "Error"]
                {
                    return try self.generateZeroArgumentsNoReturnThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
                else if cases.contains("Error")
                {
                    return try self.generateZeroArgumentsReturnThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
                else
                {
                    return try self.generateZeroArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }

            case .List(name: _, type: let listType):
                return try self.generateZeroArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, "\(listType)List".text, enumCase)

            case .Record(name: _, fields: _):
                return try self.generateZeroArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
        }
    }

    func generateOneArgumentCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let returnType = try namespace.resolve(returnTypeName)

        switch returnType
        {
            case .SingletonType(name: _):
                return try self.generateOneArgumentNoReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Builtin(name: _, representation: _):
                return try self.generateOneArgumentReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Enum(name: _, cases: let cases):
                if cases == ["Nothing", "Error"]
                {
                    return try self.generateOneArgumentNoReturnThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
                else if cases.contains("Error")
                {
                    return try self.generateOneArgumentReturnThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
                else
                {
                    return try self.generateOneArgumentReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }

            case .List(name: _, type: let listType):
                return try self.generateOneArgumentReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, "\(listType)List".text, enumCase)

            case .Record(name: _, fields: _):
                return try self.generateOneArgumentReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
        }
    }

    func generateSeveralArgumentsCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let returnType = try namespace.resolve(returnTypeName)

        switch returnType
        {
            case .SingletonType(name: _):
                return try self.generateSeveralArgumentsNoReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Builtin(name: _, representation: _):
                return try self.generateSeveralArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)

            case .Enum(name: _, cases: let cases):
                if cases == ["Nothing", "Error"]
                {
                    return try self.generateSeveralArgumentsNoReturnThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
                else if cases.contains("Error")
                {
                    return try self.generateSeveralArgumentsReturnThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }
                else
                {
                    return try self.generateSeveralArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
                }

            case .List(name: _, type: let listType):
                return try self.generateSeveralArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, "\(listType)List".text, enumCase)

            case .Record(name: _, fields: _):
                return try self.generateSeveralArgumentsReturnNoThrowingCase(inputName, namespace, functionName, argumentsType, returnTypeName, enumCase)
        }
    }

    func generateZeroArgumentsNoReturnNoThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        return """
            // f()
            public func \(functionName)() throws
            {
                let request = \(inputName)RequestValue.\(functionName)_request
                let result = try self.connection.call(request)
                switch result
                {
                    case .\(functionName)_response:
                        return

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateZeroArgumentsNoReturnThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        return """
            // f() throws
            public func \(functionName)() throws
            {
                let request = \(inputName)RequestValue.\(functionName)_request
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let maybeError):
                        switch maybeError
                        {
                            case .Nothing:
                                return

                            case .Error(let error):
                                throw \(inputName)ClientError.serviceError(error.field1)
                        }

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateZeroArgumentsReturnNoThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        return """
            // f() -> T
            public func \(functionName)() throws -> \(functionName)_responseValue
            {
                let request = \(inputName)RequestValue.\(functionName)_request
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        return value

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateZeroArgumentsReturnThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let unwrappedReturnType = try self.unwrapReturnValueType(inputName, returnTypeName, functionName, namespace)

        let unwrappedReturn = try self.unwrapReturnValue(inputName, returnTypeName, functionName, namespace)

        return """
            // f() throws -> T
            public func \(functionName)() throws -> \(unwrappedReturnType)
            {
                let request = \(inputName)RequestValue.\(functionName)_request
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        \(unwrappedReturn)

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateOneArgumentNoReturnNoThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        return """
            // f(T)
            public func \(functionName)(\(try self.unwrapArguments("\(functionName)_request".text, namespace))) throws
            {
                let request = \(inputName)RequestValue.\(functionName)_request(\(try self.unwrapRequestArguments("\(functionName)_request".text, namespace)))
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response:
                        return

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateOneArgumentNoReturnThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let unwrappedReturn = try self.unwrapReturnValue(inputName, returnTypeName, functionName, namespace)

        return """
            // f(T) throws
            public func \(functionName)(\(try self.unwrapArguments("\(functionName)_request".text, namespace))) throws
            {
                let request = \(inputName)RequestValue.\(functionName)_request(\(try self.unwrapRequestArguments("\(functionName)_request".text, namespace)))
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        \(unwrappedReturn)

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateOneArgumentReturnNoThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let unwrappedReturnType = try self.unwrapReturnValueType(inputName, returnTypeName, functionName, namespace)

        let unwrappedReturn = try self.unwrapReturnValue(inputName, returnTypeName, functionName, namespace)

        return """
            // f(S) -> T
            public func \(functionName)(\(try self.unwrapArguments("\(functionName)_request".text, namespace))) throws -> \(unwrappedReturnType)
            {
                let request = \(inputName)RequestValue.\(enumCase)(\(try self.unwrapRequestArguments("\(functionName)_request".text, namespace)))
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        \(unwrappedReturn)

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateOneArgumentReturnThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let unwrappedReturnType = try self.unwrapReturnValueType(inputName, returnTypeName, functionName, namespace)

        let unwrappedReturn = try self.unwrapReturnValue(inputName, returnTypeName, functionName, namespace)

        return """
            // f(S) throws -> T
            public func \(functionName)(\(try self.unwrapArguments("\(functionName)_request".text, namespace))) throws -> \(unwrappedReturnType)
            {
                let requestValue = \(enumCase)Value(field0)
                let request = \(inputName)RequestValue.\(enumCase)(requestValue)
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        \(unwrappedReturn)

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateSeveralArgumentsNoReturnNoThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let parametersText: Text
        let argumentsText: Text

        let enumType = try namespace.resolve(enumCase)

        switch enumType
        {
            case .Record(name: _, fields: let fields):
                let parameters = fields.enumerated().map
                {
                    index, parameter in

                    return "_ parameter\(index): \(parameter)"
                }

                let parametersString = parameters.joined(separator: ", ")
                parametersText = parametersString.text

                let arguments = fields.enumerated().map
                {
                    index, argument in

                    return "_ parameter\(index): \(argument)"
                }

                let argumentsString = arguments.joined(separator: ", ")
                argumentsText = argumentsString.text

            default:
                throw ClientGeneratorError.badFormat
        }

        return """
            // f(S, ...)
            public func \(functionName)(\(parametersText)) throws -> \(functionName)_responeValue
            {
                let request = \(inputName)RequestValue.\(enumCase)_request(argumentsText)
                let result = try self.connection.call(\(argumentsText))

                switch result
                {
                    case .\(functionName)_response(let value):
                        return value

                    case .Error(let error):
                        throw \(inputName)ClientError.serviceError(error.field1)

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateSeveralArgumentsNoReturnThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let parametersText: Text
        let argumentsText: Text

        let enumType = try namespace.resolve(enumCase)

        switch enumType
        {
            case .Enum(name: _, cases: let cases):
                let parameters = cases.enumerated().map
                {
                    index, parameter in

                    return "_ parameter\(index): \(parameter)"
                }

                let parametersString = parameters.joined(separator: ", ")
                parametersText = parametersString.text

                let arguments = cases.enumerated().map
                {
                    index, argument in

                    return "_ parameter\(index): \(argument)"
                }

                let argumentsString = arguments.joined(separator: ", ")
                argumentsText = argumentsString.text

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field = fields[0]

                    let fieldType = try namespace.resolve(field)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            parametersText = "_ parameter0: \(field)".text
                            argumentsText = "_ parameter0: \(field)".text

                        case .Enum(name: _, cases: _):
                            parametersText = "_ parameter0: \(field)".text
                            argumentsText = "_ parameter0: \(field)".text

                        case .List(name: _, type: _):
                            parametersText = "_ parameter0: \(field)".text
                            argumentsText = "_ parameter0: \(field)".text

                        case .Record(name: _, fields: let subfields):
                            let parameters = subfields.enumerated().map
                            {
                                index, parameter in

                                return "_ parameter\(index): \(parameter)"
                            }

                            let parametersString = parameters.joined(separator: ", ")
                            parametersText = parametersString.text

                            let arguments = subfields.enumerated().map
                            {
                                index, argument in

                                return "parameter\(index)"
                            }

                            let argumentsString = arguments.joined(separator: ", ")
                            argumentsText = argumentsString.text

                        case .SingletonType(name: _):
                            throw ClientGeneratorError.badFormat
                    }
                }
                else
                {
                    let parameters = fields.enumerated().map
                    {
                        index, parameter in

                        return "_ parameter\(index): \(parameter)"
                    }

                    let parametersString = parameters.joined(separator: ", ")
                    parametersText = parametersString.text

                    let arguments = fields.enumerated().map
                    {
                        index, argument in

                        return "_ parameter\(index): \(argument)"
                    }

                    let argumentsString = arguments.joined(separator: ", ")
                    argumentsText = argumentsString.text
                }

            default:
                throw ClientGeneratorError.badFormat
        }

        return """
            // f(S, ...) throws
            public func \(functionName)(\(parametersText)) throws
            {
                let argumentsValue = \(functionName)_argumentsValue(\(argumentsText))
                let requestValue = \(functionName)_requestValue(argumentsValue)
                let request = \(inputName)RequestValue.\(enumCase)(requestValue)
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let response):
                        switch response
                        {
                            case .Nothing:
                                return

                            case .Error(let error):
                                throw \(inputName)ClientError.serviceError(error.field1)
                        }

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateSeveralArgumentsReturnNoThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let argumentsText: Text

        let enumType = try namespace.resolve(enumCase)

        switch enumType
        {
            case .Enum(name: _, cases: let cases):
                let arguments = cases.enumerated().map
                {
                    index, argument in

                    return "_ parameter\(index): \(argument)"
                }

                let argumentsString = arguments.joined(separator: ", ")
                argumentsText = argumentsString.text

            default:
                throw ClientGeneratorError.badFormat
        }

        return """
            // f(S, ...) -> T
            public func \(functionName)(\(try self.unwrapArguments("\(functionName)_request".text, namespace))) throws -> \(functionName)_responeValue
            {
                let argumentsValue = \(functionName)_argumentsValue(\(argumentsText))
                let requestValue = \(functionName)_requestValue(argumentsValue)
                let request = \(inputName)RequestValue.\(enumCase)(requestValue)
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        return value

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func generateSeveralArgumentsReturnThrowingCase(_ inputName: Text, _ namespace: Namespace, _ functionName: Text, _ argumentsType: TypeDefinition, _ returnTypeName: Text, _ enumCase: Text) throws -> String
    {
        let parametersText: Text
        let argumentsText: Text

        let enumType = try namespace.resolve(enumCase)

        switch enumType
        {
            case .Enum(name: _, cases: let cases):
                let parameters = cases.enumerated().map
                {
                    index, parameter in

                    return "_ parameter\(index): \(parameter)"
                }

                let parametersString = parameters.joined(separator: ", ")
                parametersText = parametersString.text

                let arguments = cases.enumerated().map
                {
                    index, argument in

                    return "_ parameter\(index): \(argument)"
                }

                let argumentsString = arguments.joined(separator: ", ")
                argumentsText = argumentsString.text

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field = fields[0]

                    let fieldType = try namespace.resolve(field)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            parametersText = "_ parameter0: \(field)".text
                            argumentsText = "_ parameter0: \(field)".text

                        case .Enum(name: _, cases: _):
                            parametersText = "_ parameter0: \(field)".text
                            argumentsText = "_ parameter0: \(field)".text

                        case .List(name: _, type: _):
                            parametersText = "_ parameter0: \(field)".text
                            argumentsText = "_ parameter0: \(field)".text

                        case .Record(name: _, fields: let subfields):
                            let parameters = subfields.enumerated().map
                            {
                                index, parameter in

                                return "_ parameter\(index): \(parameter)"
                            }

                            let parametersString = parameters.joined(separator: ", ")
                            parametersText = parametersString.text

                            let arguments = subfields.enumerated().map
                            {
                                index, argument in

                                return "parameter\(index)"
                            }

                            let argumentsString = arguments.joined(separator: ", ")
                            argumentsText = argumentsString.text

                        case .SingletonType(name: _):
                            throw ClientGeneratorError.badFormat
                    }
                }
                else
                {
                    let parameters = fields.enumerated().map
                    {
                        index, parameter in

                        return "_ parameter\(index): \(parameter)"
                    }

                    let parametersString = parameters.joined(separator: ", ")
                    parametersText = parametersString.text

                    let arguments = fields.enumerated().map
                    {
                        index, argument in

                        return "_ parameter\(index): \(argument)"
                    }

                    let argumentsString = arguments.joined(separator: ", ")
                    argumentsText = argumentsString.text
                }

            default:
                throw ClientGeneratorError.badFormat
        }

        let unwrappedReturnType = try self.unwrapReturnValueType(inputName, returnTypeName, functionName, namespace)

        return """
            // f(S, ...) throws -> T
            public func \(functionName)(\(parametersText)) throws -> \(unwrappedReturnType)
            {
                let argumentsValue = \(functionName)_argumentsValue(\(argumentsText))
                let requestValue = \(functionName)_requestValue(argumentsValue)
                let request = \(inputName)RequestValue.\(enumCase)(requestValue)
                let result = try self.connection.call(request)

                switch result
                {
                    case .\(functionName)_response(let value):
                        \(try self.unwrapReturnValue(inputName, returnTypeName, functionName, namespace))

                    default:
                        throw \(inputName)ClientError.wrongReturnType
                }
            }
        """
    }

    func wrapArguments(_ startingTypeNames: [Text], _ functionName: Text, _ namespace: Namespace) throws -> Text
    {
        let wrappedArguments = try startingTypeNames.enumerated().map
        {
            index, element in

            try self.wrapArgument(index, element, namespace)
        }.joined(separator: "\n")

        let fields = startingTypeNames.enumerated().map
        {
            index, _ in

            return "field\(index)"
        }.joined(separator: ", ")

        return (wrappedArguments + """
            let request = \(functionName).Request(\(fields))
        """).text
    }

    func unwrapArguments(_ startingTypeName: Text, _ namespace: Namespace) throws -> String
    {
        let type = try namespace.resolve(startingTypeName)

        switch type
        {
            case .Builtin(name: _, representation: _):
                return startingTypeName.string

            case .Enum(name: _, cases: _):
                return startingTypeName.string

            case .List(name: _, type: let listType):
                return "[\(listType)]"

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            return "_ field0: \(field0)"

                        case .Enum(name: _, cases: let cases):
                            if cases.contains("Error")
                            {
                                let enumCase = cases[0]

                                return "_ field0: \(enumCase)"
                            }
                            else if cases.contains("Nothing")
                            {
                                let enumCase = cases[0]

                                return "_ field0: \(enumCase)?"
                            }
                            else
                            {
                                return "_ field0: \(field0)"
                            }

                        case .List(name: _, type: let listType):
                            return "_ field0: [\(listType)]"

                        case .Record(name: _, fields: _):
                            return "_ field0: \(field0)"

                        case .SingletonType(name: _):
                            throw ClientGeneratorError.badFormat
                    }
                }
                else
                {
                    return fields.enumerated().map
                    {
                        index, text in

                        return "_ field\(index): \(text)"
                    }.joined(separator: ", ")
                }

            case .SingletonType(name: _):
                return ""
        }
    }

    func unwrapRequestArguments(_ startingTypeName: Text, _ namespace: Namespace) throws -> String
    {
        let type = try namespace.resolve(startingTypeName)

        switch type
        {
            case .Builtin(name: _, representation: _):
                return startingTypeName.string

            case .Enum(name: _, cases: _):
                return startingTypeName.string

            case .List(name: _, type: _):
                return startingTypeName.string

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            return "\(startingTypeName)Value(field0)"

                        case .Enum(name: _, cases: let cases):
                            if cases.contains("Nothing")
                            {
                                let case0 = cases[0]

                                let caseType = try namespace.resolve(case0)

                                switch caseType
                                {
                                    case .Builtin(name: _, representation: _):
                                        return "\(startingTypeName)Value(field0 == nil ? \(field0)Value.Nothing : \(field0)Value.\(case0)Value(field0!))"

                                    default:
                                        return "\(startingTypeName)Value(\(field0)Value.\(case0)(field0))"
                                }
                            }
                            else
                            {
                                return field0.string
                            }

                        case .List(name: _, type: _):
                            return "\(startingTypeName)Value(field0)"

                        case .Record(name: _, fields: _):
                            return field0.string

                        case .SingletonType(name: _):
                            throw ClientGeneratorError.badFormat
                    }
                }
                else
                {
                    let fieldsString = fields.enumerated().map
                    {
                        index, text in

                        return "field\(index)"
                    }.joined(separator: ", ")

                    return "\(startingTypeName)Value(\(fieldsString))"
                }

            case .SingletonType(name: _):
                return ""
        }
    }

    func wrapArgument(_ index: Int, _ startingTypeName: Text, _ namespace: Namespace) throws -> String
    {
        let type = try namespace.resolve(startingTypeName)

        switch type
        {
            case .Builtin(name: _, representation: _):
                return "let field\(index) = \(startingTypeName)Builtin(\(startingTypeName.string))"

            default:
                return "let field\(index) = \(startingTypeName)"
        }
    }

    func unwrapReturnValue(_ inputName: Text, _ startingTypeName: Text, _ functionName: Text, _ namespace: Namespace) throws -> String
    {
        let type = try namespace.resolve(startingTypeName)

        switch type
        {
            case .Builtin(name: _, representation: _):
                return """
                    switch response
                    {
                        case .\(functionName)_response(let value):
                            return value

                        default:
                            throw \(inputName)ClientError.wrongReturnType
                    }
                """

            case .Enum(name: _, cases: let cases):
                if cases == ["Nothing", "Error"]
                {
                    return """
                    switch value
                                {
                                    case .Error(let error):
                                        throw \(inputName)ClientError.serviceError(error.field1)

                                    default:
                                        throw \(inputName)ClientError.wrongReturnType
                                }
                    """
                }
                else if cases.contains("Error")
                {
                    return """
                    switch value
                                    {
                                        case .\(functionName)_response_value(let subvalue):
                                            return subvalue.field1

                                        case .Error(let error):
                                            throw \(inputName)ClientError.serviceError(error.field1)
                                    }
                    """
                }
                else
                {
                    return """
                    switch value
                                {
                                    case .\(functionName)_response_value(let subvalue):
                                        return subvalue.field1

                                    default:
                                        throw \(inputName)ClientError.wrongReturnType
                                }
                    """
                }

            case .List(name: _, type: _):
                return """
                    switch response
                    {
                        case .\(functionName)_response(let value):
                            return value

                        default:
                            throw \(inputName)ClientError.wrongReturnType
                    }
                """

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            return field0.string

                        case .Enum(name: _, cases: _):
                            return field0.string

                        case .List(name: _, type: _):
                            return """
                            return value.field1
                            """

                        case .Record(name: _, fields: let subfields):
                            if subfields.count == 1
                            {
                                let field0 = subfields[0]

                                let subtype = try namespace.resolve(field0)
                                switch subtype
                                {
                                    case .Builtin(name: _, representation: _):
                                        return """
                                        return value.field1.field1
                                        """

                                    case .Enum(name: _, cases: _):
                                        return field0.string

                                    case .List(name: _, type: _):
                                        return """
                                        return value.field1.field1
                                        """

                                    case .Record(name: _, fields: _):
                                        return field0.string

                                    case .SingletonType(name: _):
                                        return field0.string

                                }
                            }
                            else
                            {
                                return field0.string
                            }

                        case .SingletonType(name: _):
                            return field0.string
                    }
                }
                if fields == ["Nothing", "Error"]
                {
                    return """
                        switch response
                        {
                            case .\(functionName)_response:
                                return

                            case .Error(let error):
                                throw \(inputName)ClientError.serviceError(error.field1)

                            default:
                                throw \(inputName)ClientError.wrongReturnType
                        }
                    """
                }
                else if fields.contains("Error")
                {
                    return """
                        switch response
                        {
                            case .\(functionName)_response:
                                return

                            default:
                                throw \(inputName)ClientError.wrongReturnType
                        }
                    """
                }
                else
                {
                    return """
                    switch response
                                    {
                                        case .\(functionName)_response:
                                            return

                                        default:
                                            throw \(inputName)ClientError.wrongReturnType
                                    }
                    """
                }

            case .SingletonType(name: _):
                return """
                    switch response
                    {
                        case .\(functionName)_response:
                            return

                        default:
                            throw \(inputName)ClientError.wrongReturnType
                    }
                """
        }
    }

    func unwrapReturnValueType(_ inputName: Text, _ startingTypeName: Text, _ functionName: Text, _ namespace: Namespace) throws -> String
    {
        let type = try namespace.resolve(startingTypeName)

        switch type
        {
            case .Builtin(name: _, representation: _):
                return startingTypeName.string

            case .Enum(name: _, cases: let cases):
                if cases == ["Nothing", "Error"]
                {
                    return ""
                }
                else if cases.contains("Error")
                {
                    let firstCase = cases[0]
                    let firstType = try namespace.resolve(firstCase)

                    switch firstType
                    {
                        case .Builtin(name: _, representation: _):
                            return firstCase.string

                        case .Enum(name: _, cases: _):
                            return firstCase.string

                        case .List(name: _, type: _):
                            return firstCase.string

                        case .Record(name: _, fields: let fields):
                            if fields.count == 1
                            {
                                let field = fields[0]

                                let fieldType = try namespace.resolve(field)

                                switch fieldType
                                {
                                    case .Builtin(name: _, representation: _):
                                        return field.string

                                    case .Enum(name: _, cases: _):
                                        return field.string

                                    case .List(name: _, type: _):
                                        return field.string

                                    case .Record(name: _, fields: let subfields):
                                        if subfields.count == 1
                                        {
                                            let subfield = subfields[0]

                                            return subfield.string
                                        }
                                        else
                                        {
                                            return field.string
                                        }

                                    case .SingletonType(name: _):
                                        return field.string
                                }
                            }
                            else
                            {
                                return firstCase.string
                            }

                        case .SingletonType(name: _):
                            return firstCase.string
                    }
                }
                else
                {
                    return startingTypeName.string
                }

            case .List(name: _, type: let type):
                return "[\(type)]"

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]
                    let subtype = try namespace.resolve(field0)

                    switch subtype
                    {
                        case .Builtin(name: _, representation: _):
                            return field0.string

                        case .Enum(name: _, cases: _):
                            return field0.string

                        case .List(name: _, type: let listType):
                            return "[\(listType)]"

                        case .Record(name: _, fields: let subfields):
                            if subfields.count == 1
                            {
                                let subfield1 = subfields[0]

                                let subtype = try namespace.resolve(subfield1)

                                switch subtype
                                {
                                    case .Builtin(name: _, representation: _):
                                        return subfield1.string

                                    case .Enum(name: _, cases: _):
                                        return subfield1.string

                                    case .List(name: _, type: let listType):
                                        return "[\(listType.string)]"

                                    case .Record(name: _, fields: _):
                                        return subfield1.string

                                    case .SingletonType(name: _):
                                        throw ClientGeneratorError.badFormat
                                }
                            }
                            else
                            {
                                return field0.string
                            }

                        case .SingletonType(name: _):
                            return field0.string
                    }
                }
                else
                {
                    return "??? 1"
                }

            case .SingletonType(name: _):
                return ""
        }
    }
}

public enum ClientGeneratorError: Error
{
    case notFound(Text)
    case wrongType
    case badFormat
}
