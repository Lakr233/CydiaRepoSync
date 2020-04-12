//
//  main.swift
//  RepoSync
//
//  Created by Lakr Aream on 2020/4/12.
//  Copyright © 2020 Lakr Aream. All rights reserved.
//

import Foundation
import SWCompression

let USAGE_STRING = """
Usage: ./RepoSync <url> <output dir> [Options]

Options:

    We default only update packages that are not
    exists and only download 1 newest version
    each for each package
    This is suggested avoiding waste of server
    or network resources
    It is expensive to host a cloud machine

    --depth     default to 2, used to control how
                may versions of a package should be
                downloaded if they exists
                set to 0 to download them all
    --timeout   default to 30, used to control timeout
                time for each package download session
    --udid      udid to request, ignored if --mess
                random if not set
    --ua        user agent to request, cydia if not set
    --machine   machine to request, default to
                "iPhone8,1", ignored if --mess
    --firmware  system version to request, default to
                "13.0", ignored if --mess
    --boom      enable multi thread
    --overwrite default to false, will download all
                packages and overwrite them for no
                reason even they already exists
    --clean     enable clean will delete all your local
                files in output dir first
    --skip-sum  shutdown package validation even if
                there is check sum or other sum info
                exists in package release file
    --no-ssl    disable SSL verification if exists
    --mess      generate random id for each request
    --timegap   sleep several seconds between requests
                default to 0 and disabled
                some repo has limited request to 10/min
                ^_^

Examples:

    ./RepoSync https://repo.test.cn ./out \
        --depth=4 \
        --timeout=60 \
        --udid=arandomudidnumber \
        --ua=someUAyouwant2use \
        --machine=iPhone9,2 \
        --firmware=12.0.0 \
        --boom \
        --overwrite \
        --skip-sum \
        --no-ssl \
        --mess \
        --timegap=1 \
        --clean

"""


struct pack {
    let id: String
    //          版本号     key      meta
    var info: [String : [String : String]]
}

var debContainer: [pack] = []

/*
 
 When I wrote this function, invokeMeta, me and god know
 how it works. But now, only god knows how it worked.
 If you are trying to improve this routine, make sure to
 modify this value here below.
 
 total_hours_wasted_here = 1
 
 */
func invokeMeta(context: String) -> [String : String] {
    let context = context + "\n\n"
    var key = ""
    var value = ""
    var keyFlag = true
    var newLineFlag = false
    var dotdotFlag = false
    var currentMeta = [String : String]()
    for char in context {
        let c = String(char)
        inner: if c == ":" {
            newLineFlag = false
            keyFlag = false
            if dotdotFlag {
                value += ":"
            } else {
                dotdotFlag = true
            }
        } else if c == "\n" {
            if newLineFlag == true {
                return currentMeta
            }
            newLineFlag = true
            keyFlag = true
            if key == "" || value == "" {
                dotdotFlag = false
                break inner
            }
            while key.hasPrefix("\n") {
                key = String(key.dropFirst())
            }
            value = String(value.dropFirst())
            while value.hasPrefix(" ") {
                value = String(value.dropFirst())
            }
            currentMeta[key.lowercased()] = value
            key = ""
            value = ""
            if keyFlag {
                key += c
            }
        } else {
            newLineFlag = false
            if keyFlag {
                key += c
            } else {
                value += c
            }
        }
    }
    return [:]
}

func invokePackageMeta(meta: String) -> pack? {
    let meta = invokeMeta(context: meta)
    
    guard let ver = meta["version"] else {
        print("[invokePackageMeta] Invalid meta: missing version string")
        return nil
    }
    guard let id = meta["package"] else {
        print("[invokePackageMeta] Invalid meta: missing package string")
        return nil
    }
    guard let _ = meta["filename"] else {
        print("[invokePackageMeta] Invalid meta: missing download location")
        return nil
    }
    return pack(id: id, info: [ver : meta])
}

