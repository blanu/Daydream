//
//  Daydreamable.swift
//  
//
//  Created by Dr. Brandon Wiley on 1/12/24.
//

import Foundation

import Transmission

public protocol Daydreamable
{
    init(daydream: Transmission.Connection) throws
    func saveDaydream(_ connection: Transmission.Connection) throws
}
