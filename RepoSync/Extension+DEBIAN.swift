//
//  InvokeMetadata.swift
//  RepoSync
//
//  Created by Lakr Aream on 2021/7/11.
//  Copyright © 2021 Lakr Aream. All rights reserved.
//

import Foundation

extension PackageOperator {
    func invokeMeta(context: String) -> [String: String]? {
        if context.count < 2 { return nil }

        var metas = [(String, String)]()
        for compose in context.components(separatedBy: "\n") where compose != "" {
            var line = compose
            line.removeSpaces()
            if line.contains(":"), !compose.hasPrefix("  ") {
                let split = line.components(separatedBy: ":")
                if split.count >= 2 {
                    var key = split[0]
                    var val = ""
                    for (index, item) in split.enumerated() where index > 0 {
                        var get = item
                        get.removeSpaces()
                        val += get
                        val += ":"
                    }
                    val.removeLast()
                    key.removeSpaces()
                    val.removeSpaces()
                    metas.append((key, val))
                }
            } else {
                if var get = metas.last {
                    metas.removeLast()
                    get.1 = get.1 + "\n" + line
                    metas.append(get)
                }
            }
        }

        var ret = [String: String]()
        metas.forEach { object in
            let key = object.0.lowercased()
            let val = object.1
            ret[key] = val
        }
        return ret.count > 0 ? ret : nil
    }
}
