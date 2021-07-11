//
//  ArgumentParser.swift
//  RepoSync
//
//  Created by Lakr Aream on 2021/7/11.
//  Copyright © 2021 Lakr Aream. All rights reserved.
//

import Foundation

class ArgumentParser {
    static let shared = ArgumentParser()

    let url: URL
    let output: URL
    let depth: Int
    let timeout: Int
    let overwrite: Bool
    let skipsum: Bool
    let mess: Bool
    let gap: Int
    let clean: Bool
    let rename: Bool
    let namematch: Bool
    let justprint: Bool

    let udid: String
    let ua: String
    let machine: String
    let firmware: String

    let multithread: Int

    private init() {
        var _depth: Int?
        var _timeout: Int?
        var _overwrite: Bool?
        var _skipsum: Bool?
        var _mess: Bool?
        var _gap: Int?
        var _clean: Bool?
        var _rename: Bool?
        var _namematch: Bool?
        var _justPrint: Bool?

        var _ua: String?
        var _machine: String?
        var _udid: String?
        var _ver: String?

        var _multithread: Int?

        if CommandLine.arguments.count < 3 {
            print(USAGE_STRING)
            exit(0)
        }

        url = URL(string: CommandLine.arguments[1])!
        output = getAbsoluteURL(location: CommandLine.arguments[2])

        if CommandLine.arguments.count > 3 {
            for i in 3 ... (CommandLine.arguments.count - 1) {
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
                if item == "--overwrite" {
                    _overwrite = true
                    continue
                }
                if item == "--rename" {
                    _rename = true
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
                if item == "--mess" {
                    _mess = true
                    continue
                }
                if item == "--allow-name-match" {
                    _namematch = true
                    continue
                }
                if item == "--timegap" {
                    _gap = Int(item.dropFirst("--timegap=".count))
                    continue
                }
                if item == "--just-print" {
                    _justPrint = true
                    continue
                }
                if item.hasPrefix("--multithread") {
                    _multithread = Int(item.dropFirst("--multithread=".count))
                    continue
                }
                fatalError("\nCommand not understood: " + item)
            }
        }

        if let val = _depth {
            depth = val
        } else {
            depth = 2
        }
        if let val = _timeout {
            timeout = val
        } else {
            timeout = 30
        }
        if let val = _overwrite {
            overwrite = val
        } else {
            overwrite = false
        }
        if let val = _skipsum {
            skipsum = val
        } else {
            skipsum = false
        }
        if let val = _mess {
            mess = val
        } else {
            mess = false
        }
        if let val = _gap {
            gap = val
        } else {
            gap = 0
        }
        if let val = _clean {
            clean = val
        } else {
            clean = false
        }
        if let val = _rename {
            rename = val
        } else {
            rename = false
        }
        if let val = _namematch {
            namematch = val
        } else {
            namematch = false
        }
        if let val = _justPrint {
            justprint = val
        } else {
            justprint = false
        }
        if let val = _ua {
            ua = val
        } else {
            ua = "Telesphoreo APT-HTTP/1.0.592"
        }
        if let val = _ver {
            firmware = val
        } else {
            firmware = "13.0"
        }
        if let val = _udid {
            udid = val.lowercased()
        } else {
            udid = "E667727230424CEDAB64C41DF94536E7DF94536E".lowercased()
        }
        if let val = _machine {
            machine = val
        } else {
            machine = "iPhone8,1"
        }
        if let val = _multithread {
            multithread = val
        } else {
            multithread = 1
        }
    }

    func printConfig() {
        print("\n")
        print("-------------------------")
        print("From: " + url.path + " to: " + output.path)
        print(" -> depth: " + String(depth) + " timeGap: " + String(gap))
        var status = ""
        if overwrite {
            status += " overwrite"
        }
        if skipsum {
            status += " skipsum"
        }
        if mess {
            status += " mess"
        }
        if clean {
            status += " clean"
        }
        if rename {
            status += " rename"
        }
        if namematch {
            status += " allow-name-match"
        }
        if status != "" {
            while status.hasPrefix(" ") {
                status = String(status.dropFirst())
            }
            print(" -> " + status)
        }
        if mess {
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

private let USAGE_STRING = """
Usage: ./RepoSync <url> <output dir> [Options]

Options:

    We default only update packages that are not
    exists and only download 1 newest version
    each for each package
    This is suggested avoiding waste of server
    or network resources
    It is expensive to host a cloud machine
    --depth             default to 2, used to control how
                        may versions of a package should be
                        downloaded if they exists. the count
                        excluded they versions that exists
                        locally
                        set to 0 to download them all
    --timeout           default to 30, used to control timeout
                        time for each package download session
    --udid              udid to request, ignored if --mess
                        random if not set
    --ua                user agent to request, cydia if not set
    --machine           machine to request, default to
                        "iPhone8,1", ignored if --mess
    --firmware          system version to request, default to
                        "13.0", ignored if --mess
    --overwrite         default to false, will download all
                        packages and overwrite them for no
                        reason even they already exists
    --clean             enable clean will delete all your local
                        files in output dir first
    --rename            rename file name if matches remote package
                        usefull if you messed your package names
    --skip-sum          shutdown package validation even if
                        there is check sum or other sum info
                        exists in package release file
    --mess              generate random id for each request
    --allow-name-match  allow package name to be used when finding
                        downloaded packages
    --timegap           sleep several seconds between requests
                        default to 0 and disabled
                        some repo has limited request to 10/min
    --just-print        do not download any package but print logs
                ^_^

Examples:

    ./RepoSync https://repo.test.cn ./out \\
        --depth=4 \\
        --timeout=60 \\
        --udid=arandomudidnumber \\
        --ua=someUAyouwant2use \\
        --machine=iPhone9,2 \\
        --firmware=12.0.0 \\
        --overwrite \\
        --skip-sum \\
        --mess \\
        --timegap=1 \\
        --clean

"""
