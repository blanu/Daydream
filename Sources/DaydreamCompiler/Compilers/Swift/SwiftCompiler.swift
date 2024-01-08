//
//  SwiftCompiler.swift
//  
//
//  Created by Dr. Brandon Wiley on 12/23/23.
//

import Foundation

import Gardener
import Text

import Daydream

public class SwiftCompiler
{
    func compile(_ inputName: String, _ builtins: [Identifier], _ identifiers: [Identifier], _ namespace: Namespace, _ outputDirectory: URL) throws
    {
        print("Builtins:")
        for builtin in builtins
        {
            print(builtin)
        }

        print("====================")

        print("Identifiers:")
        for identifier in identifiers
        {
            print(identifier)
        }

        print("====================")

        print("Saving to \(outputDirectory)")

        try self.writeTypeIdentifiers(builtins, identifiers, namespace, outputDirectory)
        try self.writeService(inputName, builtins, identifiers, namespace, outputDirectory)
    }
}

public enum SwiftCompilerError: Error
{
}
