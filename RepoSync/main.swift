//
//  main.swift
//  RepoSync
//
//  Created by Lakr Aream on 2020/4/12.
//  Copyright © 2020 Lakr Aream. All rights reserved.
//

import Foundation

// 校验输入
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
    --skip-sum  shutdown package validation even if
                there is check sum or other sum info
                exists in package release file
    --no-ssl    disable SSL verification if exists
    --mess      generate random id for each request
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
        --mess

"""


func getAbsoluteURL(url: URL) -> URL {
    let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let ret = URL(fileURLWithPath: url.absoluteString, relativeTo: current)
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
    
    let udid: String
    let ua: String
    let machine: String
    let firmware: String
    
    required init(venderInfo: String) {
        if venderInfo != "vender init" {
            fatalError("ConfigManager could only be init by vender and have one instance")
        }
        
        var _depth: Int?
        var _timeout: Int?
        var _multi: Bool?
        var _overwrite: Bool?
        var _skipsum: Bool?
        var _noSSL: Bool?
        var _mess: Bool?
        
        var _ua: String?
        var _machine: String?
        var _udid: String?
        var _ver: String?
        
        if CommandLine.arguments.count < 3 {
            print(USAGE_STRING)
            exit(0)
        }
        
        self.url = URL(string: CommandLine.arguments[1])!
        self.output = getAbsoluteURL(url: URL(fileURLWithPath: CommandLine.arguments[2]))
        
        if (CommandLine.arguments.count > 3) {
            for i in 3...(CommandLine.arguments.count - 1) {
                let item = CommandLine.arguments[i]
                if item.hasPrefix("depth=") {
                    _depth = Int(item.dropFirst("depth=".count))
                    continue
                }
                if item.hasPrefix("timeout=") {
                    _timeout = Int(item.dropFirst("timeout=".count))
                    continue
                }
                if item.hasPrefix("udid=") {
                    _udid = String(item.dropFirst("udid=".count))
                    continue
                }
                if item.hasPrefix("ua=") {
                    _ua = String(item.dropFirst("ua=".count))
                    continue
                }
                if item.hasPrefix("machine=") {
                    _machine = String(item.dropFirst("machine=".count))
                    continue
                }
                if item.hasPrefix("firmware=") {
                    _ver = String(item.dropFirst("firmware=".count))
                    continue
                }
                if item == "boom" {
                    _multi = true
                    continue
                }
                if item == "overwrite" {
                    _overwrite = true
                    continue
                }
                if item == "skip_sum" {
                    _skipsum = true
                    continue
                }
                if item == "no-ssl" {
                    _noSSL = true
                    continue
                }
                if item == "mess" {
                    _mess = true
                    continue
                }
                fatalError("Command not understood: " + item)
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
        print("-> depth: " + String(depth))
        print("-> ", separator: "", terminator: "")
        if overwrite {
            print(" overwrite", separator: "", terminator: "")
        }
        if skipsum {
            print(" skipsum", separator: "", terminator: "")
        }
        if noSSL {
            print(" noSSL", separator: "", terminator: "")
        }
        if mess {
            print(" mess", separator: "", terminator: "")
        }
        print("Request Headers:")
        print("User-Agent: " + ua)
        print("X-Unique-ID: " + udid)
        print("X-Machine:" + machine + " X-Firmware: " + firmware)
        print("-------------------------")
        print("\n")
    }
    
}

ConfigManager.shared.printConfig()


