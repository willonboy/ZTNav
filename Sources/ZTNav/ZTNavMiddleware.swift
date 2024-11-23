//
// ZTNavMiddleware.swift
//
// GitHub Repo and Documentation: https://github.com/willonboy/ZTNav
//
// Copyright © 2024 Trojan Zhang. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

import Foundation

@resultBuilder
public struct ZTNavMiddlewareBuilder {
    public static func buildBlock(_ middlewares: ZTNavMiddleware...) -> [ZTNavMiddleware] {
        return middlewares
    }

    public static func buildOptional(_ middleware: [ZTNavMiddleware]?) -> [ZTNavMiddleware] {
        return middleware ?? []
    }

    public static func buildEither(first: [ZTNavMiddleware]) -> [ZTNavMiddleware] {
        return first
    }

    public static func buildEither(second: [ZTNavMiddleware]) -> [ZTNavMiddleware] {
        return second
    }

    public static func buildArray(_ components: [[ZTNavMiddleware]]) -> [ZTNavMiddleware] {
        return components.flatMap { $0 }
    }
}

public class ZTNavMiddleware {
    let name: String
    private var middlewares: [ZTNavMiddleware] = []
    
    lazy var process: (ZTNavPath, [String: Any]) -> (ZTNavPath, [String: Any]) = {[weak self] path, params in
        guard let self = self else { return (path, params) }
        var currentPath = path
        var currentParams = params
        for middleware in self.middlewares {
            ZTNavLog.log(.Info, "will call submiddleware: \(middleware.name) url: \(currentPath) params: \(currentParams)")
            let result = middleware.process(currentPath, currentParams)
            currentPath = result.0
            currentParams = result.1
            ZTNavLog.log(.Info, "did call submiddleware: \(middleware.name) url: \(currentPath) params: \(currentParams)")
        }
        return (currentPath, currentParams)
    }

    // Regular initializer
    public init(name: String, process: @escaping (ZTNavPath, [String: Any]) -> (ZTNavPath, [String: Any])) {
        self.name = name
        self.process = process
    }

    // Nested middleware initializer
    public init(name: String, @ZTNavMiddlewareBuilder _ content: () -> [ZTNavMiddleware]) {
        self.name = name
        self.middlewares = content()
    }
    
    @MainActor
    public func regist() {
        ZTNav.regist(middleware: self)
    }
}

