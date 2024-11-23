# ZTNav Documentation

## Introduction
`ZTNav` is a lightweight and flexible navigation management system for iOS applications that abstracts away direct URL handling. It provides a way to manage navigation between view controllers and logic handlers using a unified schema. By using custom URL schemes and middleware, `ZTNav` can streamline navigation flows without the native code directly interacting with web URLs.

### Key Features
- **Path-based Navigation**: Supports native and web URL navigation using custom schemas.
- **View Controller and Logic Handlers**: Handles both view controllers and logic flows with reusable handlers.
- **Middleware System**: Allows for processing and modifying paths and parameters before navigation.
- **Error Handling**: Provides mechanisms for handling navigation failures.

## Requirements
- iOS 13.0+
- Swift 5.0+

## Installation

### Swift Package Manager
You can also use Swift Package Manager to integrate ZTNav into your Xcode project. Simply add it as a dependency in your `Package.swift` file:

```swift
dependencies: [
.package(url: "https://github.com/willonboy/ZTNav.git", from: "0.1.0")
]
```

## Usage

```swift
// set a global "failed handler"
ZTNav.failedHandler { path, params in
    debugPrint("Demo Navigation failed for URL: \(path) with params: \(params ?? [:])")
}

// set a global navigationcontroller 
ZTNav.navVC(self.window?.rootViewController as? UINavigationController)


// process router of web url
ZTNav.handle("http://example.com/mall?param1=value1&param2=value2")
ZTNav.push("http://example.com/mine?param1=43543&param2=value2", animated: true)
ZTNav.present("http://example.com/space?param1=value1&param2=value2", animated: true)


// define the app router URL and associated parameters.
extension ZTNavPath {
    static var root: ZTNavPath {
        .appUrl("//root")
    }
}

// regist ZTNavPath.root logic router handler
ZTLogicHandler(
    path: .root, 
    handler: { params in
        ZTNav.navigationController?.dismiss(animated: true)
        ZTNav.navigationController?.popToRootViewController(animated: true)
    }
).regist()

// process app router
ZTNav.handle(ZTNavPath.root, params: ["p1": { return "block param" }])


struct MallRouter {
    static var mall: ZTNavPath {
        .appUrl("//mall")
    }
    
    struct Keys {
        static var mallId : ZTNavVerifyParam.Key {
            .key("param1")
        }
    }
}

extension ZTNavVerifyParam.Key {
    static var mallName : ZTNavVerifyParam.Key {
        .key("param2")
    }
}

// regist Mall router vc handler
ZTVCHandler(
            path: MallRouter.mall,
            verifyParams: [
                .init(key: MallRouter.Keys.mallId, type: String.self, defValue: "0"),
                .init(key: .mallName, type: String.self, defValue: "default")
            ],
            handler: { params in
                if let mallId = params[dynamicMember: MallRouter.Keys.mallId.name] as? String {
                    print("mallId: \(mallId)")
                }
                if let mallName = params[dynamicMember: ZTNavVerifyParam.Key.mallName.name] as? String {
                    print("mallName: \(mallName)")
                }
                return MallVC()
            }
        ).regist()

// jump to mall vc
ZTNav.handle(MallRouter.mall, params: ["param1": "mall_id_2847","param2": "Mall name"])

```

## Regist Middleware
```swift

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
        
        // Middleware can be defined with nested combinations
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

```

## Regist VC handler & Logic handler

```swift

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
            if let mallId = params[dynamicMember: MallRouter.Keys.mallId.name] as? String {
                print("mallId: \(mallId)")
            }
            if let mallName = params[dynamicMember: ZTNavVerifyParam.Key.mallName.name] as? String {
                print("mallName: \(mallName)")
            }
            return MallVC()
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
```


## License
ZTNav is available under the MPL-2.0 license. See the [LICENSE](LICENSE) file for more information.
