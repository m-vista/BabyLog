//
//  AuthService.swift
//  BabyLog
//

import Foundation
import FirebaseAuth

/// Session state and email/password auth actions.
/// See Implementation Plan Phase 2 and Technical Requirements section 3.
@MainActor
@Observable
final class AuthService {
    enum SessionState: Equatable {
        case unknown
        case signedOut
        case signedIn(uid: String)
    }

    private(set) var sessionState: SessionState = .unknown

    private let userRepository: UserRepository
    // deinit is always nonisolated, even on a @MainActor class; the handle itself
    // is an opaque, thread-safe token, so it's safe to remove it from there.
    @ObservationIgnored
    private nonisolated(unsafe) var authStateHandle: AuthStateDidChangeListenerHandle?

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }

                self.sessionState = user.map { .signedIn(uid: $0.uid) } ?? .signedOut

                // Profile creation is intentionally best-effort while Firestore is
                // deny-all. Retrying on every restored or new signed-in session lets
                // a missing signup profile be created after Phase 3 deploys its rules.
                if let user {
                    await self.createProfileIfPossible(
                        uid: user.uid,
                        displayName: user.displayName ?? "",
                        email: user.email ?? ""
                    )
                }
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func createAccount(displayName: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        await createProfileIfPossible(uid: result.user.uid, displayName: displayName, email: email)
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    var currentEmail: String { Auth.auth().currentUser?.email ?? "" }
    var currentDisplayName: String { Auth.auth().currentUser?.displayName ?? "" }

    func updateDisplayName(_ displayName: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let value = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = user.createProfileChangeRequest()
        request.displayName = value
        try await request.commitChanges()
        try await userRepository.updateDisplayName(value, userID: user.uid)
    }

    private func createProfileIfPossible(uid: String, displayName: String, email: String) async {
        guard !displayName.isEmpty, !email.isEmpty else { return }

        // Authentication must remain usable if Firestore rejects this write.
        // UserRepository keeps this idempotent when a later session retries it.
        try? await userRepository.createProfileIfNeeded(
            uid: uid,
            displayName: displayName,
            email: email
        )
    }
}

/// Maps FirebaseAuth errors to compact, user-facing text (Phase 2 "Validate": auth errors are compact).
enum AuthErrorPresenter {
    static func message(for error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return "Something went wrong. Try again."
        }
        switch code {
        case .invalidEmail:
            return "Enter a valid email address."
        case .emailAlreadyInUse:
            return "That email is already in use."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .wrongPassword, .userNotFound, .invalidCredential:
            return "Incorrect email or password."
        case .networkError:
            return "No connection. Try again."
        case .tooManyRequests:
            return "Too many attempts. Try again later."
        default:
            return "Something went wrong. Try again."
        }
    }
}
