//
//  ViewController.swift
//  ZTNavDemo
//

import UIKit

extension ZTNavPath {
    static var root: ZTNavPath {
        .appUrl("//root")
    }
}


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        _ = self.zt.title("Root ViewControll").subject
    }

}

