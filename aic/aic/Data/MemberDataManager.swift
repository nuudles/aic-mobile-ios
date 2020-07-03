/*
Abstract:
Validates and Retrieves member card information
*/

import Alamofire

protocol MemberDataManagerDelegate: class {
	func memberCardDidLoadForMember(memberCard: AICMemberCardModel)
	func memberCardDataLoadingFailed()
}

class MemberDataManager {
	// MARK: - Private Properties -
	private struct MemberCardResponse: Decodable {
		struct Member: Decodable {
			let firstName: String
			let lastName: String
		}

		struct MemberData: Decodable {
			let id: Int
			let itemName: String
			let validUntil: Date
			let members: [Member]
		}

		let data: MemberData
	}

	// MARK: - Properties -
	static let sharedInstance = MemberDataManager()

	private (set) var currentMemberCard: AICMemberCardModel?
	var currentMemberNameIndex: Int = 0

	weak var delegate: MemberDataManagerDelegate?

	private let dataParser = AppDataParser()

	func validateMember(memberID: String, zipCode: String) {
		Alamofire
			.request(
				String(format: Common.DataConstants.memberCardRequestURL, memberID),
				method: .post,
				parameters: [
					"zip": zipCode
				],
				encoding: JSONEncoding.default,
				headers: [
					"Authorization": "Bearer \(Common.DataConstants.memberCardRequestBearerToken)"
				]
			)
			.responseData { [weak self] response in
				switch response.result {
				case .success:
					guard let data = response.data,
						let memberCard = self?.parse(response: data, zipCode: zipCode)
						else {
							self?.delegate?.memberCardDataLoadingFailed()
							return
						}

					self?.currentMemberCard = memberCard
					// Reset memberNameIndex if it's a new member ID
					if let savedMemberInfo = self?.getSavedMember() {
						if savedMemberInfo.memberID != memberCard.cardId {
							self?.currentMemberNameIndex = 0
						}
					}
					self?.saveCurrentMember()
					self?.delegate?.memberCardDidLoadForMember(memberCard: memberCard)
				case .failure:
					self?.delegate?.memberCardDataLoadingFailed()
				}
			}
	}

	private func parse(response: Data, zipCode: String) -> AICMemberCardModel? {
		do {
			let decoder = JSONDecoder()
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			decoder.dateDecodingStrategy = .iso8601

			let memberData = try decoder.decode(MemberCardResponse.self, from: response)

			var memberLevel = memberData.data.itemName
			var isReciprocal = false
			var isLifeMembership = false

			switch memberLevel {
			case "Life Membership":
				memberLevel = "Life Member"
				isLifeMembership = true
			case "Premium Member":
				isReciprocal = true
			case "Lionhearted Council":
				isReciprocal = true
			case "Lionhearted Roundtable":
				isReciprocal = true
			case "Lionhearted Circle":
				isReciprocal = true
			case "Sustaining Fellow Young":
				isReciprocal = true
			case "Sustaining Fellow":
				isReciprocal = true
			case "Sustaining Fellow Bronze":
				isReciprocal = true
			case "Sustaining Fellow Silver":
				isReciprocal = true
			case "Sustaining Fellow Sterling":
				isReciprocal = true
			case "Sustaining Fellow Gold":
				isReciprocal = true
			case "Sustaining Fellow Platinum":
				isReciprocal = true
			default:
				isReciprocal = false
			}

			return AICMemberCardModel(
				cardId: "\(memberData.data.id)",
				memberNames: memberData.data.members.map { "\($0.firstName) \($0.lastName)" },
				memberLevel: memberLevel,
				memberZip: zipCode,
				expirationDate: memberData.data.validUntil,
				isReciprocalMember: isReciprocal,
				isLifeMembership: isLifeMembership
			)
		} catch {
			delegate?.memberCardDataLoadingFailed()
			return nil
		}
	}

	func saveCurrentMember() {
		guard let memberCard = self.currentMemberCard else {
			return
		}

		let defaults = UserDefaults.standard

		var firstName: String = ""
		if currentMemberNameIndex < memberCard.memberNames.count {
			let fullName: String = memberCard.memberNames[currentMemberNameIndex]
			firstName = String(describing: fullName.split(separator: " ").first!)
		}

		// Store
		defaults.set(memberCard.cardId, forKey: Common.UserDefaults.memberInfoIDUserDefaultsKey)
		defaults.set(memberCard.memberZip, forKey: Common.UserDefaults.memberInfoZipUserDefaultsKey)
		defaults.set(firstName, forKey: Common.UserDefaults.memberFirstNameUserDefaultsKey)
		defaults.set(currentMemberNameIndex, forKey: Common.UserDefaults.memberInfoSelectedMemberDefaultsKey)

		defaults.synchronize()
	}

	func getSavedMember() -> AICMemberInfoModel? {
		let defaults = UserDefaults.standard

		let storedID = defaults.object(forKey: Common.UserDefaults.memberInfoIDUserDefaultsKey) as? String
		let storedZip = defaults.object(forKey: Common.UserDefaults.memberInfoZipUserDefaultsKey) as? String
		let storedMemberNameIndex = defaults.object(forKey: Common.UserDefaults.memberInfoSelectedMemberDefaultsKey) as? Int

		if storedID != nil && storedZip != nil && storedMemberNameIndex != nil {
			currentMemberNameIndex = storedMemberNameIndex!
			return AICMemberInfoModel(memberID: storedID!, memberZip: storedZip!)
		}

		return nil
	}
}
