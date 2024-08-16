//
//  ViewController.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/16.
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
        
        _ = self.zt.title("Root ViewControll").subject
    }

}

