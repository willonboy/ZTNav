//
// ZTNav.swift
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
import UIKit

@dynamicMemberLookup
public struct ZTNavParameters {
    private var params: [String: Any]

    init(params: [String: Any]) {
        self.params = params
    }

    subscript(dynamicMember member: String) -> Any? {
        return params[member]
    }
}

// 不要让Native代码感知到web url，所有的web url都转成appUrl，即Native Schema
public enum ZTNavPath : Hashable {
    case unknown(String)
    case web(String)
    // Native路径不要用路径模板，Native代码只简单的 "key + params => vc/logic code"
    case appUrl(String)
}

public struct ZTNavVerifyParam {
    var name: String
    var type: Any.Type
    var defValue: Any?
}

protocol ZTNavHandler {
    var path: ZTNavPath { get set }
    var verifyParams: [ZTNavVerifyParam] { get set }
}

extension ZTNavHandler {
    
    @discardableResult
    func validateParams(_ params: inout [String: Any]) -> Bool {
        for vp in verifyParams {
            if let value = params[vp.name] {
                if type(of: value) != vp.type {
                    debugPrint("ZTNav Error: validateParams failed: param value type wrong of \(vp.name) : \(value)")
                    return false
                }
            } else if let defaultValue = vp.defValue {
                params[vp.name] = defaultValue
            } else {
                debugPrint("ZTNav Error: validateParams failed: no param \(vp.name)")
                return false
            }
        }
        return true
    }
}

public class ZTVCHandler : ZTNavHandler {
    var path: ZTNavPath
    var verifyParams: [ZTNavVerifyParam]
    var handler: (ZTNavParameters) -> UIViewController

    init(path: ZTNavPath, verifyParams: [ZTNavVerifyParam] = [], handler: @escaping (ZTNavParameters) -> UIViewController) {
        self.path = path
        self.verifyParams = verifyParams
        self.handler = handler
    }

    @MainActor
    func regist() {
        ZTNav.regist(vcHandler: self)
    }
}

public class ZTLogicHandler : ZTNavHandler {
    var path: ZTNavPath
    var verifyParams: [ZTNavVerifyParam]
    var handler: (ZTNavParameters) -> Void

    init(path: ZTNavPath, verifyParams: [ZTNavVerifyParam] = [], handler: @escaping (ZTNavParameters) -> Void) {
        self.path = path
        self.verifyParams = verifyParams
        self.handler = handler
    }

    @MainActor
    func regist() {
        ZTNav.regist(logicHandler: self)
    }
}

// 必须统一注册
public class ZTNavMiddleware {
    let name: String
    let process: (String, [String: Any]) -> (String, [String: Any])

    init(name: String, process: @escaping (String, [String: Any]) -> (String, [String: Any])) {
        self.name = name
        self.process = process
    }
    
    @MainActor
    func regist() {
        ZTNav.regist(middleware: self)
    }
}

@MainActor
public class ZTNav {
    public static var AppSchema: String = "//"
    private(set) public static var navigationController: UINavigationController?
    private static var failedHandler: ((String, [String: Any]?) -> Void)? = { (url: String, params: [String: Any]?) in
        debugPrint("ZTNav Error: Navigation failed for URL: \(url) With params: \(params ?? [:])")
    }
    private static var middlewares = [ZTNavMiddleware]()
    private static var vcHandlers = [ZTNavPath: ZTVCHandler]()
    private static var logicHandlers = [ZTNavPath: ZTLogicHandler]()

    static func navVC(_ navVC: UINavigationController?) {
        navigationController = navVC
    }

    static func failedHandler(_ handler: @escaping (String, [String: Any]?) -> Void) {
        failedHandler = handler
    }

    static func allMiddle() -> [ZTNavMiddleware] {
        return middlewares
    }

    static func allHandler() -> [Any] {
        return Array(vcHandlers.values) + Array(logicHandlers.values)
    }

    @discardableResult
    static func push(_ path: ZTNavPath, params: [String: Any] = [:], animated: Bool) -> Bool {
        guard navigationController != nil else {
            debugPrint("ZTNav Error: No navigationController")
            return false
        }
        guard let vc = loadVC(path, params: params) else {
            failedHandler?(pathToString(path), params)
            return false
        }
        navigationController?.pushViewController(vc, animated: animated)
        return true
    }

    @discardableResult
    static func present(_ path: ZTNavPath, params: [String: Any] = [:], animated: Bool) -> Bool {
        guard let vc = loadVC(path, params: params) else {
            failedHandler?(pathToString(path), params)
            return false
        }
        if let nv = navigationController {
            nv.topViewController?.present(vc, animated: animated, completion: nil)
        } else {
            UIApplication.shared.zt_keyWindow?.rootViewController?.present(vc, animated: animated, completion: nil)
        }
        return true
    }

    @discardableResult
    static func handle(_ path: ZTNavPath, params: [String: Any] = [:]) -> Bool {
        guard let (processedPath, combinedParams) = applyMiddlewares(to: path, params: params), validateParams(for: processedPath, params: combinedParams) else {
            failedHandler?(pathToString(path), params)
            return false
        }
        if let processedPath = processedPath, let result = handleLogic(for: processedPath, params: params) {
            return result
        }
        return push(path, params: params, animated: false)
    }

