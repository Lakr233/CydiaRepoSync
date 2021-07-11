//
//  Function.swift
//  RepoSync
//
//  Created by Lakr Aream on 2021/7/11.
//  Copyright © 2021 Lakr Aream. All rights reserved.
//

import CommonCrypto
import Foundation

func examinePackageMetaAndBuild(meta: String) -> Pack? {
    guard let meta = PackageOperator.sharedInstance().invokeMeta(context: meta) else {
        print("[?] Failed to load package with empty metadata")
        return nil
    }
    if meta.count < 1 {
        return nil
    }
    guard let ver = meta["version"] else {
        print("[E] Invalid meta ignored: missing version string")
        return nil
    }
    guard let id = meta["package"] else {
        print("[E] Invalid meta ignored: missing package string")
        return nil
    }
    guard let _ = meta["filename"] else {
        print("[E] Invalid meta ignored: missing download location")
        return nil
    }
    return Pack(id: id, info: [ver: meta])
}

func prepareGlobalPackageMetas(meta: String) -> [Pack] {
    var container: [String: Pack] = [:]
    for item in meta.components(separatedBy: "\n\n") {
        if let pack = examinePackageMetaAndBuild(meta: item) {
            if container[pack.id] != nil {
                container[pack.id]!.info[pack.info.first!.key] = pack.info.first!.value
            } else {
                container[pack.id] = pack
            }
        }
    }
    var ret: [Pack] = []
    for item in container {
        ret.append(item.value)
    }
    return ret
}

func getAbsoluteURL(location: String) -> URL {
    let path = location.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path)
    }
    let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let ret = URL(fileURLWithPath: path, relativeTo: current)
    return ret
}

func createCydiaRequest(url: URL, slient: Bool = false) -> URLRequest {
    if !slient {
        print("[CydiaRequest] Requesting GET to -> " + url.path)
    }

    var request: URLRequest
    request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: TimeInterval(ArgumentParser.shared.timeout))

    if ArgumentParser.shared.mess {
        request.setValue([
            "iPhone6,1", "iPhone6,2", "iPhone7,2", "iPhone7,1", "iPhone8,1", "iPhone8,2", "iPhone9,1", "iPhone9,3", "iPhone9,2", "iPhone9,4", "iPhone8,4", "iPhone10,1", "iPhone10,4", "iPhone10,2", "iPhone10,5", "iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8", "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4", "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6", "iPad6,11", "iPad6,12", "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12", "iPad4,1", "iPad4,2", "iPad4,3", "iPad5,3", "iPad5,4", "iPad11,4", "iPad11,5", "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7", "iPad4,8", "iPad4,9", "iPad5,1", "iPad5,2", "iPad11,1", "iPad11,2", "iPad6,3", "iPad6,4", "iPad7,3", "iPad7,4", "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,9", "iPad8,10", "iPad6,7", "iPad6,8", "iPad7,1", "iPad7,2", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8", "iPad8,11", "iPad8,12",
        ].randomElement(), forHTTPHeaderField: "X-Machine")

        var udid = ""
        while udid.count < "E667727230424CEDAB64C41DF94536E7DF94536E".count {
            udid += UUID().uuidString.dropLast("-3042-4CED-AB64-C41DF94536E7".count)
        }
        while udid.count > "E667727230424CEDAB64C41DF94536E7DF94536E".count {
            udid = String(udid.dropLast())
        }
        udid = udid.lowercased()
        request.setValue(udid, forHTTPHeaderField: "X-Unique-ID")
        request.setValue([
            "13.0", "13.1", "13.2", "13.3", "13.4",
            "12.0", "12.1", "12.2", "12.3", "12.4",
            "11.0", "11.1", "11.2", "11.3", "11.4",
        ].randomElement(), forHTTPHeaderField: "X-Firmware")
        request.setValue("Telesphoreo APT-HTTP/1.0." + String(Int.random(in: 580 ... 620)), forHTTPHeaderField: "User-Agent")
    } else {
        request.setValue(ArgumentParser.shared.udid, forHTTPHeaderField: "X-Unique-ID")
        request.setValue(ArgumentParser.shared.machine, forHTTPHeaderField: "X-Machine")
        request.setValue(ArgumentParser.shared.firmware, forHTTPHeaderField: "X-Firmware")
        request.setValue(ArgumentParser.shared.ua, forHTTPHeaderField: "User-Agent")
    }

    request.httpMethod = "GET"

    return request
}

func computeCharacteristicWithMD5(data: Data) -> String {
    let length = Int(CC_MD5_DIGEST_LENGTH)
    let messageData = data
    var digestData = Data(count: length)
    _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
        messageData.withUnsafeBytes { messageBytes -> UInt8 in
            if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                let messageLength = CC_LONG(messageData.count)
                CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
            }
            return 0
        }
    }
    let md5Hex = digestData.map { String(format: "%02hhx", $0) }.joined()
    return md5Hex
}

func computeCharacteristicWithSHA1(data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
    }
    let hexBytes = digest.map { String(format: "%02hhx", $0) }
    let sha1Hex = hexBytes.joined()
    return sha1Hex
}

func computeCharacteristicWithSHA256(data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
    }
    let hexBytes = digest.map { String(format: "%02hhx", $0) }
    let sha256Hex = hexBytes.joined()
    return sha256Hex
}
