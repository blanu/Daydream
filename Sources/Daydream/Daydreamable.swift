//
//  Daydreamable.swift
//  
//
//  Created by Dr. Brandon Wiley on 1/12/24.
//

import Foundation

public protocol Daydreamable
{
    var daydream: Data { get }
    init(daydream: Data) throws
}
