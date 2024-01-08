//
//  File.swift
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
        let outputPath = outputDirectory.appending(path: "main.swift")

        let requestName = "\(inputName)Request".text
        guard let requestEnum = namespace.bindings[requestName] else
        {
            throw ServiceGeneratorError.notFound(requestName)
        }

        let template = """
        //
        //  main.swift
        //
        //
        //  Created by the Daydream Compiler on \(Date()).
        //

        import Foundation

        import BigNumber
        import Datable
        import RadioWave
        import SwiftHexTools
        import Text

        public struct \(inputName)Service
        {
            let logic: \(inputName)Logic = \(inputName)Logic()
            let stdio: StdioService<\(inputName)RequestValue, \(inputName)ResponseValue, \(inputName)Logic>

            public init() throws
            {
                self.stdio = try StdioService<\(inputName)RequestValue, \(inputName)ResponseValue, \(inputName)Logic>(handler: logic)
            }
        }

        public struct \(inputName)Logic: Logic
        {
            public typealias Request = \(inputName)RequestValue
            public typealias Response = \(inputName)ResponseValue

            let delegate: \(inputName)

            public init()
            {
                self.delegate = \(inputName)()
            }

            public init(delegate: \(inputName))
            {
                self.delegate = delegate
            }

            public func service(_ request: \(inputName)RequestValue) throws -> \(inputName)ResponseValue
            {
                switch request
                {
        \(try self.generateServiceCases(requestEnum, identifiers, namespace))
                }
            }
        }

        let service = try \(inputName)Service()
        """

        let data = template.data
        try data.write(to: outputPath)
    }

    func generateServiceCases(_ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace) throws -> Text
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
                                    // f()
                                    return """
                                                case .\(enumCase):
                                                    self.delegate.\(functionName)()
                                    """

                                default:
                                    // f() -> T
                                    return """
                                                case .\(enumCase):
                                                    let result = self.delegate.\(functionName)()
                                                    let resultValue = \(returnTypeName)Value(result)
                                                    return .\(returnTypeName)(resultValue)
                                    """
                            }

                        default:
                            switch returnType
                            {
                                case .SingletonType(name: _):
                                    // f(T)
                                    return """
                                                case .\(enumCase)(let value):
                                                    self.delegate.\(functionName)(value)
                                    """

                                default:
                                    // f(S) -> T
                                    return """
                                                case .\(enumCase)(let value):
                                                    let result = self.delegate.\(functionName)(value)
                                                    let resultValue = \(returnTypeName)Value(result)
                                                    return .\(returnTypeName)(resultValue)
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
