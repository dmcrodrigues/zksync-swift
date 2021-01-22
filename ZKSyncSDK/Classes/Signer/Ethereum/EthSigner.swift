//
//  EthSigner.swift
//  ZKSyncSDK
//
//  Created by Eugene Belyakov on 06/01/2021.
//

import Foundation
import web3swift
import CryptoSwift
import BigInt

public protocol EthSigner {
    
    var address: String { get }
    
    func signChangePubKey(pubKeyHash: String, nonce: Int32, accountId: Int32) throws -> EthSignature
    
    func signTransfer(to: String, accountId: Int32, nonce: Int32, amount: BigUInt, token: Token, fee: BigUInt) throws -> EthSignature
    
    func signWithdraw(to: String, accountId: Int32, nonce: Int32, amount: BigUInt, token: Token, fee: BigUInt) throws -> EthSignature
    
    func sign(message: String) throws -> EthSignature
    
    func verifySignature(_ signature: EthSignature, message: String) throws -> Bool
}
