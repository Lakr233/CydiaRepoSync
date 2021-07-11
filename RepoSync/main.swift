//
//  main.swift
//  RepoSync
//
//  Created by Lakr Aream on 2020/4/12.
//  Copyright © 2020 Lakr Aream. All rights reserved.
//

import CommonCrypto
import Foundation

var nPackageContainer: [Pack] = []
var nErrorIndicators: [String] = []

// 初始化配置
ArgumentParser.shared.printConfig()

// 输出文件组织
// output dir:
//    |
//    |-> Release       plain text if exists
//    |-> Packages      plain text if exists
//    |-> debs          packages

// 初始化输出目录
do {
    do {
        var isDir = ObjCBool(booleanLiteral: false)
        if FileManager.default.fileExists(atPath: String(ArgumentParser.shared.output.path), isDirectory: &isDir) {
            assert(isDir.boolValue, "\nOutput location must be a folder")
            if ArgumentParser.shared.clean {
                do {
                    try FileManager.default.removeItem(at: ArgumentParser.shared.output)
                    try FileManager.default.createDirectory(at: ArgumentParser.shared.output, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fatalError("\nCannot clean output location, maybe permission denied.")
                }
            }
        } else {
            do {
                try FileManager.default.createDirectory(at: ArgumentParser.shared.output, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("\nCannot create output location, maybe permission denied.")
            }
        }
    }
    do {
        var isDir = ObjCBool(booleanLiteral: false)
        if FileManager.default.fileExists(atPath: String(ArgumentParser.shared.output.appendingPathComponent("debs").path), isDirectory: &isDir) {
            assert(isDir.boolValue, "\nOutput location must be a folder")
        } else {
            do {
                try FileManager.default.createDirectory(at: ArgumentParser.shared.output.appendingPathComponent("debs"), withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("\nCannot create output deb location, maybe permission denied.")
            }
        }
    }
}

// 先决处理软件源 Release 和 Package 由 WorkParser 处理
WorkParser.shared.initPrint()

do {
    var count = 1
    let lock = NSLock()
    let sem = DispatchSemaphore(value: ArgumentParser.shared.multithread)
    let group = DispatchGroup()
    for package in nPackageContainer {
        bbb: for version in package.info {
            guard let comp = version.value["filename"] else {
                print("[E] Package with id: " + package.id + " at version:" + version.key + " failed to locate and ignored")
                continue
            }
            let target: URL
            if comp.hasPrefix("https://") || comp.hasPrefix("http://") {
                if let ttt = URL(string: comp) {
                    target = ttt
                } else {
                    continue bbb
                }
            } else {
                target = ArgumentParser.shared.url.appendingPathComponent(comp)
            }
            guard let name = comp.split(separator: "/").last else {
                print("[E] Package with id: " + package.id + " at version:" + version.key + " failed to get file name and ignored")
                print("    -> " + comp)
                continue
            }
            if ArgumentParser.shared.justprint {
                print("[P] Will download from " + target.path + "\n"
                    + "                    to " +
                    ArgumentParser.shared.output
                    .appendingPathComponent("debs")
                    .appendingPathComponent(String(name))
                    .path)
            } else {
                group.enter()
                sem.wait()
                DispatchQueue.global().async {
                    autoreleasepool {
                        let path = ArgumentParser.shared.output.appendingPathComponent("debs").appendingPathComponent(String(name))
                        WorkParser.shared.download(from: target,
                                                   to: path,
                                                   md5: version.value["md5sum"],
                                                   sha1: version.value["sha1"],
                                                   sha256: version.value["sha256"])
                        lock.lock()
                        count += 1
                        print("[*] Download Completed \(count)/\(nPackageContainer.count)\n  \(package.id) - \(version.key)\n  \(target)\n  \(path.path)")
                        lock.unlock()
                        group.leave()
                        sem.signal()
                    }
                }
            }
            // 看下要不要睡一会
            if ArgumentParser.shared.gap > 0 {
                sleep(UInt32(ArgumentParser.shared.gap))
            }
        }
    }
    group.wait()
    print("[*] Sync task completed with \(count) tasks")
}

for item in nErrorIndicators {
    print("[E] " + item)
}

if nErrorIndicators.count == 0 {
    print("\n🎉 No error occurs during download\n\n")
} else {
    print("\nTask finished with errors above\n\n")
}

print("Lakr Aream 2021.7.11 Version 1.6")
