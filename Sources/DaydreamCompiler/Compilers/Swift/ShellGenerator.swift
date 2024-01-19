//
//  ShellGenerator.swift
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
    func writeShell(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        let outputPath = outputDirectory.appending(path: "\(inputName)Shell.swift")

        let requestName = "\(inputName)Request".text
        guard let requestEnum = namespace.bindings[requestName] else
        {
            throw ServiceGeneratorError.notFound(requestName)
        }

        let template = """
        //
        //  \(inputName)Shell.swift
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

        public struct \(inputName)Shell
        {
            let client: \(inputName)Client
            let logger: Logger

            public init(host: String, port: Int, logger: Logger) throws
            {
                self.logger = logger
                self.client = try \(inputName)Client(host: host, port: port, logger: logger)

                self.run()
            }

            func run()
            {
                print("\(inputName) shell - \(Date())")

                while true
                {
                    print()
                    print("> ", terminator: "")

                    guard let line = readLine(strippingNewline: true) else
                    {
                        print("Bad read. Exiting.")
                        return
                    }

                    let parts = line.text.split(" ")
                    guard parts.count > 0 else
                    {
                        continue
                    }

                    let command = parts[0]
                    let arguments = [Text](parts.dropFirst())

                    if command == "quit"
                    {
                        print("Quiting.")
                        return
                    }
                    else if command == "help"
                    {
        \(try self.generateHelpCases(inputName.text, requestEnum, identifiers, namespace))
                    }
        \(try self.generateShellCases(inputName.text, requestEnum, identifiers, namespace))
                    else
                    {
                        print("Unknown command.")
                    }
                }
            }
        }

        public enum \(inputName)ShellError: Error
        {
            case serviceError(String)
            case wrongReturnType
        }
        """

        let data = template.data
        try data.write(to: outputPath)
    }

    func generateHelpCases(_ inputName: Text, _ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace) throws -> Text
    {
        switch requestEnum
        {
            case .Enum(name: _, cases: let cases):
                return try cases.sorted().map
                {
                    enumCase in

                    let argumentsType = try namespace.resolve(enumCase)

                    guard let functionName = enumCase.split("_").first else
                    {
                        throw ServiceGeneratorError.badFormat
                    }

                    let returnTypeName = "\(functionName)_response".text

                    switch argumentsType
                    {
                        case .SingletonType(name: _):
                            return """
                                                print("\(functionName)\(try self.formatReturnType(returnTypeName, namespace))")
                            """

                        default:
                            return """
                                                print("\(functionName)\(try self.formatReturnType(returnTypeName, namespace))")
                            """
                    }
                }
                .joined(separator: "\n")
                .text

            default:
                throw ShellGeneratorError.wrongType
        }
    }

    func formatArguments(_ arguments: [Text], _ namespace: Namespace) throws -> Text
    {
        return try arguments.map { try self.formatArgument($0, namespace).string }.joined(separator: " ").text
    }

    func formatArgument(_ argument: Text, _ namespace: Namespace) throws -> Text
    {
        let type = try namespace.resolve(argument)
        switch type
        {
            case .SingletonType(name: _):
                return "".text

            case .Builtin(name: _, representation: _):
                return "\(type)".text

            case .Enum(name: _, cases: _):
                return "\(try self.canonicalName(type, namespace))".text

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let fieldType = try namespace.resolve(fields[0])

                    switch fieldType
                    {
                        case .SingletonType(name: let name):
                            return "\(name)".text

                        case .Builtin(name: let name, representation: _):
                            return "\(name)".text

                        case .List(name: _, type: let name):
                            return "\(name)".text

                        case .Enum(name: _, cases: let cases):
                            return "\(cases.map { $0.string }.joined(separator: " | "))".text

                        default:
                            return "\(fields[0])".text
                    }
                }
                else
                {
                    return "(\(fields.map { $0.string }.joined(separator: ", ")))".text
                }

            case .List(name: _, type: let listType):
                return "[\(listType)]".text
        }
    }

    func formatReturnType(_ type: Text, _ namespace: Namespace) throws -> Text
    {
        let returnType = try namespace.resolve(type)
        switch returnType
        {
            case .SingletonType(name: _):
                return "".text

            case .Builtin(name: _, representation: _):
                return " -> \(returnType)".text

            case .Enum(name: _, cases: let cases):
                if cases == ["Nothing", "Error"]
                {
                    return " throws".text
                }
                else if cases.contains("Error")
                {
                    let caseType = try namespace.resolve(cases[0])
                    switch caseType
                    {
                        case .SingletonType(name: let name):
                            return " throws -> \(name)".text

                        case .Builtin(name: let name, representation: _):
                            return " throws -> \(name)".text

                        case .List(name: _, type: let name):
                            return " throws -> \(name)".text

                        case .Enum(name: _, cases: let cases):
                            return " throws -> \(cases.map { $0.string }.joined(separator: " | "))".text

                        case .Record(name: _, fields: let fields):
                            if fields.count == 1
                            {
                                return " throws -> \(fields[0])".text
                            }
                            else
                            {
                                return " throws -> \(fields.map { $0.string }.joined(separator: ", "))".text
                            }
                    }
                }
                else
                {
                    return " -> \(try self.canonicalName(returnType, namespace))".text
                }

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let fieldType = try namespace.resolve(fields[0])

                    switch fieldType
                    {
                        case .SingletonType(name: let name):
                            return " -> \(name)".text

                        case .Builtin(name: let name, representation: _):
                            return " -> \(name)".text

                        case .List(name: _, type: let name):
                            return " -> \(name)".text

                        case .Enum(name: _, cases: let cases):
                            return " -> \(cases.map { $0.string }.joined(separator: " | "))".text

                        default:
                            return " -> \(fields[0])".text
                    }
                }
                else
                {
                    return " -> (\(fields.map { $0.string }.joined(separator: ", ")))".text
                }

            case .List(name: _, type: let listType):
                return " -> [\(listType)]".text
        }
    }

    func generateShellCases(_ inputName: Text, _ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace) throws -> Text
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
                                                else if command == "\(functionName)".text
                                                {
                                                    do
                                                    {
                                                        try self.client.\(functionName)()
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                    """

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        return """
                                                    // f() throws
                                                    else if command == "\(functionName)".text
                                                    {
                                                        do
                                                        {
                                                            try self.client.\(functionName)()
                                                        }
                                                        catch
                                                        {
                                                            print("Error: \\(error.localizedDescription).")
                                                        }
                                                    }
                                        """
                                    }
                                    else if cases.contains("Error")
                                    {
                                        return """
                                                // f() throws -> T
                                                else if command == "\(functionName)".text
                                                {
                                                    do
                                                    {
                                                        let result = try self.client.\(functionName)()
                                                        print(result)
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                        """
                                    }
                                    else
                                    {
                                        return """
                                                // f() -> T (1)
                                                else if command == "\(functionName)".text
                                                {
                                                    do
                                                    {
                                                        let result = try self.client.\(functionName)()
                                                        print(result)
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                        """
                                    }

                                default:
                                    switch returnType
                                    {
                                        case .Builtin(name: _, representation: _):
                                            return """
                                                // f() -> T (3)
                                                else if command == "\(functionName)".text
                                                {
                                                    do
                                                    {
                                                        let result = try self.client.\(functionName)()
                                                        switch result
                                                        {
                                                            print(result)
                                                        }
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                            """

                                        case .Record(name: _, fields: let fields):
                                            if fields.count == 1
                                            {
                                                if fields[0] == "String" || fields[0] == "Text"
                                                {
                                                    return """
                                                            // f() -> T (3)
                                                            else if command == "\(functionName)".text
                                                            {
                                                                do
                                                                {
                                                                    let result = try self.client.\(functionName)()
                                                                    print("\\\"\\(result.field1)\\\"")
                                                                }
                                                                catch
                                                                {
                                                                    print("Error: \\(error.localizedDescription).")
                                                                }
                                                            }
                                                    """
                                                }
                                                else
                                                {
                                                    return """
                                                            // f() -> T (3)
                                                            else if command == "\(functionName)".text
                                                            {
                                                                do
                                                                {
                                                                    let result = try self.client.\(functionName)()
                                                                    print(result.field1)
                                                                }
                                                                catch
                                                                {
                                                                    print("Error: \\(error.localizedDescription).")
                                                                }
                                                            }
                                                    """
                                                }
                                            }
                                            else
                                            {
                                                let fieldsString = fields.map { "let \($0.string)" }.joined(separator: ", ")
                                                let printString = fields.map { "\\(\($0.string))" }.joined(separator: ", ")

                                                return """
                                                            // f() -> T (3)
                                                            else if command == "\(functionName)".text
                                                            {
                                                                do
                                                                {
                                                                    let result = try self.client.\(functionName)()
                                                                    switch result
                                                                    {
                                                                        switch .\(functionName)_responseValue(\(fieldsString)):
                                                                            print("\(printString)")
                                                                    }
                                                                }
                                                                catch
                                                                {
                                                                    print("Error: \\(error.localizedDescription).")
                                                                }
                                                            }
                                                """
                                            }

                                        default:
                                            return """
                                                // f() -> T (4)
                                                else if command == "\(functionName)".text
                                                {
                                                    do
                                                    {
                                                        let result = try self.client.\(functionName)()
                                                        switch result
                                                        {
                                                            print(result)
                                                        }
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                            """
                                    }
                            }

                        default:
                            switch returnType
                            {
                                case .SingletonType(name: _):
                                    return """
                                                // f(T)
                                                else if command == "\(functionName)".text
                                                {
                                    \(try self.parseArgument(inputName, enumCase, namespace))

                                                    do
                                                    {
                                                        try self.client.\(functionName)(\(try self.argumentList(inputName, enumCase, namespace)))
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                    """

                                case .Enum(name: _, cases: let cases):
                                    if cases == ["Nothing", "Error"]
                                    {
                                        return """
                                                // f(S) throws
                                                else if command == "\(functionName)".text
                                                {
                                        \(try self.parseArgument(inputName, enumCase, namespace))

                                                    do
                                                    {
                                                        try self.client.\(functionName)(\(try self.argumentList(inputName, enumCase, namespace)))
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                        """
                                    }
                                    else
                                    {
                                        return """
                                                // f(S) -> T 1
                                                else if command == "\(functionName)".text
                                                {
                                        \(try self.parseArgument(inputName, enumCase, namespace))

                                                    do
                                                    {
                                                        let result = try self.client.\(functionName)(\(try self.argumentList(inputName, enumCase, namespace)))
                                                        print(result)
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                        """
                                    }

                                default:
                                    return """
                                                // f(S) -> T 2
                                                else if command == "\(functionName)".text
                                                {
                                    \(try self.parseArgument(inputName, enumCase, namespace))

                                                    do
                                                    {
                                                        let result = try self.client.\(functionName)(\(try self.argumentList(inputName, enumCase, namespace)))
                                                        print(result)
                                                    }
                                                    catch
                                                    {
                                                        print("Error: \\(error.localizedDescription).")
                                                    }
                                                }
                                    """
                            }
                    }
                }
                .joined(separator: "\n")
                .text

            default:
                throw ShellGeneratorError.wrongType
        }
    }

    func parseArgument(_ inputName: Text, _ argumentsTypeName: Text, _ namespace: Namespace) throws -> Text
    {
        let argumentsType = try namespace.resolve(argumentsTypeName)

        switch argumentsType
        {
            case .Builtin(name: _, representation: _):
                return """
                        let text0 = arguments[0]

                        let argument0 = \(argumentsTypeName)(text0)
                """.text

            case .Enum(name: _, cases: _):
                return """
                        let text0 = arguments[0]

                        let argument0 = \(argumentsTypeName)(text0)
                """.text

            case .List(name: _, type: _):
                return """
                        let text0 = arguments[0]

                        let argument0 = \(argumentsTypeName)(text0)
                """.text

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            if field0 == "Text"
                            {
                                return """
                                                let text0 = arguments[0]

                                                let argument0: \(field0) = text0
                                """.text
                            }
                            else if field0 == "String"
                            {
                                return """
                                                let text0 = arguments[0]

                                                let argument0: \(field0) = text0.string
                                """.text
                            }
                            else
                            {
                                return """
                                                let text0 = arguments[0]

                                                let argument0: \(field0) = \(field0)(string: text0.string)
                                """.text
                            }

                        case .Record(name: _, fields: let fields):
                            return fields.enumerated().map
                            {
                                index, element in

                                if element == "Text"
                                {
                                    return """
                                                let argument\(index) = arguments[\(index)]
                                    """
                                }
                                else
                                {
                                    return """
                                                let text\(index) = arguments[\(index)]
                                                let argument\(index): \(element) = \(element)(string: text\(index).string)
                                    """
                                }
                            }.joined(separator: "\n").text

                        case .List(name: _, type: let listType):
                            if listType == "Text"
                            {
                                return """
                                                let parameters = arguments
                                """.text
                            }
                            else
                            {
                                return """
                                                let parameters = arguments.map { \(fieldType)(string: $0) }
                                """.text
                            }

                        case .Enum(name: _, cases: let cases):
                            if cases.contains("Nothing")
                            {
                                let case0 = cases[0]

                                return """
                                                let argument0: \(case0)?
                                                if arguments.count == 0
                                                {
                                                    argument0 = nil
                                                }
                                                else
                                                {
                                                    argument0 = arguments[0]
                                                }
                                """.text
                            }
                            else
                            {
                                return """
                                            let text0 = arguments[0]

                                            let argument0 = \(field0)(text0)
                                """.text
                            }

                        default:
                            return """
                                            let text0 = arguments[0]

                                            let argument0 = \(field0)(text0)
                            """.text
                    }
                }
                else
                {
                    return """
                        let text0 = arguments[0]

                        let argument0 = \(argumentsTypeName)(text0)
                    """.text
                }

            case .SingletonType(name: _):
                return """
                        let text0 = arguments[0]

                        let argument0 = \(argumentsTypeName)(text0)
                """.text
        }
    }

    func argumentList(_ inputName: Text, _ argumentsTypeName: Text, _ namespace: Namespace) throws -> Text
    {
        let argumentsType = try namespace.resolve(argumentsTypeName)

        switch argumentsType
        {
            case .Builtin(name: _, representation: _):
                return "argument0"

            case .Enum(name: _, cases: _):
                return "argument0"

            case .List(name: _, type: _):
                return "argument0"

            case .Record(name: _, fields: let fields):
                if fields.count == 1
                {
                    let field0 = fields[0]

                    let fieldType = try namespace.resolve(field0)

                    switch fieldType
                    {
                        case .Builtin(name: _, representation: _):
                            return "argument0"

                        case .Record(name: _, fields: let fields):
                            return fields.enumerated().map
                            {
                                index, element in

                                return "argument\(index)"
                            }.joined(separator: ", ").text

                        case .List(name: _, type: let listType):
                            return "parameters"

                        case .Enum(name: _, cases: let cases):
                            if cases.contains("Nothing")
                            {
                                return "argument0"
                            }
                            else
                            {
                                return fields.enumerated().map
                                {
                                    index, element in

                                    return "argument\(index)"
                                }.joined(separator: ", ").text
                            }

                        default:
                            return fields.enumerated().map
                            {
                                index, element in

                                return "argument\(index)"
                            }.joined(separator: ", ").text                    }
                }
                else
                {
                    return fields.enumerated().map
                    {
                        index, element in

                        return "argument\(index)"
                    }.joined(separator: ", ").text                }

            case .SingletonType(name: _):
                return "argument0"
        }
    }

}

public enum ShellGeneratorError: Error
{
    case notFound(Text)
    case wrongType
    case badFormat
}
