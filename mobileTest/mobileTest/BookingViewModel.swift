//
//  BookingViewModel.swift
//  mobileTest
//
//  Created by jiahong on 2025/6/14.
//

import Foundation
import Combine

class BookingViewModel {
    @Published private(set) var booking: Booking?
    private var cancellables = Set<AnyCancellable>()
    
    /// fetch data
    func fetch() {
        BookingDataManager.shared.bookingPublisher()
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    if let serviceError = error as? BookingServiceError {
                        switch serviceError {
                        case .businessError(let code, let message):
                            print("Business error code: \(code), message: \(message ?? "")")
                        default:
                            break
                        }
                    } else {
                        print("Error: \(error)")
                    }
                }
            }, receiveValue: { [weak self] booking in
                print("================================================")
                print("Booking data [timestamp: \(Date().timeIntervalSince1970)]:\n\(booking)")
                self?.booking = booking
            })
            .store(in: &cancellables)
    }
}
