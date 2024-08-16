//
//  Mine.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/16.
//

import UIKit

extension ZTNavPath {
    static var mine: ZTNavPath {
        .appUrl("//mine")
    }
}

class MineVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = self.zt.title("Mine ViewControll").subject
    }

}

