//
//  File.swift
//  
//
//  Created by Dr. Brandon Wiley on 1/25/24.
//

import Foundation

import Blueprint
import Gardener
import Text

import Daydream

extension SwiftCompiler
{
    func writeMainBlueprint(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        let outputPath = outputDirectory.appending(path: "main.swift")

        let template = SourceFile(
            header: FileHeader(filename: "main"),
            imports: ImportSection(
                globals: [.BigNumber, .Hex, .Logging, .RadioWave, .Text],
                locals: ["ArgumentParser", "FileLogging", "Foundation", "Datable"]
            ),
            structs: [
                Structure(passing: .value, visibility: .public, name: "\(inputName)CommandLine".text, inherits: [], implements: ["ParsableCommand"], properties:
                [
                    Property(isStatic: true, visibility: .private, name: "configuration", initializer: .constructorCall(
                        ConstructorCall(name: "CommandConfiguration", arguments:
                        [
                            Argument(label: "commandName", value: .literal(.string(inputName.text))),
                            Argument(label: "subcommands", value: .literal(.array([.type(.named("Shell")), .type(.named("Service"))])))
                        ])
                    ))
                ])
            ],
            extensions: [
                Extension(name: "\(inputName)CommandLine".text, structures: [
                    Structure(name: "Shell", implements: ["ParsableCommand"],
                        properties: [
                            Property(
                                annotation: Annotation(
                                    name: "Argument",
                                    parameters: [AnnotationParameter(name: "help", value: .string("host name of server"))]
                                ),
                                mutability: .mutable, name: "host", type: .named("String")
                            ),
                            Property(
                                annotation: Annotation(
                                    name: "Argument",
                                    parameters: [AnnotationParameter(name: "help", value: .string("port for server"))]
                                ),
                                mutability: .mutable, name: "port", type: .named("Int")
                            ),
                        ],
                        functions: [
                            Function(mutating: true, name: "run", throwing: true, statements: [
                                .assignment(
                                    .variableDefinition(VariableDefinition(name: "cwd")),
                                    .value(.variable("FileManager.default.currentDirectoryPath"))
                                ),
                                .assignment(
                                    .variableDefinition(VariableDefinition(name: "cwdURL")),
                                        .constructorCall(ConstructorCall(name: "URL", arguments: [
                                            Argument(label: "fileURLWithPath", value: .variable("cwd"))
                                        ])
                                    )
                                ),
                                .assignment(.variableDefinition(VariableDefinition(name: "logURL")), .functionCall(FunctionCall(name: "cwdURL.appendingPathComponent", arguments: [
                                    Argument(value: .literal(.string("\(inputName)Shell.log".text)))
                                ]))),
                                .assignment(
                                    .variableDefinition(VariableDefinition(mutability: .mutable, name: "logger")),
                                    .functionCall(FunctionCall(trying: true, name: "FileLogging.logger", arguments: [
                                        Argument(label: "label", value: .literal(.string("\(inputName)Shell".text))),
                                        Argument(label: "localFile", value: .variable("logURL"))
                                    ]))
                                ),
                                .assignment(.variable("logger.logLevel"), .value(.variable(".trace"))),
                                .blank,
                                .expression(.functionCall(FunctionCall(name: "logger.debug", arguments: [
                                    Argument(value: .literal(.string("\(inputName)Shell start.".text)))
                                ]))),
                                .blank,
                                .assignment(.variableDefinition(VariableDefinition(name: "_")),
                                            .constructorCall(ConstructorCall(trying: true, name: "\(inputName)Shell".text, arguments: [
                                        Argument(label: "host", value: .variable("host")),
                                        Argument(label: "port", value: .variable("port")),
                                        Argument(label: "logger", value: .variable("logger")),
                                    ]))
                                )
                            ])
                        ]
                    )
                ]),
                Extension(name: "\(inputName)CommandLine".text, structures: [
                    Structure(name: "Service", implements: ["ParsableCommand"], functions:
                    [
                        Function(mutating: true, name: "run", throwing: true, statements:
                        [
                            .expression(.functionCall(FunctionCall(name: "logger.debug", arguments:
                            [
                                Argument(value: .literal(.string("\(inputName)Server start.".text)))
                            ]))),
                            .blank,
                            .assignment(
                                .variableDefinition(VariableDefinition(name: "_")),
                                .functionCall(FunctionCall(trying: true, name: "\(inputName)Service".text, arguments: [
                                    Argument(label: "logger", value: .literal(.string("logger")))
                                ]))
                            )
                        ])
                    ])
                ])
            ],
            statements: [
                .expression(.functionCall(FunctionCall(name: "\(inputName)CommandLine.main()".text)))
            ]
        )

        let data = try template.transpile(.swift).toUTF8Data()
        try data.write(to: outputPath)
    }
}
