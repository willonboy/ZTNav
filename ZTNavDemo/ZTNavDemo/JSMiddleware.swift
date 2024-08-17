//
//  JSMiddleware.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/17.
//

import Foundation
import JavaScriptCore

public class JSMiddleware {
    private static let jsContext: JSContext = {
        let jsContext = JSContext()!
        
        let jsSource = """
        function processUrl(url, params) {
            return {url: url, params: params};
        }
        """
        jsContext.evaluateScript(jsSource)
        return jsContext
    }()
    private static let jsFunctionName: String = "processUrl"
    
    public static func process(path: ZTNavPath, params: [String: Any]) -> (ZTNavPath, [String: Any]) {
        guard let jsFunction = jsContext.objectForKeyedSubscript(jsFunctionName) else {
            debugPrint("Error: JavaScript function \(jsFunctionName) not found")
            return (path, params)
        }
        guard case .web(let url) = path else {
            return (path, params)
        }
        
        let jsParams: [String: Any] = ["url": url, "params": params]
        let jsResult = jsFunction.call(withArguments: [jsParams])
        
        if let resultDict = jsResult?.toObject() as? [String: Any] {
            let newPath = resultDict["url"] as? String ?? url
            let newParams = resultDict["params"] as? [String: Any] ?? params
            debugPrint("Javascript process over")
            return (.web(newPath), newParams)
        }
        
        return (path, params)
    }
}
