//
//  BabyLogTests.swift
//  BabyLogTests
//
//  Created by Mohana Vista on 9/29/26.
//

import Testing
import FirebaseAuth
@testable import BabyLog

struct BabyLogTests {
    @Test func authErrorMessagesAreCompactAndSpecific() {
        #expect(message(for: .invalidEmail) == "Enter a valid email address.")
        #expect(message(for: .emailAlreadyInUse) == "That email is already in use.")
        #expect(message(for: .weakPassword) == "Password must be at least 6 characters.")
        #expect(message(for: .invalidCredential) == "Incorrect email or password.")
        #expect(message(for: .networkError) == "No connection. Try again.")
        #expect(message(for: .tooManyRequests) == "Too many attempts. Try again later.")
    }

    @Test func unknownAuthErrorUsesCompactFallback() {
        let error = NSError(domain: "BabyLogTests", code: Int.max)

        #expect(AuthErrorPresenter.message(for: error) == "Something went wrong. Try again.")
    }

    @Test func babyDefaultsMatchClarifiedNightWindow() {
        let baby = Baby(id: "baby", name: "A", birthDate: .now, createdByUserID: "user", createdAt: .now, updatedAt: .now)

        #expect(baby.nightStartMinutes == 1_140)
        #expect(baby.nightEndMinutes == 420)
    }

    @Test func babyValidationErrorsAreCompactAndSpecific() {
        #expect(BabyErrorPresenter.message(for: BabyRepositoryError.missingName) == "Enter your baby’s name.")
        #expect(BabyErrorPresenter.message(for: BabyRepositoryError.futureBirthDate) == "Birth date can’t be in the future.")
        #expect(BabyErrorPresenter.message(for: BabyRepositoryError.missingUserID) == "Enter a user ID.")
    }

    @Test func babyLookupFiltersRemovedMembershipsClientSide() {
        let now = Date()
        let active = BabyMembership(id: "active", babyID: "baby-a", userID: "active", role: .caregiver, status: .active, createdAt: now, updatedAt: now)
        let removed = BabyMembership(id: "removed", babyID: "baby-b", userID: "removed", role: .caregiver, status: .removed, createdAt: now, updatedAt: now)

        #expect(BabyRepository.activeMemberships(from: [removed, active]) == [active])
    }

    private func message(for code: AuthErrorCode) -> String {
        let error = NSError(domain: "BabyLogTests", code: code.rawValue)
        return AuthErrorPresenter.message(for: error)
    }
}
