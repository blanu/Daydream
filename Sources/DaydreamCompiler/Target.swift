//
//  Target.swift
//
//
//  Created by Dr. Brandon Wiley on 12/18/23.
//

import Foundation

import ArgumentParser

public enum Target: String, Codable, ExpressibleByArgument, CaseIterable
{
    case swift
    case go
}
