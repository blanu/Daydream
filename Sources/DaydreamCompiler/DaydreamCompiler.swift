//
//  DaydreamCompiler.swift
//
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import Foundation

import Gardener
import Text

import Daydream

public class DaydreamCompiler
{
    public let input: String
    public let outputDirectory: String

    public init(input: String, outputDirectory: String)
    {
        self.input = input
        self.outputDirectory = outputDirectory
    }

    public func compile(_ target: Target) throws
    {
        guard File.exists(self.input) else
        {
            throw DaydreamCompilerError.doesNotExist(self.input)
        }

        guard File.exists(self.outputDirectory) else
        {
            throw DaydreamCompilerError.doesNotExist(self.outputDirectory)
        }

        let inputURL = URL(fileURLWithPath: self.input)
        let inputData = try Data(contentsOf: inputURL)
        let inputText = Text(fromUTF8Data: inputData)

        let outputURL = URL(fileURLWithPath: self.outputDirectory)

        let parser = Parser()
        let types = parser.parse(inputText)
        let namespace = try Namespace(types: types)
        try namespace.validate()

        let sorted = namespace.sorted()

        let builtins: [Identifier] = [
            Identifier(name: "Singleton", identifier: 1),
        ]

        var identifiers: [Identifier] = []

        var index: Int = 6
        for type in sorted
        {
            let identifier = Identifier(name: type, identifier: index)
            identifiers.append(identifier)
            index += 1
        }

        switch target
        {
            case .swift:
                let compiler = SwiftCompiler()
                try compiler.compile(builtins, identifiers, namespace, outputURL)

            case .go:
                return
//                let compiler = GoCompiler()
//                try compiler.compile(builtins, identifiers, namespace, outputURL)
        }

    }
}

public enum DaydreamCompilerError: Error
{
    case doesNotExist(String)
    case tooManyTypes
}