    static func loadVC(_ path: ZTNavPath?, params: [String: Any] = [:]) -> UIViewController? {
        guard let path = path else { return nil }
        guard let (processedPath, combinedParams) = applyMiddlewares(to: path, params: params), validateParams(for: processedPath, params: combinedParams) else { return nil}
        guard let processedPath = processedPath, let vcHandler = vcHandlers[processedPath] else { return nil }
        var validatedParams = params
        vcHandler.validateParams(&validatedParams)
        return vcHandler.handler(ZTNavParameters(params: validatedParams))
    }

    static func regist(vcHandler: ZTVCHandler) {
        guard vcHandlers[vcHandler.path] == nil else {
#if DEBUG
            assert(false, "ZTNav Error: already regist same path vcHandler")
#endif
            return
        }
        debugPrint("ZTNav regist vcHandler: \(vcHandler.path)")
        vcHandlers[vcHandler.path] = vcHandler
    }

    static func regist(logicHandler: ZTLogicHandler) {
        guard logicHandlers[logicHandler.path] == nil else {
#if DEBUG
            assert(false, "ZTNav Error: already regist same path logicHandler")
#endif
            return
        }
        debugPrint("ZTNav regist logicHandler: \(logicHandler.path)")
        logicHandlers[logicHandler.path] = logicHandler
    }
    
    static func regist(middleware: ZTNavMiddleware) {
        guard !middlewares.contains(where: { $0.name == middleware.name }) else {
#if DEBUG
        assert(false, "ZTNav Error: middleware with name \(middleware.name) already registered")
#endif
            return
        }
        debugPrint("ZTNav regist middleware: \(middleware.name)")
        middlewares.append(middleware)
    }
    
    static func unregist(vcHandler: ZTVCHandler) {
        vcHandlers.removeValue(forKey: vcHandler.path)
        debugPrint("ZTNav unregist vcHandler: \(vcHandler.path)")
    }

    static func unregist(logicHandler: ZTLogicHandler) {
        logicHandlers.removeValue(forKey: logicHandler.path)
        debugPrint("ZTNav unregist logicHandler: \(logicHandler.path)")
    }

    static func unregist(name: String) {
        middlewares.removeAll { $0.name == name }
        debugPrint("ZTNav unregist middleware: \(name)")
    }

    private static func applyMiddlewares(to path: ZTNavPath, params: [String: Any]) -> (ZTNavPath?, [String: Any])? {
        var url = pathToString(path)
        var combinedParams = parseQueryParameters(from: url)
        combinedParams.merge(params) { (_, new) in new }
        
        for middleware in middlewares {
            debugPrint("ZTNav call middleware: \(middleware.name) \nurl: \(url) \nparams: \(combinedParams)")
            (url, combinedParams) = middleware.process(url, combinedParams)
        }
        
        return (stringToPath(url), combinedParams)
    }
    
    private static func parseQueryParameters(from url: String) -> [String: Any] {
        var params = [String: Any]()
        
        if let components = URLComponents(string: url), let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value?.removingPercentEncoding {
                    params[item.name] = value
                } else {
                    params[item.name] = item.value
                }
            }
        }
        
        return params
    }
    
    private static func validateParams(for path: ZTNavPath?, params: [String: Any]) -> Bool {
        guard let path = path else { return false }
        
        for handler in vcHandlers.values {
            if handler.path == path {
                var validatedParams = params
                if !handler.validateParams(&validatedParams) {
                    return false
                }
                return true
            }
        }

        for handler in logicHandlers.values {
            if handler.path == path {
                var validatedParams = params
                if !handler.validateParams(&validatedParams) {
                    return false
                }
                return true
            }
        }
        
        return false
    }

    private static func handleLogic(for path: ZTNavPath, params: [String: Any]) -> Bool? {
        guard let logicHandler = logicHandlers[path] else { return nil }
        var validatedParams = params
        logicHandler.validateParams(&validatedParams)
        logicHandler.handler(ZTNavParameters(params: validatedParams))
        return true
    }

    private static func pathToString(_ path: ZTNavPath) -> String {
        switch path {
        case .unknown(let url), .web(let url), .appUrl(let url):
            return url
        }
    }

    private static func stringToPath(_ string: String) -> ZTNavPath? {
        if string.hasPrefix("http") {
            return .web(string)
        } else if string.hasPrefix(AppSchema) {
            return .appUrl(string)
        } else {
            return .unknown(string)
        }
    }
}




extension UIApplication {
    var zt_keyWindow: UIWindow? {
        for scene in self.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               windowScene.activationState == .foregroundActive ||
               windowScene.activationState == .background {
                for window in windowScene.windows {
                    if window.windowLevel != .normal || window.isHidden {
                        continue
                    }
                    if window.bounds == UIScreen.main.bounds && window.isKeyWindow {
                        return window
                    }
                }
            }
        }
        
        var keyWindow: UIWindow? = nil
        for window in self.windows {
            if window.windowLevel == .normal && !window.isHidden && window.bounds == UIScreen.main.bounds && window.isKeyWindow {
                keyWindow = window
                break
            }
        }
        
        if keyWindow == nil {
            keyWindow = self.delegate?.window ?? nil
        }
        return keyWindow
    }
}
