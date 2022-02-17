//
//  Utils.swift
//  ZKSync
//
//  Created by Eugene Belyakov on 11/01/2021.
//

import Foundation
import BigInt

public enum SignerError: Error {
    case negativeNonce
    case accountNumberTooLarge
    case invalidAddress(String)
    case tokenIdTooBig
    case integerIsTooBig
    case incorrectPackedDecimalLength
    case feeNotPackable
    case amountNotPackable
}

public struct Utils {

    private static let MaxNumberOfAccounts: Int = 1 << 24
    private static let MaxNumberOfTokens = UInt32.max

    private static let FeeExponentBitWidth = 5
    private static let FeeMantissaBitWidth = 11

    private static let AmountExponentBitWidth = 5
    private static let AmountMantissaBitWidth = 35

    private static var Formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 18
        return formatter
    }()

    public static func nonceToBytes(_ nonce: UInt32) -> Data {
        return nonce.bytesBE()
    }

    public static func accountIdToBytes(_ accountId: UInt32) throws -> Data {
        if accountId > Utils.MaxNumberOfAccounts {
            throw SignerError.accountNumberTooLarge
        }
        return accountId.bytesBE()
    }

    public static func addressToBytes(_ address: String) throws -> Data {
        let addressWithoutPrefix = try removeAddressPrefix(address)
        let addressData = Data(hex: addressWithoutPrefix)
        if addressData.count != 20 {
            throw SignerError.invalidAddress("Address must be 20 bytes long")
        }
        return addressData
    }

    public static func tokenIdToBytes(_ tokenId: UInt32) throws -> Data {
        if tokenId >= Utils.MaxNumberOfTokens {
            throw SignerError.tokenIdTooBig
        }
        return tokenId.bytesBE()
    }

    public static func amountFullToBytes(_ amount: BigUInt) -> Data {
        let amountData = BigInt(amount).serialize()
        var data = Data(repeating: 0x00, count: 16 - amountData.count)
        data.append(amountData)
        return data
    }

    public static func feeToBytes(_ fee: BigUInt) throws -> Data {
        return try packFeeChecked(fee)
    }

    public static func amountPackedToBytes(_ amount: BigUInt) throws -> Data {
        return try packAmountChecked(amount)
    }

    public static func numberToBytesBE<T: BinaryInteger>(_ number: T, numBytes: Int) -> Data {
        var result = Data(repeating: 0, count: numBytes)
        var numberToPack = number
        for index in (0...(numBytes - 1)).reversed() {
            result[index] = UInt8((numberToPack & 0xff))
            numberToPack >>= 8
        }
        return result
    }

    public static func packFeeChecked(_ fee: BigUInt) throws -> Data {
        if try closestPackableTransactionFee(fee).description != fee.description {
            throw SignerError.feeNotPackable
        }
        return try packFee(fee)
    }

    public static func packAmountChecked(_ amount: BigUInt) throws -> Data {
        if try closestPackableTransactionAmount(amount).description != amount.description {
            throw SignerError.amountNotPackable
        }
        return try packAmount(amount)
    }

    public static func closestPackableTransactionFee(_ fee: BigUInt) throws -> BigUInt {
        let packedFee = try packFee(fee)
        return try decimalByteArrayToInteger(packedFee,
                                             expBits: FeeExponentBitWidth,
                                             mantissaBits: FeeMantissaBitWidth,
                                             expBase: 10)
    }

    public static func closestPackableTransactionAmount(_ amount: BigUInt) throws -> BigUInt {
        let packedAmount = try packAmount(amount)
        return try decimalByteArrayToInteger(packedAmount,
                                             expBits: AmountExponentBitWidth,
                                             mantissaBits: AmountMantissaBitWidth,
                                             expBase: 10)
    }

    public static func packFee(_ fee: BigUInt) throws -> Data {
        return reverseBits(try integerToDecimalByteArray(fee,
                                                         expBits: FeeExponentBitWidth,
                                                         mantissaBits: FeeMantissaBitWidth,
                                                         expBase: 10))
    }

    public static func packAmount(_ amount: BigUInt) throws -> Data {
        return reverseBits(try integerToDecimalByteArray(amount,
                                                         expBits: AmountExponentBitWidth,
                                                         mantissaBits: AmountMantissaBitWidth,
                                                         expBase: 10))
    }

    public static func decimalByteArrayToInteger(_ decimalBytes: Data,
                                          expBits: Int,
                                          mantissaBits: Int,
                                          expBase: Int) throws -> BigUInt {
        if decimalBytes.count * 8 != mantissaBits + expBits {
            throw SignerError.incorrectPackedDecimalLength
        }

        let bits = Bits(dataBEOrder: decimalBytes).reversed

        var exponentValue = 0
        var expPow2 = 1

        for index in 0..<expBits {
            exponentValue += bits[index] ? expPow2 : 0
            expPow2 *= 2
        }
        let exponent = BigUInt(expBase).power(exponentValue)

        var mantissa = BigUInt.zero
        var mantissaPow2 = BigUInt.one

        for index in expBits..<(expBits + mantissaBits) {
            mantissa += bits[index] ? mantissaPow2 : 0
            mantissaPow2 *= 2
        }

        return exponent * mantissa
    }

    public static func reverseBits(_ data: Data) -> Data {
        Data(data.reversed().map { $0.bitReversed })
    }

    public static func integerToDecimalByteArray(_ value: BigUInt,
                                          expBits: Int,
                                          mantissaBits: Int,
                                          expBase: Int) throws -> Data {

        let maxExponent = BigUInt.ten.power(Int(BigUInt.two.power(expBits).subtracting(.one)))
        let maxMantissa = BigUInt.two.power(mantissaBits).subtracting(.one)

        if value > maxMantissa.multiplied(by: maxExponent) {
            throw SignerError.integerIsTooBig
        }

        var exponent = UInt64(0)
        var mantissa = value

        while mantissa > maxMantissa {
            mantissa /= BigUInt(expBase)
            exponent += 1
        }

        let exponentBitSet = numberToBitsLE(exponent, numBits: expBits)
        let mantissaBitSet = numberToBitsLE(UInt64(mantissa), numBits: mantissaBits)
        let reversed = (exponentBitSet + mantissaBitSet).reversed

        return reverseBits(try reversed.bytesBEOrder())
    }

    static func numberToBitsLE(_ number: UInt64, numBits: Int) -> Bits {
        var numberToConvert = number
        var bits = Bits(size: numBits)
        for index in 0..<numBits {
            if (numberToConvert & 1) == 1 {
                bits.set(index: index)
            }
            numberToConvert >>= 1
        }
        return bits
    }

    public static func reverseBytes(_ data: Data) -> Data {
        return Data(data.reversed())
    }

    public static func removeAddressPrefix(_ address: String) throws -> String {
        if address.hasHexPrefix() {
            return address.stripHexPrefix()
        }

        if address.hasPubKeyHashPrefix() {
            return address.stripPubKeyHashPrefix()
        }

        throw SignerError.invalidAddress("ETH address must start with '0x' and PubKeyHash must start with 'sync:'")
    }

    public static func format(_ value: Decimal) -> String {
        return Utils.Formatter.string(from: value as NSDecimalNumber)!
    }

    public static func currentTimeMillis() -> Int64 {
        var darwinTime: timeval = timeval(tv_sec: 0, tv_usec: 0)
        gettimeofday(&darwinTime, nil)
        return (Int64(darwinTime.tv_sec) * 1000) + Int64(darwinTime.tv_usec / 1000)
    }
}
