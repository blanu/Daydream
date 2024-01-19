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

            public enum \(inputName)ServiceError: Error
            {
                case wrongReturnType
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
                                                    self.delegate.\(functionName)(value.field1)
                                                    let response = \(inputName)ResponseValue.\(returnTypeName)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                    """

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        switch argumentsType
                                        {
                                            case .Record(name: _, fields: let fields):
                                                if fields.count == 1
                                                {
                                                    let field0 = fields[0]

                                                    let fieldType = try namespace.resolve(field0)

                                                    switch fieldType
                                                    {
                                                        case .Record(name: _, fields: let subfields):
                                                            if subfields.count == 1
                                                            {
                                                                return """
                                                                    // f(T) throws 1
                                                                    case .\(enumCase)(let value):
                                                                        do
                                                                        {
                                                                            try self.delegate.\(functionName)(value.field1.field1)
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
                                                            else
                                                            {
                                                                let arguments = subfields.enumerated().map
                                                                {
                                                                    index, _ in

                                                                    return "value.field1.field\(index + 1)"
                                                                }.joined(separator: ", ")

                                                                return """
                                                                    // f(T) throws 2
                                                                    case .\(enumCase)(let value):
                                                                        do
                                                                        {
                                                                            try self.delegate.\(functionName)(\(arguments))
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

                                                        default:
                                                            return """
                                                                    // f(T) throws 3
                                                                    case .\(enumCase)(let value):
                                                                        do
                                                                        {
                                                                            try self.delegate.\(functionName)(value.field1)
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
                                                }
                                                else
                                                {
                                                    let arguments = fields.enumerated().map
                                                    {
                                                        index, _ in

                                                        return "value.field1.field\(index + 1)"
                                                    }.joined(separator: ", ")

                                                    return """
                                                        // f(T) throws 4
                                                        case .\(enumCase)(let value):
                                                            do
                                                            {
                                                                try self.delegate.\(functionName)(\(arguments))
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

                                            default:
                                                return """
                                                    // f(T) throws 5
                                                    case .\(enumCase)(let value):
                                                        do
                                                        {
                                                            try self.delegate.\(functionName)(value.field1.field1)
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
                                    }
                                    else if cases.contains("Error")
                                    {
                                        switch argumentsType
                                        {
                                            case .Record(name: _, fields: let fields):
                                                if fields.count == 1
                                                {
                                                    let field0 = fields[0]

                                                    let fieldType = try namespace.resolve(field0)

                                                    switch fieldType
                                                    {
                                                        case .Record(name: _, fields: let subfields):
                                                            if subfields.count == 1
                                                            {
                                                                return """
                                                                    // f(S) throws -> T
                                                                    case .\(enumCase)(let value):
                                                                        do
                                                                        {
                                                                            let result = try self.delegate.\(functionName)(value.field1)
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
                                                                let arguments = subfields.enumerated().map
                                                                {
                                                                    index, _ in

                                                                    return "value.field1.field\(index + 1)"
                                                                }.joined(separator: ", ")

                                                                return """
                                                                    // f(S, ...) throws -> T (enum of Error and record with 1 field)
                                                                    case .\(enumCase)(let value):
                                                                        do
                                                                        {
                                                                            let result = try self.delegate.\(functionName)(\(arguments))
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
                                                        default:
                                                            return """
                                                                // f(S) throws -> T (enum of Error and record with 1 field)
                                                                case .\(enumCase)(let value):
                                                                    do
                                                                    {
                                                                        let result = try self.delegate.\(functionName)(value.field1)
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
                                                }
                                                else
                                                {
                                                    return """
                                                        // f(S) throws -> T (enum of Error and record with multiple fields)
                                                        case .\(enumCase)(let value):
                                                            do
                                                            {
                                                                let result = try self.delegate.\(functionName)(value.field1)
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

                                            default:
                                                return """
                                                    // f(S) throws -> T (enum of Error and non-record)
                                                    case .\(enumCase)(let value):
                                                        do
                                                        {
                                                            let result = try self.delegate.\(functionName)(value.field1)
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
                                    }
                                    else
                                    {
                                        return """
                                                // f(S) -> T 1
                                                case .\(enumCase)(let value):
                                                    let resultValue = \(returnTypeName)Value(value)
                                                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                    self.logger.debug("client <-(\\(response))-")

                                                    return response
                                        """
                                    }

                                default:
                                    switch argumentsType
                                    {
                                        case .Record(name: _, fields: let fields):
                                            if fields.count == 1
                                            {
                                                let field0 = fields[0]

                                                let fieldType = try namespace.resolve(field0)

                                                switch fieldType
                                                {
                                                    case .Record(name: _, fields: let subfields):
                                                        if subfields.count == 1
                                                        {
                                                            let arguments = subfields.enumerated().map
                                                            {
                                                                index, _ in

                                                                return "value.field1.field\(index + 1)"
                                                            }.joined(separator: ", ")

                                                            return """
                                                                // f(S) -> T 2
                                                                case .\(enumCase)(let value):
                                                                    let result = self.delegate.\(functionName)(\(arguments))
                                                                    let resultValue = \(returnTypeName)Value(result)
                                                                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                                    self.logger.debug("client <-(\\(response))-")

                                                                    return response
                                                            """
                                                        }
                                                        else
                                                        {
                                                            return """
                                                                // f(S) -> T 3
                                                                case .\(enumCase)(let value):
                                                                    let result = self.delegate.\(functionName)(value)
                                                                    let resultValue = \(returnTypeName)Value(result)
                                                                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)

                                                                    self.logger.debug("client <-(\\(response))-")

                                                                    return response
                                                            """
                                                        }

                                                    case .Builtin(name: _, representation: _):
                                                        let wrappedReturn = try self.wrapReturnValue(inputName, returnTypeName, functionName, namespace)

                                                        return """
                                                                // f(S:Builtin) -> T 3.1
                                                                case .\(enumCase)(let value):
                                                                    let result = self.delegate.\(functionName)(value.field1)
                                                        \(wrappedReturn)

                                                                    self.logger.debug("client <-(\\(response))-")

                                                                    return response
                                                        """

                                                    case .List(name: _, type: _):
                                                        let wrappedReturn = try self.wrapReturnValue(inputName, returnTypeName, functionName, namespace)

                                                        return """
                                                            // f(S) -> T 4
                                                            case .\(enumCase)(let value):
                                                                let result = self.delegate.\(functionName)(value.field1)
                                                        \(wrappedReturn)

                                                                self.logger.debug("client <-(\\(response))-")

                                                                return response
                                                        """

                                                    case .Enum(name: _, cases: let cases):
                                                        let wrappedReturn = try self.wrapReturnValue(inputName, returnTypeName, functionName, namespace)

                                                        if cases == ["Nothing", "Error"]
                                                        {
                                                            return """
                                                                // f(S) -> T 5.1
                                                                case .\(enumCase)(let value):
                                                                    let result = self.delegate.\(functionName)(value.field1

                                                            \(wrappedReturn)

                                                                    self.logger.debug("client <-(\\(response))-")

                                                                    return response
                                                            """
                                                        }
                                                        else if cases.contains("Nothing")
                                                        {
                                                            let case0 = cases[0]

                                                            return """
                                                                        // f(S) -> T 5.2
                                                                        case .\(enumCase)(let value):
                                                                            switch value.field1
                                                                            {
                                                                                case .\(case0)Value(let valueValue):
                                                                                    let result = self.delegate.\(functionName)(valueValue)
                                                            \(wrappedReturn)

                                                                                    self.logger.debug("client <-(\\(response))-")

                                                                                    return response

                                                                                case .Nothing:
                                                                                    let result = self.delegate.\(functionName)(nil)
                                                            \(wrappedReturn)

                                                                                    self.logger.debug("client <-(\\(response))-")

                                                                                    return response
                                                                            }
                                                            """
                                                        }
                                                        else
                                                        {
                                                            return """
                                                                        // f(S) -> T 5.2
                                                                        case .\(enumCase)(let value):
                                                                            let result = self.delegate.\(functionName)(value.field1)
                                                            \(wrappedReturn)

                                                                            self.logger.debug("client <-(\\(response))-")

                                                                            return response
                                                            """
                                                        }

                                                    default:
                                                        let wrappedReturn = try self.wrapReturnValue(inputName, returnTypeName, functionName, namespace)

                                                        return """
                                                            // f(S) -> T 6
                                                            case .\(enumCase)(let value):
                                                                let result = self.delegate.\(functionName)(value.field1)
                                                        \(wrappedReturn)

                                                                self.logger.debug("client <-(\\(response))-")

                                                                return response
                                                        """
                                                }
                                            }
                                            else
                                            {
                                                return """
                                                    // f(S) -> T 5.3
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
                                                // f(S) -> T 6
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
                }
                .joined(separator: "\n\n")
                .text

            default:
                throw ServiceGeneratorError.wrongType
        }
    }

    func unwrapArguments(_ index: Int, _ startingTypeName: Text, _ namespace: Namespace) throws -> Text
    {
        let startingType = try namespace.resolve(startingTypeName)

        switch startingType
        {
            case .Builtin(name: _, representation: _):
                return """
                try self.delegate.indexOf(value)
                """
            case .Enum(name: _, cases: _):
                return """
                try self.delegate.indexOf(value)
                """
            case .List(name: _, type: _):
                return """
                try self.delegate.indexOf(value)
                """
            case .Record(name: _, fields: _):
                return """
                try self.delegate.indexOf(value)
                """
            case .SingletonType(name: _):
                return """
                try self.delegate.indexOf(value)
                """
        }
    }

    func wrapReturnValue(_ inputName: Text, _ returnTypeName: Text, _ functionName: Text, _ namespace: Namespace) throws -> Text
    {
        let type = try namespace.resolve(returnTypeName)

        switch type
        {
            case .Builtin(name: _, representation: _):
                return """
                    let resultValue = \(returnTypeName)Value(result)
                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                """.text

            case .Enum(name: _, cases: _):
                return """
                    let resultValue = \(returnTypeName)Value(result)
                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                """.text

            case .List(name: _, type: _):
                return """
                    let resultValue = \(returnTypeName)Value(result)
                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                """.text

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Enum(name: _, cases: let cases):
                            if cases == ["Nothing", "Error"]
                            {
                                return """
                                            let resultValueValue = \(returnTypeName)_valueValue(result)
                                            let resultValue = \(returnTypeName)Value(resultValueValue)
                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                                """.text
                            }
                            else if cases.contains("Error")
                            {
                                return """
                                            let resultValueValue = \(returnTypeName)_valueValue(result)
                                            let resultValue = \(returnTypeName)Value(resultValueValue)
                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                                """.text
                            }
                            else
                            {
                                return """
                                            let resultValueValue = \(returnTypeName)_valueValue(result)
                                            let resultValue = \(returnTypeName)Value(resultValueValue)
                                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                                """.text
                            }

                        default:
                            return """
                                        let resultValueValue = \(returnTypeName)_valueValue(result)
                                        let resultValue = \(returnTypeName)Value(resultValueValue)
                                        let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                            """.text
                    }
                }
                else
                {
                    return """
                            let resultValueValue = \(returnTypeName)_valueValue(result)
                            let resultValue = \(returnTypeName)Value(resultValueValue)
                            let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                    """.text
                }

            case .SingletonType(name: _):
                return """
                    let resultValue = \(returnTypeName)Value(result)
                    let response = \(inputName)ResponseValue.\(returnTypeName)(resultValue)
                """.text
        }
    }
}

public enum ServiceGeneratorError: Error
{
    case notFound(Text)
    case wrongType
    case badFormat
}
