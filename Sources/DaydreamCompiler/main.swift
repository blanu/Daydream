//
//  main.swift
//  
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import ArgumentParser
import Foundation

import Daydream

struct DaydreamCompilerCommandLine: ParsableCommand
{
    @Argument(help: "Daydream type definition file to parse")
    var input: String

    @Argument(help: "Directory to write generated source code")
    var outputDirectory: String

    @Option(help: "platform for which code should be generated")
    var target: Target

    mutating func run() throws
    {
        let compiler = DaydreamCompiler(input: input, outputDirectory: outputDirectory)
        try compiler.compile(target)
    }
}

DaydreamCompilerCommandLine.main()

public enum DaydreamCompilerCommandLineError: Error
{
    case badWordSize(UInt8)
}