func invokePackageMetas(meta: String) -> [pack] {
    // 超级快查表 避免重复
    var container: [String : pack] = [:]
    for item in meta.components(separatedBy: "\n\n") {
        if let pack = invokePackageMeta(meta: item) {
            if container[pack.id] != nil {
                // 已经包含了这个玩意         注意 单次初始化的软件包对象的info只有一个version
                container[pack.id]!.info[pack.info.first!.key] = pack.info.first!.value
            } else {
                container[pack.id] = pack
            }
        }
    }
    var ret: [pack] = []
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

func createCydiaRequest(url: URL) -> URLRequest {
    
    print("[CydiaRequest] Requesting GET to -> " + url.absoluteString)
    var request: URLRequest
    request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval:  TimeInterval(ConfigManager.shared.timeout))
    
    if (ConfigManager.shared.mess) {
        request.setValue([
            "iPhone6,1", "iPhone6,2", "iPhone7,2", "iPhone7,1", "iPhone8,1", "iPhone8,2", "iPhone9,1", "iPhone9,3", "iPhone9,2", "iPhone9,4", "iPhone8,4", "iPhone10,1", "iPhone10,4", "iPhone10,2", "iPhone10,5", "iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8", "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4", "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6", "iPad6,11", "iPad6,12", "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12", "iPad4,1", "iPad4,2", "iPad4,3", "iPad5,3", "iPad5,4", "iPad11,4", "iPad11,5", "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7", "iPad4,8", "iPad4,9", "iPad5,1", "iPad5,2", "iPad11,1", "iPad11,2", "iPad6,3", "iPad6,4", "iPad7,3", "iPad7,4", "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,9", "iPad8,10", "iPad6,7", "iPad6,8", "iPad7,1", "iPad7,2", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8", "iPad8,11", "iPad8,12"
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
        request.setValue("Telesphoreo APT-HTTP/1.0." + String(Int.random(in: 580...620)), forHTTPHeaderField: "User-Agent")
    } else {
        request.setValue(ConfigManager.shared.udid, forHTTPHeaderField: "X-Unique-ID")
        request.setValue(ConfigManager.shared.machine, forHTTPHeaderField: "X-Machine")
        request.setValue(ConfigManager.shared.firmware, forHTTPHeaderField: "X-Firmware")
        request.setValue(ConfigManager.shared.ua, forHTTPHeaderField: "User-Agent")
    }
    
    request.httpMethod = "GET"
    
    return request
}

class ConfigManager {
    
    static let shared = ConfigManager(venderInfo: "vender init")
    
    let url: URL
    let output: URL
    let depth: Int
    let timeout: Int
    let multiThread: Bool
    let overwrite: Bool
    let skipsum: Bool
    let noSSL: Bool
    let mess: Bool
    let gap: Int
    let clean: Bool
    
    let udid: String
    let ua: String
    let machine: String
    let firmware: String
    
    required init(venderInfo: String) {
        if venderInfo != "vender init" {
            fatalError("\nConfigManager could only be init by vender and have one instance")
        }
        
        var _depth: Int?
        var _timeout: Int?
        var _multi: Bool?
        var _overwrite: Bool?
        var _skipsum: Bool?
        var _noSSL: Bool?
        var _mess: Bool?
        var _gap: Int?
        var _clean: Bool?
        
        var _ua: String?
        var _machine: String?
        var _udid: String?
        var _ver: String?
        
        if CommandLine.arguments.count < 3 {
            print(USAGE_STRING)
            exit(0)
        }
        
        self.url = URL(string: CommandLine.arguments[1])!
        self.output = getAbsoluteURL(location: CommandLine.arguments[2])
        
        if (CommandLine.arguments.count > 3) {
            for i in 3...(CommandLine.arguments.count - 1) {
                let item = CommandLine.arguments[i]
                if item.hasPrefix("--depth=") {
                    _depth = Int(item.dropFirst("--depth=".count))
                    continue
                }
                if item.hasPrefix("--timeout=") {
                    _timeout = Int(item.dropFirst("--timeout=".count))
                    continue
                }
                if item.hasPrefix("--udid=") {
                    _udid = String(item.dropFirst("--udid=".count))
                    continue
                }
                if item.hasPrefix("--ua=") {
                    _ua = String(item.dropFirst("--ua=".count))
                    continue
                }
                if item.hasPrefix("--machine=") {
                    _machine = String(item.dropFirst("--machine=".count))
                    continue
                }
                if item.hasPrefix("--firmware=") {
                    _ver = String(item.dropFirst("--firmware=".count))
                    continue
                }
                if item == "--boom" {
                    _multi = true
                    continue
                }
                if item == "--overwrite" {
                    _overwrite = true
                    continue
                }
                if item == "--skip-sum" {
                    _skipsum = true
                    continue
                }
                if item == "--clean" {
                    _clean = true
                    continue
                }
                if item == "--no-ssl" {
                    _noSSL = true
                    continue
                }
                if item == "--mess" {
                    _mess = true
                    continue
                }
                if item == "--timegap" {
                    _gap = Int(item.dropFirst("--timegap=".count))
                    continue
                }
                fatalError("\nCommand not understood: " + item)
            }
        }
        
        if let val = _depth {
            self.depth = val
        } else {
            self.depth = 2
        }
        if let val = _timeout {
            self.timeout = val
        } else {
            self.timeout = 30
        }
        if let val = _multi {
            self.multiThread = val
        } else {
            self.multiThread = false
        }
        if let val = _overwrite {
            self.overwrite = val
        } else {
            self.overwrite = false
        }
        if let val = _skipsum {
            self.skipsum = val
        } else {
            self.skipsum = false
        }
        if let val = _noSSL {
            self.noSSL = val
        } else {
            self.noSSL = false
        }
        if let val = _mess {
            self.mess = val
        } else {
            self.mess = false
        }
        if let val = _gap {
            self.gap = val
        } else {
            self.gap = 0
        }
        if let val = _clean {
            self.clean = val
        } else {
            self.clean = false
        }
        
        if let val = _ua {
            self.ua = val
        } else {
            self.ua = "Telesphoreo APT-HTTP/1.0.592"
        }
        if let val = _ver {
            self.firmware = val
        } else {
            self.firmware = "13.0"
        }
        if let val = _udid {
            self.udid = val.lowercased()
        } else {
            self.udid = "E667727230424CEDAB64C41DF94536E7DF94536E".lowercased()
        }
        if let val = _machine {
            self.machine = val
        } else {
            self.machine = "iPhone8,1"
        }
        
        
    }
    
    func printConfig() {
        print("\n")
        print("-------------------------")
        print("From: " + url.absoluteString + " to: " + output.absoluteString)
        print(" -> depth: " + String(depth) + " timeGap: " + String(gap))
        var status = ""
        if overwrite {
            status += " overwrite"
        }
        if skipsum {
            status += " skipsum"
        }
        if noSSL {
            status += " noSSL"
        }
        if mess {
            status += " mess"
        }
        if clean {
            status += " clean"
        }
        if multiThread {
            status += " multiThread"
        }
        if (status != "") {
            while status.hasPrefix(" ") {
                status = String(status.dropFirst())
            }
            print(" -> " + status)
        }
        if (mess) {
            print("Request Messed!")
        } else {
            print("Request Headers:")
            print(" -> User-Agent: " + ua)
            print(" -> X-Unique-ID: " + udid)
            print(" -> X-Machine:" + machine + " X-Firmware: " + firmware)
        }
        print("-------------------------")
        print("\n")
    }
    
}

// 初始化配置
ConfigManager.shared.printConfig()

// 输出文件组织
// output dir:
//    |
//    |-> Release       plain text if exists
//    |-> Packages      plain text if exists
//    |-> debs          packages

class JobManager {
    
    static let shared = JobManager(venderInfo: "vender init")
    
    let release: String
    let package: String
    //                          id        version
    let alreadyExistsPackages: [String : [String]]
    
    static let tim = DispatchQueue(label: "wiki.qaq.JobsLoveTim")
    
    required init(venderInfo: String) {
        if venderInfo != "vender init" {
            fatalError("\nConfigManager could only be init by vender and have one instance")
        }
        let semRelease = DispatchSemaphore(value: 0)
        let semPackage = DispatchSemaphore(value: 0)
        
        var getRelease: String?
        var getPackage: String?
        
        JobManager.tim.async {
            let request = createCydiaRequest(url: ConfigManager.shared.url.appendingPathComponent("Release"))
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let task = session.dataTask(with: request) { (data, respond, error) in
                if error == nil, let data = data, let resp = respond as? HTTPURLResponse {
                    if resp.statusCode != 200 {
                        print("[Release] Failed to get repo release, server returned " + String(resp.statusCode))
                    } else {
                        if let str = String(data: data, encoding: .utf8) {
                            getRelease = str
                        } else if let str = String(data: data, encoding: .ascii) {
                            getRelease = str
                        } else {
                            print("[Release] Decode failed, ignored")
                        }
                    }
                }
                semRelease.signal()
            }
            task.resume()
        }
        
        let search = ["bz2", "", "xz", "gz", "lzma", "lzma2", "bz", "xz2", "gz2"]
        
        // 小心菊花
        let sync = DispatchQueue(label: "watch.our.ass")
        for item in search {
            JobManager.tim.async {
                let request: URLRequest
                if item == "" {
                    request = createCydiaRequest(url: ConfigManager.shared.url.appendingPathComponent("Packages"))
                } else {
                    request = createCydiaRequest(url: ConfigManager.shared.url.appendingPathComponent("Packages." + item))
                }
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
                let task = session.dataTask(with: request) { (data, respond, error) in
                    if error == nil, let data = data, let resp = respond as? HTTPURLResponse {
                        if resp.statusCode != 200 {
                            print("[Packages] Failed to get repo meta data, server returned " + String(resp.statusCode) + " when looking for ." + item)
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
                                if let str = String(data: decoded, encoding: .utf8) {
                                    sync.sync {
                                        getPackage = str
                                        semPackage.signal()
                                    }
                                    return
                                } else if let str = String(data: decoded, encoding: .ascii) {
                                    sync.sync {
                                        getPackage = str
                                        semPackage.signal()
                                    }
                                    return
                                } else {
                                    print("[Release] Decode failed, ignored")
                                }
                            }
                        }
                    }
                }
                task.resume()
            }
        }
        
        
        let _ = semRelease.wait(timeout: .now() + Double(ConfigManager.shared.timeout))
        let _ = semPackage.wait(timeout: .now() + Double(ConfigManager.shared.timeout * search.count))
        
        if getRelease != nil {
            release = getRelease!
        } else {
            release = ""
        }
        
        assert(getPackage != nil, "\nFailed to download packages' meta data")
        package = getPackage!
        
        if release != "" {
            try? FileManager.default.removeItem(at: ConfigManager.shared.output.appendingPathComponent("Release.txt"))
            try? release.write(to: ConfigManager.shared.output.appendingPathComponent("Release.txt"), atomically: true, encoding: .utf8)
        }

        do {
            try FileManager.default.removeItem(at: ConfigManager.shared.output.appendingPathComponent("Packages.txt"))
            try package.write(to: ConfigManager.shared.output.appendingPathComponent("Packages.txt"), atomically: true, encoding: .utf8)
        } catch {
            fatalError("\nCannot write package file to output location, maybe permission denied")
        }
        
        print("\n\n🎉 Congratulations! Repo is validated!\n\n")
        print("Invoking package metadata, this will take some times...")
        
        let packages = invokePackageMetas(meta: package)

        var exists: [String : [String]]?
        
        if ConfigManager.shared.overwrite {
            debContainer = packages
        } else {
            // 先获取存在的软件包
            exists = [:]
            let contents = try? FileManager.default.contentsOfDirectory(atPath: ConfigManager.shared.output.appendingPathComponent("debs").absoluteString)
            flag1: for item in contents ?? [] {
                // 校验软件包 核验通过之后添加到已存在列表
                for object in packages {
                    for version in object.info {
                        let val = version.value
                        let downloadLocation = val["filename"] ?? ""
                        let name = String(downloadLocation.split(separator: "/").last ?? "")
                        if name == item {
                            // 一般来说文件名都包含版本号 不包含的话也不会有多版本的存在
                            if exists![object.id] == nil {
                                exists![object.id] = [version.key]
                            } else {
                                exists![object.id]!.append(version.key)
                            }
                            continue flag1
                        }
                    }
                }
            }
        }
        
        if let exists = exists {
            alreadyExistsPackages = exists
            // 能走到这里一定没有开覆盖 那么我们构建软件包列表
            var temp: [String : pack] = [:]
            for item in packages {
                for version in item.info {
                    // 如果这个版本这个软件包存在于exists里面就跳过
                    if exists.keys.contains(item.id) && exists[item.id]!.contains(version.key) {
                        print("Skipping package with id: " + item.id + " at version: " + version.key)
                    } else {
                        // 不存在下载好的文件
                        if temp[item.id] != nil {
                            // 已经有这个软件包了
                            temp[item.id]!.info[version.key] = version.value
                        } else {
                            temp[item.id] = pack(id: item.id, info: [version.key : version.value])
                        }
                    }
                }
            }
            for item in temp {
                debContainer.append(item.value)
            }
        } else {
            alreadyExistsPackages = [:]
        }
    
        // 检查下载的depth
        if (ConfigManager.shared.depth > 0) {
            var temp: [pack] = []
            let depth = ConfigManager.shared.depth
            let dpkgAgent = dpkgWrapper()
            for pack in debContainer {
                // 获取这个软件包的全部版本
                var versionStrings = pack.info.keys
                // 排序
                versionStrings.sorted { (A, B) -> Bool in
                    return dpkgAgent.compareVersionA(A, andB: B) == 1
                }
                // 创建新的versionkeys
                print("")
                // 合成符合要求的deb
                
            }
        }
        
        
    }
    
    func initPrint() {
        
        print("\n\n")
        print(String(debContainer.count) + " packages to download in total")
        
    }
    
}

do {
    do {
        var isDir = ObjCBool(booleanLiteral: false)
        if FileManager.default.fileExists(atPath: ConfigManager.shared.output.absoluteString, isDirectory: &isDir) {
            assert(isDir.boolValue, "\nOutput location must be a folder")
            if ConfigManager.shared.clean {
                do {
                    try FileManager.default.removeItem(at: ConfigManager.shared.output)
                    try FileManager.default.createDirectory(at: ConfigManager.shared.output, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fatalError("\nCannot clean output location, maybe permission denied.")
                }
            }
        } else {
            do {
                try FileManager.default.createDirectory(at: ConfigManager.shared.output, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("\nCannot create output location, maybe permission denied.")
            }
        }
    }
    do {
        var isDir = ObjCBool(booleanLiteral: false)
        if FileManager.default.fileExists(atPath: ConfigManager.shared.output.appendingPathComponent("debs").absoluteString, isDirectory: &isDir) {
            assert(isDir.boolValue, "\nOutput location must be a folder")
        } else {
            do {
                try FileManager.default.createDirectory(at: ConfigManager.shared.output.appendingPathComponent("debs"), withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("\nCannot create output deb location, maybe permission denied.")
            }
        }
    }
}

// 先决处理软件源 Release 和 Package 由JobManager处理
JobManager.shared.initPrint()

// 初始化输出目录
