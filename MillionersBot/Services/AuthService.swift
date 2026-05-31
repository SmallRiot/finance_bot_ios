//
//  AuthService.swift
//  MillionersBot
//
//  Анонимная аутентификация через Firebase Auth.
//  Sign in with Apple добавим позже поверх этого же uid (linkWithCredential).
//

import Foundation
import Observation
import FirebaseAuth

@MainActor
@Observable
final class AuthService {
    private(set) var uid: String?
    var errorMessage: String?

    /// При старте: берём текущего пользователя либо логинимся анонимно.
    func bootstrap() async {
        if let user = Auth.auth().currentUser {
            uid = user.uid
            return
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            uid = result.user.uid
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
