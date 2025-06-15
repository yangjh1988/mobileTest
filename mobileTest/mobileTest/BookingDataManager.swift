//
//  BookingDataManager.swift
//  mobileTest
//
//  Created by jiahong on 2025/6/13.
//

import Foundation
import Combine

/// Manages booking data.
class BookingDataManager {
    /// Shared instance for data manager.
    static let shared = BookingDataManager()
    private let service = BookingService.shared
    private init() {}

    /// Publishes booking updates: first cached, then fresh if expired.
    ///
    /// - Returns: A publisher emitting `Booking` or an `Error`.
    func bookingPublisher() -> AnyPublisher<Booking, Error> {
        let freshPublisher =
        Deferred {
            Future<Booking, Error> { promise in
                Task {
                    do {
                        let fresh = try await self.service.fetchFreshBooking()
                        promise(.success(fresh))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }

        if let cached = service.getCachedBooking() {
            let cachedPub = Just(cached.booking)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            if !cached.isExpired() {
                return cachedPub
            }
            return cachedPub
                .append(freshPublisher)
                .eraseToAnyPublisher()
        } else {
            return freshPublisher.eraseToAnyPublisher()
        }
    }
}

struct BookingResponse {
    var message: String
    var code: Int
    var data: Data?
    
    static func mockBookingResponse() async throws -> BookingResponse? {
        /// simulate the network request
        try await Task.sleep(nanoseconds: 1000_000_000)
        guard let url = Bundle.main.url(forResource: "booking", withExtension: "json") else {
            throw BookingServiceError.businessError(code: -1, message: "booking.json not found")
        }
        do {
            let data = try Data(contentsOf: url)
            return BookingResponse(message: "", code: 200, data: data)
        } catch let error as NSError {
            throw BookingServiceError.businessError(code: error.code, message: error.localizedDescription)
        }
    }
}

/// Represents a booking with ship details and travel segments.
struct Booking: Codable {
    let shipReference: String
    let shipToken: String
    let canIssueTicketChecking: Bool
    let expiryTime: String
    let duration: Int
    var segments: [Segment]
    
    /// Generates a mock `Booking` instance with sample data.
    ///
    /// - Returns: A `Data` populated with 10 sample `Segment` items.
    static func mockBooking() -> Data? {
        
        let shipReference = "ABCDEF"
        let shipToken = "AAAABBBCCCCDDD"
        let canIssueTicketChecking = true
        let expiryTime = String(Date().timeIntervalSince1970)
        /// trip totol time(minutes)
        var duration = 0
        var segments = [Segment]()
        let cnt = Int(arc4random()%2 + 2)
        for i in 1...cnt {
            let origin = Location(code: "AAA", displayName: "AAA DisplayName", url: "www.ship.com")
            let destination = Location(code: "BBB", displayName: "BBB DisplayName", url: "www.ship.com")
            let pair = OriginDestinationPair(origin: origin, destination: destination,
                                             originCity: "City\(i)", destinationCity: "City\(i+1)")
            segments.append(Segment(id: i, originAndDestinationPair: pair))
            duration += Int(arc4random()%4 + 3) * 60
        }
        let booking =  Booking(shipReference: shipReference,
                       shipToken: shipToken,
                       canIssueTicketChecking: canIssueTicketChecking,
                       expiryTime: expiryTime,
                       duration: duration,
                       segments: segments)
        guard let data = try? JSONEncoder().encode(booking) else { return nil }
        return data
    }
}

/// Represents a travel segment with origin and destination pair.
struct Segment: Codable {
    let id: Int
    let originAndDestinationPair: OriginDestinationPair
}

/// Holds origin and destination location details for a segment.
struct OriginDestinationPair: Codable {
    let origin: Location
    let destination: Location
    let originCity: String
    let destinationCity: String
}

/// Represents a geographic location with code and display information.
struct Location: Codable {
    let code: String
    let displayName: String
    let url: String
}

/// Defines errors thrown by `BookingService`.
enum BookingServiceError: Error {
    case decodingFailed(Error)
    case businessError(code: Int, message: String?)
}

struct BookingCache: Codable {
    let timestamp: TimeInterval
    let booking: Booking
    
    func isExpired() -> Bool {
        return true
//        return Date().timeIntervalSince1970 - timestamp > 60 * 5
    }
}

/// Caches `Booking` data to a local file in the caches directory.
class BookingDataCache {
    /// Singleton instance for file-based booking cache.
    static let shared = BookingDataCache()
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("booking_cache.json")
    }()
    /// momery cache
    private var cached: BookingCache?
    private init() {}
    private func loadCached() -> BookingCache? {
        if let cached = self.cached {
            return cached
        }
        guard let data = try? Data(contentsOf: fileURL),
              let cached = try? JSONDecoder().decode(BookingCache.self, from: data) else { return nil }
        self.cached = cached
        return cached
    }
    func load() -> BookingCache? {
        loadCached()
    }
    
    func save(_ booking: Booking) {
        let cached = BookingCache(timestamp: Date().timeIntervalSince1970, booking: booking)
        self.cached = cached
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Provides booking data retrieval, caching, and business validation.
class BookingService {
    /// Singleton instance for booking service.
    static let shared = BookingService()
    private init() {}
    
    /// Retrieves a cached booking if available.
    ///
    /// - Returns: The cached `Booking`, or `nil` if none.
    func getCachedBooking() -> BookingCache? {
        BookingDataCache.shared.load()
    }

    /// Fetches booking data, performing business validation.
    ///
    /// - Throws: `BookingServiceError.businessError` if validation fails.
    /// - Returns: A `Booking` object.
    func fetchBooking() async throws -> Booking {
        guard let response = try await BookingResponse.mockBookingResponse() else {
            throw BookingServiceError.businessError(code: 400, message: "some http/https error")
        }
        guard response.code == 200, let data = response.data else {
            throw BookingServiceError.businessError(code: response.code, message: response.message)
        }
        do {
            let booking = try JSONDecoder().decode(Booking.self, from: data)
            return booking
        } catch {
            print("Decoding error: \(error)")
            throw BookingServiceError.decodingFailed(error)
        }
    }

    /// Fetches fresh booking data and updates the cache.
   ///
   /// - Throws: Errors from `fetchBooking()`.
   /// - Returns: A fresh `Booking` object.
    func fetchFreshBooking() async throws -> Booking {
        let booking = try await fetchBooking()
        BookingDataCache.shared.save(booking)
        return booking
    }
}


