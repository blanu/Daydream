//
//  Connection+Daydream.swift
//
//
//  Created by Dr. Brandon Wiley on 1/15/24.
//

import Foundation

import Transmission

extension Transmission.Connection
{
    func write(_ data: Data, compression: Bool = false) throws
    {
        var payload = data
        if compression
        {
            payload = self.compress(payload)
        }

        try self.writeCount( payload)

        guard self.write(data: payload) else
        {
            throw ArrayError.writeFailed
        }
    }

    func writeCount(_ data: Data) throws
    {
        let count = data.count
        let countUInt64 = UInt64(count)
        let countUncompressed = countUInt64.maybeNetworkData!
        let countCompressed = self.compress(countUncompressed)

        let metacount = countCompressed.count
        let metacountUInt8 = UInt8(metacount)
        let metacountData = metacountUInt8.maybeNetworkData!

        guard self.write(data: metacountData) else
        {
            throw ArrayError.writeFailed
        }

        guard self.write(data: countCompressed) else
        {
            throw ArrayError.writeFailed
        }
    }

    func read(compression: Bool = false) throws -> Data
    {
        let count = try self.readCount()

        guard count > 0 else
        {
            return Data(repeating: 0, count: 8)
        }

        guard var payload = self.read(size: count) else
        {
            throw ArrayError.readFailed
        }

        if compression
        {
            payload = uncompress(payload)
        }

        return payload
    }

    func readCount() throws -> Int
    {
        guard let compressedCountDataPrefix = self.read(size: 1) else
        {
            throw ArrayError.readFailed
        }

        let countPrefix = Int(compressedCountDataPrefix[0])

        guard countPrefix > 0 else
        {
            return 0
        }

        guard let compressedCountData = self.read(size: countPrefix) else
        {
            throw ArrayError.readFailed
        }

        let uncompressedCountData = uncompress(compressedCountData)
        guard let uint64 = UInt64(maybeNetworkData: uncompressedCountData) else
        {
            throw ArrayError.conversionFailed
        }
        let count = Int(uint64)

        return count
    }

    func compress(_ uncompressed: Data) -> Data
    {
        guard uncompressed.count > 0 else
        {
            return uncompressed
        }

        var prefix = 0
        for index in 0..<uncompressed.count
        {
            if uncompressed[index] == 0
            {
                prefix += 1
            }
        }

        return Data(uncompressed[prefix...])
    }

    func uncompress(_ compressed: Data) -> Data
    {
        guard compressed.count > 0 else
        {
            return Data()
        }

        let mod8 = compressed.count % 8
        if mod8 == 0
        {
            return compressed
        }

        let gapSize = 8 - mod8
        let filler = Data(repeating: 0, count: gapSize)
        return filler + compressed
    }
}
