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

class ConfigManager {
    
    static let shared = ConfigManager(venderInfo: "vender init")
    
    let url: URL
    let output: URL
    let depth: Int
    let overwrite: Bool
    let skipsum: Bool
    let noSSL: Bool
    let mess: Bool
    
    required init(venderInfo: String) {
        if venderInfo != "vender init" {
            fatalError("ConfigManager could only be init by vender and have one instance")
        }
        
        var _depth: Int?
        var _overwrite: Bool?
        var _skipsum: Bool?
        var _noSSL: Bool?
        var _mess: Bool?
        
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
        
    }
    
    func printConfig() {
        print("\n")
        print("Starting jobs with config")
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
        print("\n-------------------------")
        print("\n")
    }
    
}

ConfigManager.shared.printConfig()


