//
//  TransactionDetails.swift
//  ZKSync
//
//  Created by Eugene Belyakov on 16/01/2021.
//

import Foundation

public struct TransactionDetails: Decodable {
    public let executed: Bool
    public let success: Bool?
    public let failReason: String?
    public let block: BlockInfo?
}
