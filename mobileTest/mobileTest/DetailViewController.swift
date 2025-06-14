//
//  DetailViewController.swift
//  mobileTest
//
//  Created by jiahong on 2025/6/13.
//

import UIKit

class DetailViewController: UIViewController {
    private let label = UILabel()
    private let button = UIButton()
    var text: String?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        view.addSubview(label)
        label.frame = CGRect(origin: .zero, size: CGSize(width: view.bounds.size.width, height: 50))
        label.center = view.center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 28)
        label.textAlignment = .center
        label.text = text
    }
    @objc private func close() {
        navigationController?.popViewController(animated: true)
    }
}
