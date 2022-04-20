//
//  NFT.swift
//  ZKSync
//
//  Created by Eugene Belyakov on 20/05/2021.
//

import Foundation
import BigInt

public struct NFT: TokenId, Decodable {

    public let id: UInt32
    public let symbol: String
    public let creatorId: UInt32
    public let contentHash: String
    public let creatorAddress: String

    public let serialId: UInt32

    public let address: String

    public init(
        id: UInt32,
        symbol: String,
        creatorId: UInt32,
        contentHash: String,
        creatorAddress: String,
        serialId: UInt32,
        address: String
    ) {
        self.id = id
        self.symbol = symbol
        self.creatorId = creatorId
        self.contentHash = contentHash
        self.creatorAddress = creatorAddress
        self.serialId = serialId
        self.address = address
    }

    public func intoDecimal(_ amount: BigUInt) -> Decimal {
        let sourceDecimal = Decimal(string: "\(amount)")!
        return  sourceDecimal / pow(Decimal(1), 1)
    }
}
