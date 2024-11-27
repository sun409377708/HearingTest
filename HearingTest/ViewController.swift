//
//  ViewController.swift
//  HearingTest
//
//  Created by maoge on 2024/11/14.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .orange
    }

    @IBAction func btnAction(_ sender: Any) {

        let vc = HearingTestViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
}

