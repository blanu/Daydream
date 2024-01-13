//
//  ServiceGenerator.swift
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
    func writeService(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        let outputPath = outputDirectory.appending(path: "\(inputName)Service.swift")

        let requestName = "\(inputName)Request".text
        guard let requestEnum = namespace.bindings[requestName] else
        {
            throw ServiceGeneratorError.notFound(requestName)
        }

        let template = """
        //
        //  \(inputName)Service.swift
        //
        //
        //  Created by the Daydream Compiler on \(Date()).
        //

        import ArgumentParser
        import Foundation
        import Logging

        import BigNumber
        import Datable
        import RadioWave
        import SwiftHexTools
        import Text

        public struct \(inputName)Service
        {
            let logic: \(inputName)Logic
            let stdio: StdioService<\(inputName)RequestValue, \(inputName)ResponseValue, \(inputName)Logic>
            let logger: Logger

            public init(logger: Logger) throws
            {
                self.logger = logger

                self.logic = \(inputName)Logic(logger: logger)
                self.stdio = try StdioService<\(inputName)RequestValue, \(inputName)ResponseValue, \(inputName)Logic>(handler: logic, logger: logger)
            }
        }

        public struct \(inputName)Logic: Logic
        {
            public typealias Request = \(inputName)RequestValue
            public typealias Response = \(inputName)ResponseValue

            let delegate: \(inputName)
            let logger: Logger

            public init(logger: Logger)
            {
                self.logger = logger

                self.delegate = \(inputName)()
            }

            public init(logger: Logger, delegate: \(inputName))
            {
                self.logger = logger
                self.delegate = delegate
            }

            public func service(_ request: \(inputName)RequestValue) throws -> \(inputName)ResponseValue
            {
                self.logger.debug("client -(\\(request))->")

                switch request
                {
        \(try self.generateServiceCases(inputName.text, requestEnum, identifiers, namespace))
                }
            }
        }
        """

        let data = template.data
        try data.write(to: outputPath)
    }

    func generateServiceCases(_ inputName: Text, _ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace) throws -> Text
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
                                                case .\(enumCase):
                                                    self.delegate.\(functionName)()
                                                    let response = \(inputName)ResponseValue.\(returnTypeName)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                    """

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        return """
                                                    // f() throws
                                                    case .\(enumCase):
                                                        do
                                                        {
                                                            try self.delegate.\(functionName)()
                                                            let resultValue = \(returnTypeName)Value.Nothing
                                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                            self.logger.debug("client <-(\\(response))-")

                                                            return response
                                                        }
                                                        catch
                                                        {
                                                            let result = ErrorValue(error.localizedDescription)
                                                            let resultValue = \(returnTypeName)Value.Error(result)
                                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                            self.logger.debug("client <-(\\(response))-")

                                                            return response
                                                        }
                                        """
                                    }
                                    else if cases.contains("Error")
                                    {
                                        return """
                                                    // f() throws -> T
                                                    case .\(enumCase):
                                                        do
                                                        {
                                                            let result = try self.delegate.\(functionName)()
                                                            let resultValue = \(returnTypeName)Value.\(returnTypeName)_value(\(returnTypeName)_valueValue(result))
                                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                            self.logger.debug("client <-(\\(response))-")

                                                            return response
                                                        }
                                                        catch
                                                        {
                                                            let result = ErrorValue(error.localizedDescription)
                                                            let resultValue = \(returnTypeName)Value.Error(result)
                                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                            self.logger.debug("client <-(\\(response))-")

                                                            return response
                                                        }
                                        """
                                    }
                                    else
                                    {
                                        return """
                                                    // f() -> T
                                                    case .\(enumCase)():
                                                        let result = self.delegate.\(functionName)()
                                                        let resultValue = \(returnTypeName)Value(result)
                                                        let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                        self.logger.debug("client <-(\\(response))-")

                                                        return response
                                        """
                                    }

                                default:
                                    return """
                                                // f() -> T
                                                case .\(enumCase):
                                                    let result = self.delegate.\(functionName)()
                                                    let resultValue = \(returnTypeName)Value(result)
                                                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                    """
                            }

                        default:
                            switch returnType
                            {
                                case .SingletonType(name: _):
                                    return """
                                                // f(T)
                                                case .\(enumCase)(let value):
                                                    self.delegate.\(functionName)(value)
                                                    let respnse = \(inputName)ResponseValue.\(returnTypeName)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                    """

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        return """
                                                // f(T) throws
                                                case .\(enumCase)(let value):
                                                    do
                                                    {
                                                        try self.delegate.\(functionName)(value)
                                                        let resultValue = \(returnTypeName)Value.Nothing
                                                        let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                        self.logger.debug("client <-(\\(response))-")

                                                        return response
                                                    }
                                                    catch
                                                    {
                                                        let result = ErrorValue(error.localizedDescription)
                                                        let resultValue = \(returnTypeName)Value.Error(result)
                                                        let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                        self.logger.debug("client <-(\\(response))-")

                                                        return response
                                                    }
                                        """
                                    }
                                    else if cases.contains("Error")
                                    {
                                        return """
                                                // f(S) throws -> T
                                                case .\(enumCase)(let value):
                                                    do
                                                    {
                                                        try self.delegate.\(functionName)(value)
                                                        let resultValue = \(returnTypeName)Value(result)
                                                        let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                        self.logger.debug("client <-(\\(response))-")
                                        
                                                        return response
                                                    }
                                                    catch
                                                    {
                                                        let result = ErrorValue(error.localizedDescription)
                                                        let resultValue = \(returnTypeName)Value.Error(result)
                                                        let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                        self.logger.debug("client <-(\\(response))-")

                                                        return response
                                                    }
                                        """
                                    }
                                    else
                                    {
                                        return """
                                                // f(S) -> T
                                                case .\(enumCase)(let value):
                                                    let result = self.delegate.\(functionName)(value)
                                                    let resultValue = \(returnTypeName)Value(result)
                                                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                        """
                                    }

                                default:
                                    return """
                                                // f(S) -> T
                                                case .\(enumCase)(let value):
                                                    let result = self.delegate.\(functionName)(value)
                                                    let resultValue = \(returnTypeName)Value(result)
                                                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                    """
                            }
                    }
                }
                .joined(separator: "\n")
                .text

            default:
                throw ServiceGeneratorError.wrongType
        }
    }
}

public enum ServiceGeneratorError: Error
{
    case notFound(Text)
    case wrongType
    case badFormat
}
