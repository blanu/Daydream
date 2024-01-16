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

        let requestName = "\(inputName)Request".text
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

                    let argumentsType = try namespace.resolve(enumCase)

                    guard let functionName = enumCase.split("_").first else
                    {
                        throw ServiceGeneratorError.badFormat
                    }

                    let returnTypeName = "\(functionName)_response".text
                    let returnType = try namespace.resolve(returnTypeName)

                    switch argumentsType
                    {
                        case .SingletonType(name: _):
                            switch returnType
                            {
                                case .SingletonType(name: _):
                                    return """
                                        // f()
                                        public func \(functionName)() throws
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
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

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        return """
                                            // f() throws
                                            public func \(functionName)() throws
                                            {
                                                let request = \(inputName)RequestValue.\(enumCase)
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
                                    else if cases.contains("Error")
                                    {
                                        return """
                                        // f() throws -> T
                                        public func \(functionName)() throws -> \(functionName)_response_valueValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
                                            let result = try self.connection.call(request)

                                            switch result
                                            {
                                                case .\(functionName)_response(let maybeError):
                                                    switch maybeError
                                                    {
                                                        case .\(functionName)_response_value(let value):
                                                            return value

                                                        case .Error(let error):
                                                            throw \(inputName)ClientError.serviceError(error.field1)
                                                    }

                                                default:
                                                    throw \(inputName)ClientError.wrongReturnType
                                            }
                                        }
                                        """
                                    }
                                    else
                                    {
                                        return """
                                        // f() -> T
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
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

                                default:
                                    return """
                                        // f(S) -> T (1)
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
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

                        default:
                            switch returnType
                            {
                                case .SingletonType(name: _):
                                    return """
                                        // f(T)
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
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

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        return """
                                        // f(T) throws
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
                                            let result = try self.connection.call(request)

                                            switch result
                                            {
                                                case .\(functionName)_response(let value):
                                                    return value

                                                case .Error(let error):
                                                    throw \(inputName)ClientError.serviceError(error)

                                                default:
                                                    throw \(inputName)ClientError.wrongReturnType
                                            }          
                                        }
                                        """
                                    }
                                    else if cases.contains("Error")
                                    {
                                        return """
                                        // f(S) throws -> T
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
                                            let result = try self.connection.call(request)

                                            switch result
                                            {
                                                case .\(functionName)_response(let value):
                                                    return value

                                                case .Error(let error):
                                                    throw \(inputName)ClientError.serviceError(error)

                                                default:
                                                    throw \(inputName)ClientError.wrongReturnType
                                            }                              
                                        }
                                        """
                                    }
                                    else
                                    {
                                        return """
                                        // f(S) -> T (2)
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
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

                                default:
                                    return """
                                        // f(S) -> T (3)
                                        public func \(functionName)() throws -> \(functionName)_responseValue
                                        {
                                            let request = \(inputName)RequestValue.\(enumCase)
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
                    }
                }
                .joined(separator: "\n\n")
                .text

            default:
                throw ServiceGeneratorError.wrongType
        }
    }
}

public enum ClientGeneratorError: Error
{
    case notFound(Text)
    case wrongType
    case badFormat
}
