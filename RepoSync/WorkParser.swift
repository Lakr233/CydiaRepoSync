//
//  WorkParser.swift
//  RepoSync
//
//  Created by Lakr Aream on 2021/7/11.
//  Copyright © 2021 Lakr Aream. All rights reserved.
//

import Foundation
import SWCompression

class WorkParser {
    static let shared = WorkParser()

    let release: String
    let package: String

    //                已经存在的 文件名      md5 sha1 sha256 filename
    var alreadyExistsPackages: [String: (String, String, String)] = [:]

    private init() {
        let semRelease = DispatchSemaphore(value: 0)
        let semIcon = DispatchSemaphore(value: 0)
        let semPackage = DispatchSemaphore(value: 0)

        var getRelease: String?
        var getPackage: String?

        DispatchQueue.global().async {
            let request = createCydiaRequest(url: ArgumentParser.shared.url.appendingPathComponent("Release"))
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let task = session.dataTask(with: request) { data, respond, error in
                if error == nil, let data = data, let resp = respond as? HTTPURLResponse {
                    if resp.statusCode != 200 {
                        print("[E] Failed to get repo release, server returned " + String(resp.statusCode))
                    } else {
                        if let str = String(data: data, encoding: .utf8) {
                            getRelease = str
                        } else if let str = String(data: data, encoding: .ascii) {
                            getRelease = str
                        } else {
                            print("[E] Decode failed, ignored")
                        }
                    }
                }
                semRelease.signal()
            }
            task.resume()
        }

        DispatchQueue.global().async {
            let request = createCydiaRequest(url: ArgumentParser.shared.url.appendingPathComponent("CydiaIcon.png"))
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let task = session.dataTask(with: request) { data, respond, error in
                if error == nil, let data = data, let resp = respond as? HTTPURLResponse {
                    if resp.statusCode != 200 {
                        print("[E] Failed to get repo icon, server returned " + String(resp.statusCode))
                    } else {
                        do {
                            try data.write(to: ArgumentParser.shared.output.appendingPathComponent("CydiaIcon.png"))
                        } catch {
                            print("[E] Failed to write CydiaIcon.png data")
                        }
                    }
                }
                semIcon.signal()
            }
            task.resume()
        }

        let search = ["bz2", "", "xz", "gz", "lzma", "lzma2", "bz", "xz2", "gz2"]

        // 小心菊花
        let sync = DispatchQueue(label: "watch.our.ass")
        for item in search {
            DispatchQueue.global().async {
                let request: URLRequest
                if item == "" {
                    request = createCydiaRequest(url: ArgumentParser.shared.url.appendingPathComponent("Packages"))
                } else {
                    request = createCydiaRequest(url: ArgumentParser.shared.url.appendingPathComponent("Packages." + item))
                }
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
                let task = session.dataTask(with: request) { data, respond, error in
                    if error == nil, let data = data, let resp = respond as? HTTPURLResponse {
                        if resp.statusCode != 200 {
                            print("[E] Failed to get repo meta data, server returned " + String(resp.statusCode) + " when looking for ." + item)
                        } else {
                            let decode: Data?
                            switch item {
                            case "":
                                decode = data
                            case "bz2", "bz":
                                decode = try? BZip2.decompress(data: data)
                            case "gz", "gz2":
                                decode = try? GzipArchive.unarchive(archive: data)
                            case "xz", "xz2":
                                decode = try? XZArchive.unarchive(archive: data)
                            case "lzma":
                                decode = try? LZMA.decompress(data: data)
                            case "lzma2":
                                decode = try? LZMA2.decompress(data: data)
                            default:
                                fatalError("\nUnknown data format passed to vender function")
                            }
                            if let decoded = decode {
                                if var str = String(data: decoded, encoding: .utf8), !str.hasPrefix("<!DOCTYPE html>") {
                                    str.cleanAndReplaceLineBreaker()
                                    sync.sync {
                                        getPackage = str
                                        semPackage.signal()
                                    }
                                    return
                                } else if var str = String(data: decoded, encoding: .ascii), !str.hasPrefix("<!DOCTYPE html>") {
                                    str.cleanAndReplaceLineBreaker()
                                    sync.sync {
                                        getPackage = str
                                        semPackage.signal()
                                    }
                                    return
                                } else {
                                    print("[E] Decode failed, ignored")
                                }
                            }
                        }
                    }
                }
                task.resume()
            }
        }

        _ = semRelease.wait(timeout: .now() + Double(ArgumentParser.shared.timeout))
        _ = semIcon.wait(timeout: .now() + Double(ArgumentParser.shared.timeout))
        _ = semPackage.wait(timeout: .now() + Double(ArgumentParser.shared.timeout * search.count))

        if getRelease != nil {
            release = getRelease!
        } else {
            release = ""
        }

        assert(getPackage != nil, "\nFailed to download packages' meta data")
        package = getPackage!

        if release != "" {
            try? FileManager.default.removeItem(at: ArgumentParser.shared.output.appendingPathComponent("Release.txt"))
            try? release.write(to: ArgumentParser.shared.output.appendingPathComponent("Release.txt"), atomically: true, encoding: .utf8)
        }

        do {
            let loc = ArgumentParser.shared.output.appendingPathComponent("Packages.txt")
            if FileManager.default.fileExists(atPath: String(loc.path)) {
                try FileManager.default.removeItem(at: ArgumentParser.shared.output.appendingPathComponent("Packages.txt"))
            }
            try package.write(to: ArgumentParser.shared.output.appendingPathComponent("Packages.txt"), atomically: true, encoding: .utf8)
        } catch {
            fatalError("\nCannot write package file to output location, maybe permission denied")
        }

        print("\n\n🎉 Congratulations! Repo is validated!\n\n")
        print("Invoking package metadata, this will take some times...")

        let packages = prepareGlobalPackageMetas(meta: package)

        if !ArgumentParser.shared.overwrite {
            print("Analyzing local packages, this will take some times...")
            // 先获取存在的软件包
            let loc = ArgumentParser.shared.output.appendingPathComponent("debs").path
            let contents = try? FileManager.default.contentsOfDirectory(atPath: loc)

            if ArgumentParser.shared.namematch {
                // 读取所有本地文件并构建校验列表
                for item in contents ?? [] {
                    alreadyExistsPackages[item] = ("*", "*", "*")
                }
            } else {
                // 读取所有本地文件并构建校验列表
                for item in contents ?? [] {
                    let fullLocation = loc + "/" + item
                    let read = try? Data(contentsOf: URL(fileURLWithPath: fullLocation))
                    if let read = read {
                        // 读取成功！开始计算
                        let md5 = computeCharacteristicWithMD5(data: read)
                        let sha1 = computeCharacteristicWithSHA1(data: read)
                        let sha256 = computeCharacteristicWithSHA256(data: read)
                        alreadyExistsPackages[item] = (md5, sha1, sha256)
                    }
                }
            }

            print("\n\n🎉 Congratulations! Analyze completed!\n")
        }

        // 如果开了覆盖不可能出现数据
        if alreadyExistsPackages.count > 0 {
            // 重新构建软件包咯
            var temp: [String: Pack] = [:]
            flag233: for item in packages { // item -> pack
                flag234: for version in item.info { // \-> version -> [String : [String : String]
                    var everFoundMatch = false
                    var matchName = ""

                    if ArgumentParser.shared.namematch {
                        flag236: for packageName in alreadyExistsPackages.keys {
                            if let filename = version.value["filename"],
                               filename.hasSuffix(packageName)
                            { // 偷懒一下！
                                everFoundMatch = true
                                break flag236
                            }
                        }
                    } else {
                        flag235: for sumObject in alreadyExistsPackages { // sumObject -> String : (String, String, String)
                            // 注意这里不检查深度
                            // 这里开始核验校验数据是否出现在记录中
                            var recordMatch = 3 //  3 = record not found
                            // -1 = record match failed
                            //  1 = record found and matches at least once
                            if recordMatch > 0, let md5Record = version.value["md5sum"] {
                                if md5Record == sumObject.value.0 {
                                    recordMatch = 1
                                } else {
                                    recordMatch = -1
                                }
                            }
                            if recordMatch > 0, let sha1Record = version.value["sha1"] {
                                if sha1Record == sumObject.value.1 {
                                    recordMatch = 1
                                } else {
                                    recordMatch = -1
                                }
                            }
                            if recordMatch > 0, let sha256Record = version.value["sha256"] {
                                if sha256Record == sumObject.value.2 {
                                    recordMatch = 1
                                } else {
                                    recordMatch = -1
                                }
                            }
                            // 任何一次失败的校验都会置-1并跳过接下来的比对
                            if recordMatch == 1 {
                                everFoundMatch = true
                                matchName = sumObject.key
                            }
                        }
                    }

                    if everFoundMatch {
                        if ArgumentParser.shared.namematch {
                            print("Skipping due to name matches at package: " + item.id + "\n" +
                                "                             at version: " + version.key)
                        } else {
                            print("Skipping due to sum matches at package: " + item.id + "\n" +
                                "                            at version: " + version.key)
                        }
                        if ArgumentParser.shared.rename {
                            // 先获缓存位置
                            let loc = ArgumentParser.shared.output.appendingPathComponent("debs").path
                            let origString = loc + "/" + matchName
                            // 获取远端文件名
                            if FileManager.default.fileExists(atPath: origString),
                               let target = version.value["filename"],
                               let filePath = URL(string: target)
                            {
                                let fileName = filePath.lastPathComponent
                                let newString = loc + "/" + fileName
                                // 重命名一下咯
                                if newString != origString {
                                    do {
                                        try FileManager.default.moveItem(atPath: origString, toPath: newString)
                                        print("                            renamed!")
                                    } catch {
                                        print("                            rename failed!")
                                    }
                                }
                            }
                        }
                    } else {
                        // 没找到咯那就重新下载
                        if let object = temp[item.id] {
                            // 这说明temp中有这个软件包了 我们添加一个版本
                            var ver: [String: [String: String]] = [:]
                            for ooo in object.info {
                                ver[ooo.key] = ooo.value
                            }
                            ver[version.key] = version.value
                            let new = Pack(id: item.id, info: ver)
                            temp[item.id] = new
                        } else {
                            temp[item.id] = Pack(id: item.id, info: [version.key: version.value])
                        }
                    }
                }
            }
            for item in temp {
                nPackageContainer.append(item.value)
            }
        } else {
            alreadyExistsPackages = [:]
            nPackageContainer = packages
        }

        // 检查下载的depth
        if ArgumentParser.shared.depth > 0 {
            var temp: [Pack] = []
            let depth = ArgumentParser.shared.depth
            let dpkgAgent = PackageOperator()
            for object in nPackageContainer {
                // 获取这个软件包的全部版本
                let versionStrings = object.info.keys
                // 排序
                let what = versionStrings.sorted { A, B -> Bool in
                    dpkgAgent.compareVersionA(A, andB: B) == 1
                }
                var createdNewVersionKeys: [String] = []
                var count = 0
                flag2: for item in what {
                    createdNewVersionKeys.append(item)
                    count += 1
                    if count >= depth {
                        break flag2
                    }
                }
                // 创建新的versionkeys
                var newVersion: [String: [String: String]] = [:]
                for item in createdNewVersionKeys {
                    newVersion[item] = object.info[item]
                }
                // 合成符合要求的deb
                let new = Pack(id: object.id, info: newVersion)
                temp.append(new)
            }
            nPackageContainer = temp
        }
    }

