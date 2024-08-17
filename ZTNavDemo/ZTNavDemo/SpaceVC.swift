//
//  Space.swift
//  ZTNavDemo
//

import UIKit

extension ZTNavPath {
    static var space: ZTNavPath {
        .appUrl("//space")
    }
}




class SpaceVC: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemPink
        _ = self.zt.title("Space ViewControll").subject
    }

}

