//
//  Mine.swift
//  ZTNavDemo
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
        self.view.backgroundColor = .purple
        self.zt.title("Mine ViewControll").build()
    }

}

