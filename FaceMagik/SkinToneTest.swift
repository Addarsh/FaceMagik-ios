//
//  SkinToneTest.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/20/22.
//

import UIKit

class SkinToneTest: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    static func storyboardInstance() -> UINavigationController? {
        let className = String(describing: SkinToneTest.self)
        let storyboard = UIStoryboard(name: className, bundle: nil)
        return storyboard.instantiateInitialViewController() as UINavigationController?
    }

}
