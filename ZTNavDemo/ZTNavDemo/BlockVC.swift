//
//  BlockVC.swift
//  ZTNavDemo
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
        self.view.backgroundColor = .systemYellow
        self.zt.title("Mall ViewControll").build()
    }

}

