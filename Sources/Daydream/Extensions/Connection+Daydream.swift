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
    func write(_ data: Data, compression: Bool = false, metacount: Bool = false) throws
    {
        var payload = data
        if compression
        {
            payload = self.compress(payload)
        }

        try self.writeCount(payload, metacount: metacount)

        guard self.write(data: payload) else
        {
            throw ConnectionDaydreamError.writeFailed
        }
    }

    func writeCount(_ data: Data, metacount: Bool = false) throws
    {
        let count = data.count
        let countUInt64 = UInt64(count)
        let countUncompressed = countUInt64.maybeNetworkData!
        let countCompressed = self.compress(countUncompressed)

        if metacount
        {
            let metacountInt = countCompressed.count
            let metacountUInt8 = UInt8(metacountInt)
            let metacountData = metacountUInt8.maybeNetworkData!

            guard self.write(data: metacountData) else
            {
                throw ConnectionDaydreamError.writeFailed
            }
        }
        else
        {
            guard countCompressed.count == 1 else
            {
                throw ConnectionDaydreamError.countTooBig
            }
        }

        guard self.write(data: countCompressed) else
        {
            throw ConnectionDaydreamError.writeFailed
        }
    }

    func read(compression: Bool = false, metacount: Bool = false) throws -> Data
    {
        let count = try self.readCount(metacount: metacount)

        guard count > 0 else
        {
            return Data(repeating: 0, count: 8)
        }

        guard var payload = self.read(size: count) else
        {
            throw ConnectionDaydreamError.readFailed
        }

        if compression
        {
            payload = uncompress(payload)
        }

        return payload
    }

    func readCount(metacount: Bool = false) throws -> Int
    {
        if metacount
        {
            guard let compressedCountDataPrefix = self.read(size: 1) else
            {
                throw ConnectionDaydreamError.readFailed
            }

            let countPrefix = Int(compressedCountDataPrefix[0])

            guard countPrefix > 0 else
            {
                return 0
            }

            guard let compressedCountData = self.read(size: countPrefix) else
            {
                throw ConnectionDaydreamError.readFailed
            }

            let uncompressedCountData = uncompress(compressedCountData)
            guard let uint64 = UInt64(maybeNetworkData: uncompressedCountData) else
            {
                throw ConnectionDaydreamError.conversionFailed
            }

            return Int(uint64)
        }
        else
        {
            guard let countData = self.read(size: 1) else
            {
                throw ConnectionDaydreamError.readFailed
            }

            return Int(countData[0])
        }
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

public enum ConnectionDaydreamError: Error
{
    case countTooBig
    case readFailed
    case writeFailed
    case conversionFailed
}
