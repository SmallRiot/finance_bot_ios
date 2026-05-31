//
//  GroupService.swift
//  MillionersBot
//
//  Семейный доступ: создание группы, инвайт-коды, вступление/выход.
//  Хранится в Firestore (households/{id}), чтобы код был виден на всех устройствах.
//

import Foundation
import Observation
import FirebaseFirestore

struct HouseholdInfo {
    let id: String
    let name: String
    let inviteCode: String
    let baseCurrency: String
    let memberIDs: [String]
}

@MainActor
@Observable
final class GroupService {
    var isWorking = false
    var errorMessage: String?

    // Вычисляемое (а не stored), чтобы Firestore не трогался до FirebaseApp.configure().
    private var db: Firestore { Firestore.firestore() }
    private var collection: CollectionReference { db.collection("households") }
    private var inviteCodes: CollectionReference { db.collection("inviteCodes") }

    /// Создаёт новую группу и делает текущего пользователя её участником.
    /// Дополнительно пишет публичную запись inviteCodes/{КОД} → { householdId },
    /// чтобы по коду можно было найти семью, не открывая её данные посторонним.
    func createHousehold(name: String, uid: String, baseCurrency: String) async -> HouseholdInfo? {
        isWorking = true
        defer { isWorking = false }
        let id = UUID().uuidString
        let code = Self.generateInviteCode()
        let data: [String: Any] = [
            "name": name,
            "inviteCode": code,
            "memberIDs": [uid],
            "baseCurrency": baseCurrency,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        do {
            let batch = db.batch()
            batch.setData(data, forDocument: collection.document(id))
            batch.setData(["householdId": id, "createdAt": FieldValue.serverTimestamp()],
                          forDocument: inviteCodes.document(code))
            try await batch.commit()
            return HouseholdInfo(id: id, name: name, inviteCode: code, baseCurrency: baseCurrency, memberIDs: [uid])
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Вступает в группу по инвайт-коду. Возвращает nil, если код не найден.
    /// Сначала резолвит код через публичную коллекцию inviteCodes, затем
    /// добавляет себя в memberIDs (после чего уже может прочитать данные семьи).
    func joinHousehold(inviteCode: String, uid: String) async -> HouseholdInfo? {
        isWorking = true
        defer { isWorking = false }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            let codeDoc = try await inviteCodes.document(code).getDocument()
            guard codeDoc.exists, let hid = codeDoc.data()?["householdId"] as? String else {
                errorMessage = "Группа с таким кодом не найдена"
                return nil
            }
            // Добавляем себя в участники (разрешено правилами даже без права чтения).
            try await collection.document(hid).updateData(["memberIDs": FieldValue.arrayUnion([uid])])
            // Теперь мы участник — можно прочитать данные семьи.
            let document = try await collection.document(hid).getDocument()
            let data = document.data() ?? [:]
            var members = data["memberIDs"] as? [String] ?? []
            if !members.contains(uid) { members.append(uid) }
            return HouseholdInfo(
                id: hid,
                name: data["name"] as? String ?? "Семья",
                inviteCode: data["inviteCode"] as? String ?? code,
                baseCurrency: data["baseCurrency"] as? String ?? CurrencyCode.default.rawValue,
                memberIDs: members
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Выход из группы.
    func leaveHousehold(id: String, uid: String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await collection.document(id).updateData(["memberIDs": FieldValue.arrayRemove([uid])])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 6-значный код из заглавных букв и цифр (без похожих символов 0/O, 1/I).
    static func generateInviteCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }
}
