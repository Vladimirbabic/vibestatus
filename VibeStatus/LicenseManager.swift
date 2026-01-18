// LicenseManager.swift
// VibeStatus
//
// Manages license key validation using Polar.sh API.
// Responsible for:
// - Storing and retrieving license keys
// - Validating licenses against Polar.sh
// - Caching validation results

import Foundation
import Combine

/// Manages license key storage and validation via Polar.sh.
///
/// Use `LicenseManager.shared` to access the singleton instance.
/// All properties are @Published for SwiftUI binding.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    // MARK: - Published State

    /// The stored license key (may be empty)
    @Published var licenseKey: String {
        didSet {
            UserDefaults.standard.set(licenseKey, forKey: UserDefaultsKey.licenseKey.rawValue)
        }
    }

    /// Current license validation status
    @Published private(set) var licenseStatus: LicenseStatus

    /// Whether validation is currently in progress
    @Published private(set) var isValidating: Bool = false

    /// Error message from last validation attempt, if any
    @Published private(set) var validationError: String?

    /// When the license was last successfully validated
    @Published private(set) var lastValidatedAt: Date?

    // MARK: - Initialization

    private init() {
        licenseKey = UserDefaults.standard.string(forKey: UserDefaultsKey.licenseKey.rawValue) ?? ""

        if let statusString = UserDefaults.standard.string(forKey: UserDefaultsKey.licenseStatus.rawValue),
           let status = LicenseStatus(rawValue: statusString) {
            licenseStatus = status
        } else {
            licenseStatus = .notValidated
        }

        if let timestamp = UserDefaults.standard.object(forKey: UserDefaultsKey.licenseValidatedAt.rawValue) as? Date {
            lastValidatedAt = timestamp
        }
    }

    // MARK: - Public API

    /// Whether the app is currently licensed
    var isLicensed: Bool {
        licenseStatus.isActive
    }

    /// Validate the current license key against Polar.sh
    @discardableResult
    func validateLicense() async -> Bool {
        guard !licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            licenseStatus = .notValidated
            saveLicenseStatus()
            return false
        }

        isValidating = true
        validationError = nil

        do {
            let result = try await performValidation(key: licenseKey)
            processValidationResult(result)
            isValidating = false
            return licenseStatus.isActive
        } catch {
            validationError = error.localizedDescription
            licenseStatus = .invalid
            saveLicenseStatus()
            isValidating = false
            return false
        }
    }

    /// Validate a specific license key (used when entering a new key)
    @discardableResult
    func validateLicense(key: String) async -> Bool {
        licenseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return await validateLicense()
    }

    /// Clear the stored license
    func clearLicense() {
        licenseKey = ""
        licenseStatus = .notValidated
        lastValidatedAt = nil
        validationError = nil
        saveLicenseStatus()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.licenseValidatedAt.rawValue)
    }

    /// Check if license needs revalidation (past 24 hours)
    func needsRevalidation() -> Bool {
        guard licenseStatus.isActive, let lastValidated = lastValidatedAt else {
            return !licenseKey.isEmpty
        }
        return Date().timeIntervalSince(lastValidated) > LicenseConstants.revalidationIntervalSeconds
    }

    // MARK: - Private Methods

    private func performValidation(key: String) async throws -> PolarValidationResponse {
        guard let url = URL(string: LicenseConstants.validationURL) else {
            throw LicenseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = PolarValidationRequest(
            key: key,
            organizationId: LicenseConstants.organizationId
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PolarValidationResponse.self, from: data)
        case 404:
            throw LicenseError.licenseNotFound
        case 422:
            throw LicenseError.invalidRequest
        default:
            throw LicenseError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func processValidationResult(_ result: PolarValidationResponse) {
        switch result.status {
        case "granted":
            // Check if expired
            if let expiresAt = result.expiresAt, expiresAt < Date() {
                licenseStatus = .expired
            } else {
                licenseStatus = .valid
                lastValidatedAt = Date()
                UserDefaults.standard.set(lastValidatedAt, forKey: UserDefaultsKey.licenseValidatedAt.rawValue)
            }
        case "revoked":
            licenseStatus = .revoked
        case "disabled":
            licenseStatus = .invalid
        default:
            licenseStatus = .invalid
        }
        saveLicenseStatus()
    }

    private func saveLicenseStatus() {
        UserDefaults.standard.set(licenseStatus.rawValue, forKey: UserDefaultsKey.licenseStatus.rawValue)
    }
}

// MARK: - Polar API Types

private struct PolarValidationRequest: Encodable {
    let key: String
    let organizationId: String

    enum CodingKeys: String, CodingKey {
        case key
        case organizationId = "organization_id"
    }
}

private struct PolarValidationResponse: Decodable {
    let id: String
    let status: String
    let key: String
    let organizationId: String
    let customerId: String
    let benefitId: String
    let expiresAt: Date?
    let usage: Int
    let limitUsage: Int?
    let validations: Int
}

// MARK: - License Errors

enum LicenseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case licenseNotFound
    case invalidRequest
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid validation URL"
        case .invalidResponse:
            return "Invalid server response"
        case .licenseNotFound:
            return "License key not found"
        case .invalidRequest:
            return "Invalid license key format"
        case .serverError(let code):
            return "Server error (code: \(code))"
        }
    }
}
