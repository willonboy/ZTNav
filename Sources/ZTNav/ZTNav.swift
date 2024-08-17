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

public class ZTNavLog {
    public enum LogLevel {
        case Error, Warning, Info
    }
    public static var log:((LogLevel, String) -> Void) = {level, msg in
        debugPrint("ZTNav \(level) : " + msg)
    }
}


public protocol ZTNavPathProtocol {}

extension String : ZTNavPathProtocol {}

// Do not let native code perceive web URLs; convert all web URLs to appUrl, which is the native schema
public enum ZTNavPath : ZTNavPathProtocol, Hashable {
    case web(String)
    // Native paths should not use path templates; native code simply uses "key + params => vc/logic code"
    case appUrl(String)
    case ignore
}

public struct ZTNavVerifyParam {
    public enum Key {
        case key(String)

        var name: String {
            switch self {
            case .key(let name):
                return name
            }
        }
    }
    var key: Key
    var type: Any.Type
    var defValue: Any?
}

public protocol ZTNavHandler {
    var path: ZTNavPath { get }
    var verifyParams: [ZTNavVerifyParam] { get }
}

extension ZTNavHandler {
    
    @discardableResult
    func validateParams(_ params: [String: Any]) -> Bool {
        for vp in verifyParams {
            if let value = params[vp.key.name] {
                if type(of: value) != vp.type {
                    ZTNavLog.log(.Error, "validateParams failed: Incorrect value type for parameter '\(vp.key)'. Expected \(vp.type), but got \(type(of: value)).")
                    return false
                }
            } else {
                if vp.defValue != nil {
                    continue
                }
                ZTNavLog.log(.Error, "validateParams failed: Missing parameter \(vp.key)")
                return false
            }
        }
        return true
    }
    
    func bindParamsDefaultValue(_ params: [String: Any]) -> [String: Any] {
        var combinedParams = params
        for vp in verifyParams {
            if params.keys.contains(vp.key.name) == false, let defaultValue = vp.defValue {
                combinedParams[vp.key.name] = defaultValue
            }
        }
        return combinedParams
    }
}

public class ZTVCHandler : ZTNavHandler {
    private(set) public var path: ZTNavPath
    private(set) public var verifyParams: [ZTNavVerifyParam]
    private(set) var handler: (ZTNavParameters) -> UIViewController

    init(path: ZTNavPath, verifyParams: [ZTNavVerifyParam] = [], handler: @escaping (ZTNavParameters) -> UIViewController) {
        if case .appUrl = path {} else {
            ZTNavLog.log(.Error, "ZTVCHandler path must be appUrl")
        }
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
    private(set) public var path: ZTNavPath
    private(set) public var verifyParams: [ZTNavVerifyParam]
    private(set) var handler: (ZTNavParameters) -> Void

    init(path: ZTNavPath, verifyParams: [ZTNavVerifyParam] = [], handler: @escaping (ZTNavParameters) -> Void) {
        if case .appUrl = path {} else {
            ZTNavLog.log(.Error, "ZTLogicHandler path must be appUrl")
        }
        self.path = path
        self.verifyParams = verifyParams
        self.handler = handler
    }

    @MainActor
    func regist() {
        ZTNav.regist(logicHandler: self)
    }
}

@MainActor
public class ZTNav {
    public static var AppSchema: String = "//" {
        willSet {
            if (newValue.hasPrefix("http") || newValue.hasPrefix("ftp")) {
                ZTNavLog.log(.Error, "Invalid AppSchema => \(newValue)")
            }
        }
    }
    private(set) public static var navigationController: UINavigationController?
    private static var failedHandler: ((ZTNavPathProtocol, [String: Any]?) -> Void)? = { (path: ZTNavPathProtocol, params: [String: Any]?) in
        ZTNavLog.log(.Error, "Navigation failed for URL: \(path) with params: \(params ?? [:])")
    }
    private static var middlewares = [ZTNavMiddleware]()
    private static var vcHandlers = [ZTNavPath: ZTVCHandler]()
    private static var logicHandlers = [ZTNavPath: ZTLogicHandler]()

    public static func navVC(_ navVC: UINavigationController?) {
        navigationController = navVC
    }

    public static func failedHandler(_ handler: @escaping (ZTNavPathProtocol, [String: Any]?) -> Void) {
        failedHandler = handler
    }

    public static func allMiddle() -> [ZTNavMiddleware] {
        return middlewares
    }

    public static func allHandler() -> [Any] {
        return Array(vcHandlers.values) + Array(logicHandlers.values)
    }

    @discardableResult
    public static func push(_ path: ZTNavPathProtocol, params: [String: Any] = [:], animated: Bool) -> Bool {
        guard navigationController != nil else {
            ZTNavLog.log(.Error, "Missing navigationController")
            failedHandler?(path, params)
            return false
        }
        guard let vc = matchVC(path, params: params) else {
            failedHandler?(path, params)
            return false
        }
        
        navigationController?.pushViewController(vc, animated: animated)
        return true
    }

