//
//  MallVC.swift
//  ZTNavDemo
//

import UIKit

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


class MallVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGray2
        _ = self.zt.title("Mall ViewControll").subject
    }

}

