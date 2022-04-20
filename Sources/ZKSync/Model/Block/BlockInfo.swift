//
//  BlockInfo.swift
//  ZKSync
//
//  Created by Eugene Belyakov on 16/01/2021.
//

import Foundation

public struct BlockInfo: Decodable {
    public let blockNumber: Int
    public let committed: Bool
    public let verified: Bool
}
