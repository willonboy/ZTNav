//
//  MallVC.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/16.
//

import UIKit

struct MallRouter {
    static var mall: ZTNavPath {
        .appUrl("//mall")
    }
}

class MallVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = self.zt.title("Mall ViewControll").subject
    }

}