    @discardableResult
    public static func present(_ path: ZTNavPathProtocol, params: [String: Any] = [:], animated: Bool) -> Bool {
        guard let vc = matchVC(path, params: params) else {
            failedHandler?(path, params)
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
    public static func handle(_ path: ZTNavPathProtocol, params: [String: Any] = [:], animated: Bool = true) -> Bool {
        guard let navPath = tryTransNavPath(path) else {
            failedHandler?(path, params)
            return false
        }
        let (processedPath, mParams) = applyMiddlewares(to: navPath, params: params)
        if case .ignore = processedPath {
            ZTNavLog.log(.Warning, "`handle` Ignore url: \(path) params: \(params)")
            return false
        }
        guard canHandle(for: processedPath, params: mParams) else {
            failedHandler?(path, params)
            return false
        }
        
        let handler:ZTNavHandler = vcHandlers[processedPath] ?? logicHandlers[processedPath]!
        if let logicHandler = handler as? ZTLogicHandler {
            let combinedParams = logicHandler.bindParamsDefaultValue(mParams)
            logicHandler.handler(ZTNavParameters(params: combinedParams))
        } else {
            let vcHandler = handler as! ZTVCHandler
            let combinedParams = vcHandler.bindParamsDefaultValue(params)
            let vc = vcHandler.handler(ZTNavParameters(params: combinedParams))
            navigationController?.pushViewController(vc, animated: animated)
        }
        return true
    }

    public static func matchVC(_ path: ZTNavPathProtocol, params: [String: Any] = [:]) -> UIViewController? {
        guard let navPath = tryTransNavPath(path) else {
            failedHandler?(path, params)
            return nil
        }
        let (processedPath, mParams) = applyMiddlewares(to: navPath, params: params)
        if case .ignore = processedPath {
            ZTNavLog.log(.Warning, "`matchVC` Ignore url: \(path) params: \(params)")
            return nil
        }
        guard canHandle(for: processedPath, params: mParams) else { return nil}
        guard let vcHandler = vcHandlers[processedPath] else { return nil }
        
        let combinedParams = vcHandler.bindParamsDefaultValue(params)
        return vcHandler.handler(ZTNavParameters(params: combinedParams))
    }

    static func regist(vcHandler: ZTVCHandler) {
        guard vcHandlers[vcHandler.path] == nil else {
#if DEBUG
            assert(false, "ZTNav Error: already regist same path vcHandler")
#endif
            return
        }
        ZTNavLog.log(.Info, "vcHandler: \(vcHandler.path)")
        vcHandlers[vcHandler.path] = vcHandler
    }

    static func regist(logicHandler: ZTLogicHandler) {
        guard logicHandlers[logicHandler.path] == nil else {
#if DEBUG
            assert(false, "ZTNav Error: already regist same path logicHandler")
#endif
            return
        }
        ZTNavLog.log(.Info, "regist logicHandler: \(logicHandler.path)")
        logicHandlers[logicHandler.path] = logicHandler
    }
    
    public static func regist(middleware: ZTNavMiddleware) {
        guard !middlewares.contains(where: { $0.name == middleware.name }) else {
#if DEBUG
        assert(false, "ZTNav Error: middleware with name \(middleware.name) already registered")
#endif
            return
        }
        ZTNavLog.log(.Info, "regist middleware: \(middleware.name)")
        middlewares.append(middleware)
    }
    
    public static func unregist(vcHandler: ZTVCHandler) {
        vcHandlers.removeValue(forKey: vcHandler.path)
        ZTNavLog.log(.Info, "unregist vcHandler: \(vcHandler.path)")
    }

    public static func unregist(logicHandler: ZTLogicHandler) {
        logicHandlers.removeValue(forKey: logicHandler.path)
        ZTNavLog.log(.Info, "unregist logicHandler: \(logicHandler.path)")
    }

    public static func unregist(name: String) {
        middlewares.removeAll { $0.name == name }
        ZTNavLog.log(.Info, "unregist middleware: \(name)")
    }

    private static func applyMiddlewares(to path: ZTNavPath, params: [String: Any]) -> (ZTNavPath, [String: Any]) {
        if case .ignore = path {
            return (path, params)
        }
        var combinedParams = parseQueryParameters(from: path)
        combinedParams.merge(params) { (_, new) in new }
        var mPath = path
        
        for middleware in middlewares {
            ZTNavLog.log(.Info, "will call middleware: \(middleware.name) url: \(mPath) params: \(combinedParams)")
            (mPath, combinedParams) = middleware.process(mPath, combinedParams)
            ZTNavLog.log(.Info, "did call middleware: \(middleware.name) url: \(mPath) params: \(combinedParams)")
        }
        
        if case .appUrl = mPath {} else if case .ignore = mPath {
            ZTNavLog.log(.Warning, "middleware ignore url: \(path) params: \(params)")
        } else {
            ZTNavLog.log(.Error, "The path processed by middleware cannot be a web path.")
        }
        return (mPath, combinedParams)
    }
    
    private static func parseQueryParameters(from path: ZTNavPath) -> [String: Any] {
        if case .ignore = path {
            return [:]
        }
        let url = switch path {
        case .web(let urlStr), .appUrl(let urlStr):
            urlStr
        case .ignore:
            ""
        }
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
    
    private static func canHandle(for path: ZTNavPath, params: [String: Any]) -> Bool {
        guard let handler:ZTNavHandler = vcHandlers[path] ?? logicHandlers[path] else {
            ZTNavLog.log(.Info, "Can't handle \(path) params:\(params)")
            return false
        }
        
        let result = handler.validateParams(params)
        ZTNavLog.log(.Info, "\(result ? "Can": "Can't") handle \(path) params:\(params)")
        return result
    }
    
    private static func tryTransNavPath(_ path: ZTNavPathProtocol) -> ZTNavPath? {
        if let p = path as? ZTNavPath {
            return p
        }
        if let stringPath = path as? String {
            return stringToPath(stringPath)
        }
        ZTNavLog.log(.Error, "Invalid path type")
        return nil
    }

    private static func stringToPath(_ string: String) -> ZTNavPath {
        if string.hasPrefix(AppSchema) {
            return .appUrl(string)
        } 
        return .web(string)
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
