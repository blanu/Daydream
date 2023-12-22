//
//  main.swift
//  
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import ArgumentParser
import Foundation

struct DaydreamCompilerCommandLine: ParsableCommand
{
    @Argument(help: "Daydream type definition file to parse")
    var input: String

    @Argument(help: "Directory to write generated source code")
    var outputDirectory: String

    @Option(help: "Word size for VM in bytes")
    var wordSize: UInt8 = 8

    mutating func run() throws
    {
        guard let word = WordSize(rawValue: wordSize) else
        {
            throw DaydreamCompilerCommandLineError.badWordSize(wordSize)
        }

        let compiler = DaydreamCompiler(input: input, outputDirectory: outputDirectory)
        try compiler.compile(wordSize: word)
    }
}

DaydreamCompilerCommandLine.main()

public enum DaydreamCompilerCommandLineError: Error
{
    case badWordSize(UInt8)
}
