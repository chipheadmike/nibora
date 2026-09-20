//
//  WeatherService.swift
//  Nibora
//

import Foundation
import CoreLocation

/// Keeps a cached current temperature fresh in the background so the
/// timestamp hotkey (which must feel instant) never has to wait on a
/// network call — it just reads whatever's already cached. No API key
/// needed: CLGeocoder (a system service, not device-location tracking, so
/// no location permission prompt) turns the zip code into coordinates, and
/// Open-Meteo's free public API turns those into a temperature, the same
/// plain-URLSession-REST pattern already used for the Claude/ChatGPT
/// providers elsewhere in this app.
@Observable
final class WeatherService {
    private(set) var currentTemperatureText: String?

    private var lastFetchedZipCode: String?
    private var lastFetchedAt: Date?
    private let freshnessWindow: TimeInterval = 20 * 60

    /// Safe to call often — only actually fetches when the zip code changed
    /// or the cache has aged past freshnessWindow.
    func refreshIfNeeded(zipCode: String) {
        let trimmed = zipCode.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            currentTemperatureText = nil
            lastFetchedZipCode = nil
            lastFetchedAt = nil
            return
        }

        if trimmed != lastFetchedZipCode {
            currentTemperatureText = nil
        } else if let lastFetchedAt, Date().timeIntervalSince(lastFetchedAt) < freshnessWindow {
            return
        }

        Task { [weak self] in
            await self?.fetch(zipCode: trimmed)
        }
    }

    private func fetch(zipCode: String) async {
        do {
            let coordinate = try await Self.geocode(zipCode: zipCode)
            let temperature = try await Self.fetchTemperature(latitude: coordinate.latitude, longitude: coordinate.longitude)
            currentTemperatureText = "\(temperature)F"
            lastFetchedZipCode = zipCode
            lastFetchedAt = Date()
        } catch {
            // A background refresh failing (offline, bad zip, API hiccup)
            // just leaves whatever was cached before in place.
        }
    }

    private static func geocode(zipCode: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await CLGeocoder().geocodeAddressString(zipCode)
        guard let location = placemarks.first?.location else {
            throw WeatherServiceError.geocodingFailed
        }
        return location.coordinate
    }

    private static func fetchTemperature(latitude: Double, longitude: Double) async throws -> Int {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit")
        ]
        guard let url = components.url else { throw WeatherServiceError.badURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return Int(response.current.temperature2m.rounded())
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature2m: Double

            private enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
            }
        }
        let current: Current
    }

    private enum WeatherServiceError: Error {
        case geocodingFailed
        case badURL
    }
}
