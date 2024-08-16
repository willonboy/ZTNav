//
//  AppDelegate.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/16.
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

        ZTNav.navVC(self.window?.rootViewController as? UINavigationController)
        
        registMiddleWare()
        
        registVcHandlers()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
            ZTNav.handle(.web("http://example.com/mall?param1=value1&param2=value2"))
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 6) {
            ZTNav.push(.web("http://example.com/mine?param1=43543&param2=value2"), animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 9) {
            ZTNav.push(.web("http://example.com/space?param1=value1&param2=value2"), animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 12) {
            ZTNav.handle(.root, params: ["p1":{return "block param"}])
        }
        
        return true
    }
    
    func report(_ url: String, params: [String: Any]?) {
        debugPrint("ZTNav APM try handle \(url) \nparams:\(params ?? [:])")
    }
    
    func registMiddleWare() {
        ZTNav.AppSchema = "//"
        
        // APM
        ZTNavMiddleware(name: "APMMiddleware") { [weak self] url, params in
            guard let self = self else { return (url, params) }
            self.report(url, params: params)
            return (url, params)
        }.regist()
        
        // 黑名单中间件，命中时转换为 app://link/blocked
        ZTNavMiddleware(name: "BlacklistMiddleware") { url, params in
            // 定义黑名单 URL 模式，可以是完整的 URL，也可以使用正则表达式
            let blacklistPatterns: [String] = [
                "^http(s)?:\\/\\/(www\\.)?malicious\\.com.*$",  // 匹配 malicious.com 域名
                "^http(s)?:\\/\\/(www\\.)?spam\\.org.*$",       // 匹配 spam.org 域名
            ]
            
            // 检查 URL 是否匹配黑名单中的任何模式
            for pattern in blacklistPatterns {
                let regex = try! NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: url.utf16.count)
                
                if regex.firstMatch(in: url, options: [], range: range) != nil {
                    // 如果 URL 匹配黑名单，转换为 "app://link/blocked"
                    let blockedUrl = "app://link/blocked"
                    debugPrint("ZTNav Middleware [BlacklistMiddleware] - Blocked URL: \(url), converted to: \(blockedUrl)")
                    return (blockedUrl, params)
                }
            }
            
            // 如果不在黑名单，返回原始 URL 和参数
            return (url, params)
        }.regist()
        
        // 正则表达式匹配和转换 HTTP 链接为 app schema URL
        ZTNavMiddleware(name: "HTTPTransToAppSchema") { url, params in
            // 正则匹配 http 类链接
            let httpRegex = try! NSRegularExpression(pattern: "^http(s)?:\\/\\/(www\\.)?example\\.com(\\/.*)?$", options: [])
            
            let range = NSRange(location: 0, length: url.utf16.count)
            if httpRegex.firstMatch(in: url, options: [], range: range) != nil {
                // 如果匹配到，转换为 app schema
                let nativeUrl = url.replacingOccurrences(of: "^http(s)?:\\/\\/(www\\.)?example\\.com(\\/)", with: "app://", options: .regularExpression)
                
                var combinedParams = [String: Any]()  // 先解析 URL 中的参数
                combinedParams.merge(params) { (_, new) in new }
                // 解析 url 中的 query 参数
                if let components = URLComponents(string: url), let queryItems = components.queryItems {
                    for item in queryItems {
                        // 合并 query 参数至 params
                        combinedParams[item.name] = item.value?.removingPercentEncoding ?? item.value
                    }
                }
                // 添加原始url进参数
                combinedParams["originUrl"] = url
                combinedParams["nativeUrl"] = nativeUrl
                
                
                // 移除 query 参数后，保留基础 URL
                var urlWithoutQuery = nativeUrl
                if let range = nativeUrl.range(of: "?") {
                    urlWithoutQuery = String(nativeUrl[..<range.lowerBound])
                }
                
                debugPrint("ZTNav Middleware [HTTPTransToAppSchema] - Converted Native URL: \(urlWithoutQuery)")
                return (urlWithoutQuery, combinedParams)
            }
            
            // 没有匹配则返回原始 URL
            return (url, params)
        }.regist()

        // 去除 native app schema 前缀的中间件
        ZTNavMiddleware(name: "RemoveAppSchemaPrefix") { url, params in
            // 检查并移除 app:// 前缀
            if url.hasPrefix("app://") {
                let newUrl = url.replacingOccurrences(of: "app://", with: ZTNav.AppSchema)
                debugPrint("ZTNav Middleware [RemoveAppSchemaPrefix] - Modified URL: \(newUrl)")
                return (newUrl, params)
            }
            
            // 没有前缀则不处理
            return (url, params)
        }.regist()
        
        // 解析 URL 中的 query 参数并合并到 params 中的中间件
        ZTNavMiddleware(name: "ParseQueryParamMiddleware") { url, params in
            // 使用 URLComponents 解析 URL 中的 query 参数
            if let components = URLComponents(string: url), let queryItems = components.queryItems {
                var combinedParams = params
                for queryItem in queryItems {
                    combinedParams[queryItem.name] = queryItem.value?.removingPercentEncoding ?? queryItem.value
                }
                // 移除 query 参数后，保留基础 URL
                var urlWithoutQuery = url
                if let range = url.range(of: "?") {
                    urlWithoutQuery = String(url[..<range.lowerBound])
                }
                
                debugPrint("ZTNav Middleware [ParseQueryParamMiddleware] - Parsed query parameters: \(combinedParams)")
                return (urlWithoutQuery, combinedParams)
            }

            // 如果没有 query 参数，返回原始的 URL 和参数
            return (url, params)
        }.regist()

    }

    
    
    func registVcHandlers() {
        ZTVCHandler(
            path: .mine,
            verifyParams: [
                ZTNavVerifyParam(name: "param1", type: String.self, defValue: "0"),
                ZTNavVerifyParam(name: "param2", type: String.self, defValue: "default")
            ],
            handler: { params in
                // 使用 params 动态查找参数
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
                ZTNav.navigationController?.popToRootViewController(animated: true)
            }
        ).regist()
    }
    
    
    
    
    
    
}

