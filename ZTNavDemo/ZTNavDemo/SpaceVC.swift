//
//  Space.swift
//  ZTNavDemo
//
//  Created by zt on 2024/8/16.
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
        
        _ = self.zt.title("Space ViewControll").subject
    }

}

