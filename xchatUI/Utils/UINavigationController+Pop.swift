//
//  UIViewController+Pop.swift
//  allnet-xchat
//
//  Created by Tiago Do Couto on 2/27/18.
//  Copyright © 2018 allnet. All rights reserved.
//

import UIKit

extension UINavigationController {
    func popToViewControllerFor(_ index: Int){
        self.popToViewController(self.viewControllers[self.viewControllers.count - 1 - index], animated: true)
    }
}
