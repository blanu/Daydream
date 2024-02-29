////
////  BlueprintShellGenerator.swift
////
////
////  Created by Dr. Brandon Wiley on 1/28/24.
////
//
//import Blueprint
//import Daydream
//import Foundation
//import Gardener
//import Text
//
//extension SwiftCompiler {
//    func writeShellBlueprint(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws {
//        let outputPath = outputDirectory.appending(path: "\(inputName)Shell.swift")
//
//        let requestName = "\(inputName)Request".text
//        guard let requestEnum = namespace.bindings[requestName] else { throw ServiceGeneratorError.notFound(requestName) }
//
//        let blueprint = SourceFile(
//            header: FileHeader(filename: "\(inputName)Request".text), imports: ImportSection(globals: [.BigNumber, .Datable, .Hex, .Logging, .RadioWave, .Text], locals: ["Foundation"]),
//            structs: [
//                Structure(
//                    name: "\(inputName)Shell".text, properties: [Property(name: "client", type: .named("\(inputName)Client".text)), Property(name: "logger", type: .named("Logger"))],
//                    constructors: [
//                        Constructor(
//                            parameters: [Parameter(name: "host", type: .named("String")), Parameter(name: "port", type: .named("Int")), Parameter(name: "logger", type: .named("Logger"))],
//                            throwing: true,
//                            statements: [
//                                .assignment(.property("logger"), .value(.variable("logger"))),
//                                .assignment(
//                                    .property("client"),
//                                    .constructorCall(
//                                        ConstructorCall(
//                                            trying: true, name: "\(inputName)Client".text,
//                                            arguments: [
//                                                Argument(label: "host", value: .variable("host")), Argument(label: "port", value: .variable("port")),
//                                                Argument(label: "logger", value: .variable("logger")),
//                                            ]))), .blank, .expression(.functionCall(FunctionCall(name: "self.run"))),
//                            ])
//                    ],
//                    functions: [
//                        Function(
//                            name: "run",
//                            statements: [
//                                .expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("\(inputName) shell - \(Date())".text)))]))),
//                                .`while`(
//                                    While(
//                                        expression: .value(.literal(.boolean(true))),
//                                        statements: [
//                                            .expression(.functionCall(FunctionCall(name: "print"))),
//                                            .expression(
//                                                .functionCall(
//                                                    FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("> "))), Argument(label: "terminator", value: .literal(.string("")))]))),
//                                            .blank,
//                                            .`guard`(
//                                                .`let`(
//                                                    "line", .functionCall(FunctionCall(name: "readLine", arguments: [Argument(label: "strippingNewline", value: .literal(.boolean(true)))])),
//                                                    [.expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("Bad read. Exiting.")))]))), .`return`])),
//                                            .blank,
//                                            .assignment(
//                                                .variableDefinition(VariableDefinition(name: "parts")),
//                                                .functionCall(FunctionCall(name: "line.text.split", arguments: [Argument(value: .literal(.string(" ")))]))),
//                                            .guard(.condition(.math(MathExpression.infix(.greaterThan, .value(.variable("parts.count")), .value(.literal(.number(0))))), [.continue])),
//                                            .assignment(.variableDefinition(VariableDefinition(name: "command")), .index(.single(.value(.variable("parts")), .value(.literal(.number(0)))))),
//                                            .assignment(
//                                                .variableDefinition(VariableDefinition(name: "arguments")),
//                                                .cast(Cast(type: .list(.named("Text")), expression: .functionCall(FunctionCall(name: "parts.dropFirst"))))),
//                                            .branch(
//                                                Branch(
//                                                    condition: .math(.infix(.equal, .value(.variable("command")), .value(.literal(.string("quit"))))),
//                                                    statements: [.expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("Quiting.")))])))],
//                                                    elseClause: ElseClause.elseIf(
//                                                        Branch(
//                                                            condition: .math(.infix(.equal, .value(.variable("command")), .value(.literal(.string("help"))))),
//                                                            statements: try self.generateHelpCasesBlueprint(inputName.text, requestEnum, identifiers, namespace),
//                                                            elseClause: try self.generateShellCasesBlueprint(
//                                                                inputName.text, requestEnum, identifiers, namespace,
//                                                                elseStatements: [
//                                                                    .expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("Unknown command.")))])))
//                                                                ]))))),
//                                        ])),
//                            ])
//                    ])
//            ], enums: [Enumeration(name: "\(inputName)ShellError".text, implements: ["Error"], cases: [Case(name: "serviceError", value: .named("String")), Case(name: "wrongReturnType")])])
//
//        let data = try blueprint.transpile(.swift).toUTF8Data()
//        try data.write(to: outputPath)
//    }
//
//    func generateHelpCasesBlueprint(_ inputName: Text, _ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace) throws -> [Statement] {
//        switch requestEnum { case .Enum(name: _, let cases):
//            return try cases.sorted().map { enumCase in
//
//                let argumentsType = try namespace.resolve(enumCase)
//
//                guard let functionName = enumCase.split("_").first else { throw ServiceGeneratorError.badFormat }
//
//                let returnTypeName = "\(functionName)_response".text
//
//                switch argumentsType { case .SingletonType(name: _):
//                    return Statement.expression(
//                        .functionCall(FunctionCall(trying: true, name: "print", arguments: [Argument(value: .literal(.string(try self.formatReturnType(returnTypeName, namespace))))])))
//
//                    default:  // FIXME
//                        return Statement.expression(
//                            .functionCall(FunctionCall(trying: true, name: "print", arguments: [Argument(value: .literal(.string(try self.formatReturnType(returnTypeName, namespace))))])))
//                }
//            }
//
//            default: throw ShellGeneratorError.wrongType
//        }
//    }
//
//    func generateShellCasesBlueprint(
//        _ inputName: Text, _ requestEnum: TypeDefinition, _ identifiers: [Identifier], _ namespace: Namespace, elseStatements statements: [Statement]
//    ) throws -> ElseClause? {
//        switch requestEnum { case .Enum(name: _, let cases):
//            let finalElse = ElseClause.else(statements)
//
//            return try cases.reversed().reduce(finalElse) { nextElse, enumCase in
//
//                let argumentsType = try namespace.resolve(enumCase)
//
//                guard let functionName = enumCase.split("_").first else { throw ServiceGeneratorError.badFormat }
//
//                let returnTypeName = "\(functionName)_response".text
//                let returnType = try namespace.resolve(returnTypeName)
//
//                return try self.generateShellCaseBlueprint(inputName, namespace, enumCase, argumentsType, functionName, returnTypeName, returnType, nextElse)
//            }
//
//            default: throw ShellGeneratorError.wrongType
//        }
//    }
//
//    func generateShellCaseBlueprint(_ inputName: Text, _ namespace: Namespace,
//        _ enumCase: Text, _ argumentsType: TypeDefinition, _ functionName: Text, _ returnTypeName: Text, _ returnType: TypeDefinition, _ nextElse: ElseClause
//    ) throws -> ElseClause {
//        let argumentsText: Text
//        let parseArguments: [Statement]
//        let arguments: [Argument]
//        switch argumentsType { 
//            case .SingletonType(name: _):
//                argumentsText = ""
//                parseArguments = []
//                arguments = []
//
//            default:  // FIXME
//                argumentsText = "S"
//                parseArguments = try self.parseArgumentBlueprint(inputName, enumCase, namespace)
//                arguments = try self.argumentListBlueprint(inputName, enumCase, namespace)
//        }
//
//        switch returnType {
//            // No arguments, no return
//            case .SingletonType(name: _): return self.generateHelpBlueprint("f(\(argumentsText))".text, functionName, nextElse: nextElse)
//
//            // No arguments, special case return type
//            case .Enum(name: _, let cases):
//                if cases == ["Nothing", "Error"] {
//                    // No arguments, special case returning nothing but also throwing
//                    return self.generateHelpBlueprint("f(\(argumentsText)) throws".text, functionName, trying: true, nextElse: nextElse, parseArguments, arguments)
//                }
//                else if cases.contains("Error") {
//                    // No arguments, special case returning a value and also throwing
//                    return self.generateHelpBlueprint("f(\(argumentsText)) throws -> T".text, functionName, trying: true, returning: true, nextElse: nextElse, parseArguments, arguments)
//                }
//                else {
//                    // No arguments, general case of returning a value (that happens to be an enum)
//                    return self.generateHelpBlueprint("f(\(argumentsText)) -> T where T: Enum".text, functionName, returning: true, nextElse: nextElse, parseArguments, arguments)
//                }
//
//            // No arguments, returning a value that is a builtin
//            case .Builtin(name: _, representation: _): return self.generateHelpBlueprint("f(\(argumentsText)) -> T where T: Builtin".text, functionName, returning: true, nextElse: nextElse, parseArguments, arguments)
//
//            // No arguments, returning a value that is a record
//            case .Record(name: _, let fields):
//                // No arugments, special case of returning a record with only one field
//                // This represents a normal return value and we just need to unwrap the type from the record.
//                if fields.count == 1 {
//                    // No arguments, special case of returning a record with only one field, the type of which is String
//                    // This represents a normal return value of a String type.
//                    if fields[0] == "String" {
//                        return self.generateHelpBlueprint("f(\(argumentsText)) -> String".text, functionName, returning: true, unwrap: true, quoted: true, nextElse: nextElse, parseArguments, arguments)
//                    }
//                    else if fields[0] == "Text" {
//                        return self.generateHelpBlueprint("f(\(argumentsText)) -> Text".text, functionName, returning: true, unwrap: true, quoted: true, nextElse: nextElse, parseArguments, arguments)
//                    }
//                    else {
//                        return self.generateHelpBlueprint("f(\(argumentsText)) -> T".text, functionName, returning: true, unwrap: true, quoted: false, nextElse: nextElse, parseArguments, arguments)
//                    }
//                }
//                else {
//                    // No arguments, return type is a regular record. This is the general case, so it's more complicated.
//                    let fieldCases: [CaseArgument] = fields.map { field in
//
//                        .assign(field)
//                    }
//
//                    // FIXME - add arguments case
//                    return ElseClause.elseIf(
//                        Branch(
//                            condition: .math(.infix(.equal, .value(.variable("command")), .value(.literal(.string(functionName))))),
//                            statements: [
//                                .comment(Comment(text: "f(\(argumentsText)) -> T: Record".text)),
//                                .tryCatch(
//                                    TryCatch(
//                                        tryBlock: [
//                                            .assignment(.variable("result"), .functionCall(FunctionCall(trying: true, name: "self.client.\(functionName)".text))),
//                                            .`switch`(
//                                                Switch(
//                                                    on: .value(.variable("result")),
//                                                    cases: [
//                                                        SwitchCase(
//                                                            name: ".\(functionName)_responseValue".text, arguments: fieldCases,
//                                                            statements: [
//                                                                .expression(
//                                                                    .functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("\(Text.join(fields, ", "))".text)))])))
//                                                            ])
//                                                    ])),
//                                        ],
//                                        catchBlock: [.expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("Error: \\(error.localizedDescription).")))])))]
//                                    )),
//                            ], elseClause: nextElse))
//                }
//
//            // FIXME - add arguments case
//            // No arguments, there is a return value of a generalized type
//            default:
//                return ElseClause.elseIf(
//                    Branch(
//                        condition: .math(.infix(.equal, .value(.variable("command")), .value(.literal(.string(functionName))))),
//                        statements: [
//                            .comment(Comment(text: "f() -> T (generalized)")),
//                            .tryCatch(
//                                TryCatch(
//                                    tryBlock: [
//                                        .assignment(.variable("result"), .functionCall(FunctionCall(trying: true, name: "self.client.\(functionName)".text))),
//                                        .`switch`(
//                                            Switch(
//                                                on: .value(.variable("result")),
//                                                cases: [
//                                                    SwitchCase(
//                                                        name: ".\(functionName)_responseValue".text, arguments: [.assign("result")],
//                                                        statements: [.expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .variable("result"))])))])
//                                                ])),
//                                    ], catchBlock: [.expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("Error: \\(error.localizedDescription).")))])))])
//                            ),
//                        ], elseClause: nextElse))
//        }
//
//    }
//
//    func generateHelpBlueprint(_ comment: Text, _ functionName: Text, trying: Bool = false, returning: Bool = false, unwrap: Bool = false, quoted: Bool = false, nextElse: ElseClause, parseArguments: [], arguments: []) -> ElseClause {
//        let tryBlock: [Statement]
//
//        var resultValueText: Text = ""
//        if returning {
//            resultValueText = "result"
//
//            if unwrap { resultValueText = "\(resultValueText.string).field1".text }
//
//            if quoted {
//                resultValueText = "\"\(resultValueText.string)\"".text
//
//            }
//
//            if returning {
//                tryBlock = [.expression(.functionCall(FunctionCall(trying: trying, name: "self.client.\(functionName)".text)))]
//            }
//            else {
//                tryBlock = [
//                    .assignment(.variableDefinition(VariableDefinition(name: "result")), .functionCall(FunctionCall(trying: trying, name: "self.client.\(functionName)".text))),
//                    .expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .variable("result"))]))),
//                ]
//            }
//
//            return ElseClause.elseIf(
//                Branch(
//                    condition: .math(.infix(.equal, .value(.variable("command")), .value(.literal(.string(functionName))))),
//                    statements: [
//                        .comment(Comment(text: comment)),
//                        .tryCatch(
//                            TryCatch(
//                                tryBlock: tryBlock,
//                                catchBlock: [.expression(.functionCall(FunctionCall(name: "print", arguments: [Argument(value: .literal(.string("Error: \\(error.localizedDescription).")))])))])),
//                    ], elseClause: nextElse))
//        }
//    }
//}
//
//
//    func parseArgumentBlueprint(_ inputName: Text, _ argumentsTypeName: Text, _ namespace: Namespace) throws -> [Statement]
//    {
//        let argumentsType = try namespace.resolve(argumentsTypeName)
//
//        switch argumentsType
//        {
//            case .Builtin(name: _, representation: _):
//                return [
//                    .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                    .assignment(.variableDefinition(VariableDefinition(name: "argument0")), .cast(Cast(type: .named(argumentsTypeName), expression: .value(.variable("text0")))))
//                ]
//
//            case .Enum(name: _, cases: _):
//                return [
//                    .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                    .assignment(.variableDefinition(VariableDefinition(name: "argument0")), .cast(Cast(type: .named(argumentsTypeName), expression: .value(.variable("text0")))))
//                ]
//
//            case .List(name: _, type: _):
//                return [
//                    .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                    .assignment(.variableDefinition(VariableDefinition(name: "argument0")), .cast(Cast(type: .named(argumentsTypeName), expression: .value(.variable("text0")))))
//                ]
//
//            case .Record(name: _, fields: let fields):
//                if fields.count == 1
//                {
//                    let field0 = fields[0]
//
//                    let fieldType = try namespace.resolve(field0)
//
//                    switch fieldType
//                    {
//                        case .Builtin(name: _, representation: _):
//                            return [
//                                .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                                .assignment(.variableDefinition(VariableDefinition(name: "argument0", type: .named(field0))), .value(.variable("text0")))
//                            ]
//
//
//                            if field0 == "Text"
//                            {
//                                return [
//                                    .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                                    .assignment(.variableDefinition(VariableDefinition(name: "argument0", type: .named("Text"))), .value(.variable("text0")))
//                                ]
//                            }
//                            else if field0 == "String"
//                            {
//                                return [
//                                    .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                                    .assignment(.variableDefinition(VariableDefinition(name: "argument0", type: .named("String"))), .value(.variable("text0")))
//                                ]
//                            }
//                            else
//                            {
//                                return [
//                                    .assignment(.variableDefinition(VariableDefinition(name: "text0")), .index(.single(.value(.variable("arguments")), .value(.literal(.number(0)))))),
//                                    .assignment(.variableDefinition(VariableDefinition(name: "argument0", type: .named(field0))), .constructorCall(ConstructorCall(name: field0, arguments: [Argument(value: .variable("text0"))])))
//                                ]
//                            }
//
//                        case .Record(name: _, fields: let fields):
//                            return fields.enumerated().flatMap
//                            {
//                                (index: Int, element: Text) -> [Statement] in
//
//                                if element == "Text"
//                                {
//                                    return [.assignment(.variableDefinition(VariableDefinition(name: "argument\(index)".text)), .index(.single(.value(.variable("arguments")), .value(.literal(.number(index))))))]
//                                }
//                                else
//                                {
//                                    return [
//                                        .assignment(.variableDefinition(VariableDefinition(name: "text\(index)".text)), .index(.single(.value(.variable("arguments")), .value(.literal(.number(index)))))),
//                                        .assignment(.variableDefinition(
//                                            VariableDefinition(name: "arguments\(index)".text, type: .named(element))), .constructorCall(ConstructorCall(name: element, arguments:
//                                                                                [Argument(label: "string", value: .variable("text\(index).string".text))])))
//                                    ]
//                                }
//                            }
//
//                        case .List(name: _, type: let listType):
//                            if listType == "Text"
//                            {
//                                return [.assignment(.variableDefinition(VariableDefinition(name: "parameters")), .value(.variable("arguments")))]
//                            }
//                            else
//                            {
//                                return [.assignment(.variableDefinition(VariableDefinition(name: "parameters")), .functionCall(FunctionCall(name: "arguments.map", arguments: [
//                                    Argument(value: .literal(.))
//                                ])))]
//                                return """
//                                                let parameters = arguments.map { \(fieldType)(string: $0) }
//                                """.text
//                            }
//
//                        case .Enum(name: _, cases: let cases):
//                            if cases.contains("Nothing")
//                            {
//                                let case0 = cases[0]
//
//                                return """
//                                                let argument0: \(case0)?
//                                                if arguments.count == 0
//                                                {
//                                                    argument0 = nil
//                                                }
//                                                else
//                                                {
//                                                    argument0 = arguments[0]
//                                                }
//                                """.text
//                            }
//                            else
//                            {
//                                return """
//                                            let text0 = arguments[0]
//
//                                            let argument0 = \(field0)(text0)
//                                """.text
//                            }
//
//                        default:
//                            return """
//                                            let text0 = arguments[0]
//
//                                            let argument0 = \(field0)(text0)
//                            """.text
//                    }
//                }
//                else
//                {
//                    return """
//                        let text0 = arguments[0]
//
//                        let argument0 = \(argumentsTypeName)(text0)
//                    """.text
//                }
//
//            case .SingletonType(name: _):
//                return """
//                        let text0 = arguments[0]
//
//                        let argument0 = \(argumentsTypeName)(text0)
//                """.text
//        }
//    }
////
////    func argumentList(_ inputName: Text, _ argumentsTypeName: Text, _ namespace: Namespace) throws -> Text
////    {
////        let argumentsType = try namespace.resolve(argumentsTypeName)
////
////        switch argumentsType
////        {
////            case .Builtin(name: _, representation: _):
////                return "argument0"
////
////            case .Enum(name: _, cases: _):
////                return "argument0"
////
////            case .List(name: _, type: _):
////                return "argument0"
////
////            case .Record(name: _, fields: let fields):
////                if fields.count == 1
////                {
////                    let field0 = fields[0]
////
////                    let fieldType = try namespace.resolve(field0)
////
////                    switch fieldType
////                    {
////                        case .Builtin(name: _, representation: _):
////                            return "argument0"
////
////                        case .Record(name: _, fields: let fields):
////                            return fields.enumerated().map
////                            {
////                                index, element in
////
////                                return "argument\(index)"
////                            }.joined(separator: ", ").text
////
////                        case .List(name: _, type: let listType):
////                            return "parameters"
////
////                        case .Enum(name: _, cases: let cases):
////                            if cases.contains("Nothing")
////                            {
////                                return "argument0"
////                            }
////                            else
////                            {
////                                return fields.enumerated().map
////                                {
////                                    index, element in
////
////                                    return "argument\(index)"
////                                }.joined(separator: ", ").text
////                            }
////
////                        default:
////                            return fields.enumerated().map
////                            {
////                                index, element in
////
////                                return "argument\(index)"
////                            }.joined(separator: ", ").text                    }
////                }
////                else
////                {
////                    return fields.enumerated().map
////                    {
////                        index, element in
////
////                        return "argument\(index)"
////                    }.joined(separator: ", ").text                }
////
////            case .SingletonType(name: _):
////                return "argument0"
////        }
////    }
////
////}
////
////public enum ShellGeneratorError: Error
////{
////    case notFound(Text)
////    case wrongType
////    case badFormat
////}
