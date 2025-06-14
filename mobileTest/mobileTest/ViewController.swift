//
//  ViewController.swift
//  mobileTest
//
//  Created by jiahong on 2025/6/13.
//

import UIKit
import Combine

internal class ViewController: UIViewController {
    /// tableview to display booking info
    private lazy var tableView: UITableView = {
        let view = UITableView(frame: view.bounds, style: .plain)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.rowHeight = 64.0
        view.dataSource = self
        view.delegate = self
        return view
    }()
    /// booking viewmodel
    private let viewModel = BookingViewModel()
    /// cancellables
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        bindAction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadData()
    }
}

//MARK: private methods
extension ViewController {
    /// bind viewmodel
    private func bindAction() {
        viewModel.$booking
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] booking in
                self?.tableView.tableHeaderView = self?.buildHeader(for: booking)
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }
    
    /// build up ui
    private func buildUI() {
        title = "Booking"
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
    }
    
    /// load booking data
    private func loadData() {
        viewModel.fetch()
    }
    
    /// build the tableheader to display booking's ship info
    /// - Parameter booking: booking model
    /// - Returns: tableheaderview
    private func buildHeader(for booking: Booking) -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 100))
        header.backgroundColor = .clear
        let label = UILabel(frame: header.bounds.insetBy(dx: 20, dy: 8))
        label.numberOfLines = 0
        label.text = "Ref: \(booking.shipReference)\nToken: \(booking.shipToken)\nExpiry: \(Date(timeIntervalSince1970: TimeInterval(booking.expiryTime) ?? 0))\nDuration: \(booking.duration)"
        header.addSubview(label)
        return header
    }
}

//MARK: UITableViewDataSource & UITableViewDelegate
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.booking?.segments.count ?? 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .none
        if let seg = viewModel.booking?.segments[indexPath.row] {
            cell.textLabel?.text = "\(seg.originAndDestinationPair.originCity) → \(seg.originAndDestinationPair.destinationCity)"
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let seg = viewModel.booking?.segments[indexPath.row] {
            let detail = DetailViewController()
            detail.text = "\(seg.originAndDestinationPair.originCity) → \(seg.originAndDestinationPair.destinationCity)"
            navigationController?.pushViewController(detail, animated: true)
        }
    }
}
