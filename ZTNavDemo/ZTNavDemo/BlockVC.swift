//
//  BlockVC.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/16.
//

import UIKit

extension ZTNavPath {
    static var linkBlocked: ZTNavPath {
        .appUrl("//link/blocked")
    }
}

class BlockVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = self.zt.title("Mall ViewControll").subject
    }

}

