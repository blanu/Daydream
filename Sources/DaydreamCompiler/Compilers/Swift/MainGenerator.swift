//
//  MainGenerator.swift
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
    func writeMain(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        let outputPath = outputDirectory.appending(path: "main.swift")

        let template = """
        //
        //  main.swift
        //
        //
        //  Created by the Daydream Compiler on \(Date()).
        //

        import ArgumentParser
        import FileLogging
        import Foundation
        import Logging

        import BigNumber
        import Datable
        import RadioWave
        import SwiftHexTools
        import Text

        struct \(inputName)CommandLine: ParsableCommand
        {
            static let configuration = CommandConfiguration(
                commandName: "\(inputName)",
                subcommands: [Shell.self, Service.self]
            )
        }

        extension \(inputName)CommandLine
        {
            struct Shell: ParsableCommand
            {
                @Argument(help: "host name of server")
                var host: String

                @Argument(help: "port for server")
                var port: Int

                mutating public func run() throws
                {
                    let cwd = FileManager.default.currentDirectoryPath
                    let cwdURL = URL(fileURLWithPath: cwd)
                    let logURL = cwdURL.appendingPathComponent("\(inputName)Shell.log")
                    var logger = try FileLogging.logger(label: "\(inputName)Shell", localFile: logURL)
                    logger.logLevel = .trace

                    logger.debug("\(inputName)Shell start.")

                    let _ = try \(inputName)Shell(host: host, port: port, logger: logger)
                }
            }
        }

        extension \(inputName)CommandLine
        {
            struct Service: ParsableCommand
            {
                mutating public func run() throws
                {
                    let cwd = FileManager.default.currentDirectoryPath
                    let cwdURL = URL(fileURLWithPath: cwd)
                    let logURL = cwdURL.appendingPathComponent("\(inputName)Service.log")
                    var logger = try FileLogging.logger(label: "\(inputName)Service", localFile: logURL)
                    logger.logLevel = .trace

                    logger.debug("\(inputName)Service start.")

                    let _ = try \(inputName)Service(logger: logger)
                }
            }
        }

        \(inputName)CommandLine.main()
        """

        let data = template.data
        try data.write(to: outputPath)
    }
}

public enum MainGeneratorError: Error
{
    case notFound(Text)
    case wrongType
    case badFormat
}