    func initPrint() {
        print("\n--- SUMMARY ---\n")
        print(String(nPackageContainer.count) + " packages to download in total")
        print("\n--- SUMMARY ---\n")
    }

    func download(from: URL, to: URL, md5: String? = nil, sha1: String? = nil, sha256: String? = nil) {
        let sem = DispatchSemaphore(value: 0)
        // 开始下载

        DispatchQueue.global().async {
            let request = createCydiaRequest(url: from, slient: true)
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let task = session.dataTask(with: request) { data, respond, error in
                if error == nil, let data = data, let resp = respond as? HTTPURLResponse {
                    if resp.statusCode != 200 {
                        print("[E] Failed to get repo release, server returned " + String(resp.statusCode))
                        nErrorIndicators.append("Failed to download from: " + from.path)
                    } else {
                        if !ArgumentParser.shared.skipsum {
                            // 校验数据
                            var failed = false
                            if let md5 = md5 {
                                if md5.lowercased() != computeCharacteristicWithMD5(data: data).lowercased() {
                                    nErrorIndicators.append("MD5 failed at: " + from.path)
                                    failed = true
                                }
                            }
                            if let sha1 = sha1 {
                                if sha1.lowercased() != computeCharacteristicWithSHA1(data: data).lowercased() {
                                    nErrorIndicators.append("SHA1 failed at: " + from.path)
                                    failed = true
                                }
                            }
                            if let sha256 = sha256 {
                                if sha256.lowercased() != computeCharacteristicWithSHA256(data: data).lowercased() {
                                    nErrorIndicators.append("SHA256 failed at: " + from.path)
                                    failed = true
                                }
                            }
                            if failed {
                                print(" [E]: Failed to write package due to broken data found, skipped")
                            } else {
                                do {
                                    try data.write(to: to)
                                } catch {
                                    print(" [E]: Failed to write package data, skipped")
                                    nErrorIndicators.append("Failed to download from: " + from.path)
                                }
                            }
                        } else {
                            do {
                                try data.write(to: to)
                            } catch {
                                print(" [E]: Failed to write package data, skipped")
                                nErrorIndicators.append("Failed to download from: " + from.path)
                            }
                        }
                    }
                }
                sem.signal()
            }
            task.resume()
        }
        // 超时由URLTask处理
        sem.wait()
    }
}
