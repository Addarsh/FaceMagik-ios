//
//  ViewController.swift
//  FaceMagik
//
//  Created by Addarsh Chandrasekar on 3/20/22.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func didTapButton(_ sender: UIButton) {
        guard let vc = SkinToneTest.storyboardInstance() else {
            return
        }
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true)
    }
    
}

