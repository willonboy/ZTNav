//
//  AppDelegate.swift
//  ZTNavDemo
//

import UIKit
import ZTChain

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.main.bounds)
            .zt
            .backgroundColor(.white)
            .rootViewController(UINavigationController(rootViewController: ViewController()))
            .subject
        self.window?.makeKeyAndVisible()

        ZTNav.failedHandler { path, params in
            debugPrint("Demo Navigation failed for URL: \(path) with params: \(params ?? [:])")
        }
        ZTNav.navVC(self.window?.rootViewController as? UINavigationController)
        
        registMiddleWare()
        
        registVcHandlers()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
            ZTNav.handle("http://example.com/mall?param1=value1&param2=value2")
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 6) {
            ZTNav.handle("http://example.com/ignore?param1=value1&param2=value2")
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 9) {
            ZTNav.handle("http://example.com/mall/xxx?param1=value1&param2=value2")
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 12) {
            ZTNav.push("http://example.com/mine?param1=43543&param2=value2", animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 15) {
            ZTNav.present("http://example.com/space?param1=value1&param2=value2", animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 18) {
            ZTNav.handle(ZTNavPath.root, params: ["p1": { return "block param" }])
        }
        
        return true
    }
    
    func report(_ url: ZTNavPath, params: [String: Any]?) {
        debugPrint("Demo log: APM Info: try handle \(url) params:\(params ?? [:])")
    }
    
    func registMiddleWare() {
        ZTNav.AppSchema = "//"
        
        ZTNavMiddleware(name: "APMMiddleware") { [weak self] url, params in
            guard let self = self else { return (url, params) }
            self.report(url, params: params)
            return (url, params)
        }.regist()
        
        ZTNavMiddleware(name: "BlacklistMiddleware") { path, params in
            guard case .web(let url) = path else {
                return (path, params)
            }

            let blacklistPatterns: [String] = [
                "^http(s)?:\\/\\/(www\\.)?malicious\\.com.*$",  // 匹配 malicious.com 域名
                "^http(s)?:\\/\\/(www\\.)?spam\\.org.*$",       // 匹配 spam.org 域名
            ]
            
            for pattern in blacklistPatterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: url.utf16.count)
                
                if regex.firstMatch(in: url, options: [], range: range) != nil {
                    let blockedUrl = "app://link/blocked"
                    debugPrint("Demo log: Middleware [BlacklistMiddleware] - Blocked URL: \(url), converted to: \(blockedUrl)")
                    return (.appUrl(blockedUrl), params)
                }
            }
            return (path, params)
        }.regist()
        
        ZTNavMiddleware(name: "JSMiddleware") { path, params in
            return JSMiddleware.process(path: path, params: params)
        }.regist()
        
        ZTNavMiddleware(name: "HTTPTransToAppSchema") { path, params in
            guard case .web(let url) = path else {
                return (path, params)
            }
            let httpRegex = try! NSRegularExpression(pattern: "^http(s)?:\\/\\/(www\\.)?example\\.com(\\/.*)?$", options: [])
            
            let range = NSRange(location: 0, length: url.utf16.count)
            if httpRegex.firstMatch(in: url, options: [], range: range) != nil {
                let nativeUrl = url.replacingOccurrences(of: "^http(s)?:\\/\\/(www\\.)?example\\.com(\\/)", with: "app://", options: .regularExpression)
                
                var combinedParams = [String: Any]()
                combinedParams.merge(params) { (_, new) in new }
                combinedParams["originUrl"] = url
                combinedParams["nativeUrl"] = nativeUrl
                
                var urlWithoutQuery = nativeUrl
                if let range = nativeUrl.range(of: "?") {
                    urlWithoutQuery = String(nativeUrl[..<range.lowerBound])
                }
                
                debugPrint("Demo log: Middleware [HTTPTransToAppSchema] - Converted Native URL: \(urlWithoutQuery)")
                return (.appUrl(urlWithoutQuery), combinedParams)
            }
            return (path, params)
        }.regist()

        ZTNavMiddleware(name: "AppSchemaProcessMiddleward") {
            /*
            ZTNavMiddleware(name: "ParseIgnoreMiddleware") { path, params in
                guard case .appUrl(let p) = path else {
                    return (path, params)
                }

                if p != "app://link/blocked" { return (path, params) }
                return (.ignore, params)
            }
             */
            
            ZTNavMiddleware(name: "RemoveAppSchemaPrefix") { path, params in
                guard case .appUrl(let url) = path else {
                    return (path, params)
                }
                if url.hasPrefix("app://") {
                    let newUrl = url.replacingOccurrences(of: "app://", with: ZTNav.AppSchema)
                    debugPrint("Demo log: Middleware [RemoveAppSchemaPrefix] - Modified URL: \(newUrl)")
                    return (.appUrl(newUrl), params)
                }
                
                return (path, params)
            }
            
            ZTNavMiddleware(name: "AppSchemaOtherMiddleward") {
                ZTNavMiddleware(name: "ParseQueryParamMiddleware") { path, params in
                    if case .ignore = path { return (path, params) }
                    let url = switch path {
                    case .web(let urlStr), .appUrl(let urlStr):
                        urlStr
                    case .ignore:
                        ""
                    }
                    
                    if let components = URLComponents(string: url), let queryItems = components.queryItems {
                        var combinedParams = params
                        for queryItem in queryItems {
                            combinedParams[queryItem.name] = queryItem.value?.removingPercentEncoding ?? queryItem.value
                        }
                        var urlWithoutQuery = url
                        if let range = url.range(of: "?") {
                            urlWithoutQuery = String(url[..<range.lowerBound])
                        }
                        
                        debugPrint("Demo log: Middleware [ParseQueryParamMiddleware] - Parsed query parameters: \(combinedParams)")
                        return (.appUrl(urlWithoutQuery), combinedParams)
                    }

                    return (path, params)
                }
                
                ZTNavMiddleware(name: "ParseIgnoreMiddleware") { path, params in
                    if case .ignore = path {
                        return (path, params)
                    }
                    let url = switch path {
                    case .web(let urlStr), .appUrl(let urlStr):
                        urlStr
                    case .ignore:
                        ""
                    }
                    
                    if url.hasPrefix("//ignore") {
                        return (.ignore, params)
                    }
                    return (path, params)
                }
            }
        }.regist()
    }
    
    func registVcHandlers() {
        ZTVCHandler(
            path: .mine,
            verifyParams: [
                .init(key: .key("param1"), type: String.self, defValue: "0"),
                .init(key: .key("param2"), type: String.self, defValue: "default")
            ],
            handler: { params in
                if let seasonId = params.param1 as? String {
                    print("seasonId: \(seasonId)")
                }
                if let msg = params.param2 as? Int {
                    print("msg: \(msg)")
                }
                return MineVC()
             }
        ).regist()
        
        ZTVCHandler(
            path: MallRouter.mall,
            verifyParams: [
                .init(key: MallRouter.Keys.mallId, type: String.self, defValue: "0"),
                .init(key: .mallName, type: String.self, defValue: "default")
            ],
            handler: { params in
                MallVC()
            }
        ).regist()
        
        ZTVCHandler(
            path: .space,
            handler: { params in
                SpaceVC()
            }
        ).regist()
        
        ZTLogicHandler(
            path: .root, 
            handler: { params in
                ZTNav.navigationController?.dismiss(animated: true)
                ZTNav.navigationController?.popToRootViewController(animated: true)
            }
        ).regist()
    }
    
}

