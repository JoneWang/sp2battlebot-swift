//
//  SP2Model.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation

struct SP2BattleList: Decodable {
    var battles: [SP2Battle]

    enum CodingKeys: String, CodingKey {
        case battles = "results"
    }
}

struct SP2Battle: Decodable {

    enum BattleType: String, Codable {
        case league
        case regular
        case ranked = "gachi"
    }

    var battleId: String
    var type: BattleType
    var victory: Bool
    var myTeamPlayerResults: [SP2BattlePlayerResult]?
    var otherTeamPlayerResults: [SP2BattlePlayerResult]?
    var selfPlayerResult: SP2BattlePlayerResult
    var myEstimateLeaguePoint: Int?
    var otherEstimateLeaguePoint: Int?
    var myTeamPercentage: Double?
    var otherTeamPercentage: Double?
    var myTeamCount: Int?
    var otherTeamCount: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case myTeamResult = "my_team_result"
        case battleId = "battle_number"
        case myTeamPlayerResults = "my_team_members"
        case otherTeamPlayerResults = "other_team_members"
        case selfPlayerResult = "player_result"
        case myEstimateLeaguePoint = "my_estimate_league_point"
        case otherEstimateLeaguePoint = "other_estimate_league_point"
        case myTeamPercentage = "my_team_percentage"
        case otherTeamPercentage = "other_team_percentage"
        case myTeamCount = "my_team_count"
        case otherTeamCount = "other_team_count"
    }

    enum MyTeamResultCodingKeys: String, CodingKey {
        case key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        battleId = try container.decode(String.self, forKey: .battleId)
        let typeString = try container.decode(String.self, forKey: .type)
        type = BattleType(rawValue: typeString)!

        let myTeamResultContainer = try container.nestedContainer(keyedBy: MyTeamResultCodingKeys.self, forKey: .myTeamResult)
        victory = try myTeamResultContainer.decode(String.self, forKey: .key) == "victory"

        myTeamPlayerResults = try container.decodeIfPresent([SP2BattlePlayerResult].self, forKey: .myTeamPlayerResults)
        otherTeamPlayerResults = try container.decodeIfPresent([SP2BattlePlayerResult].self, forKey: .otherTeamPlayerResults)
        selfPlayerResult = try container.decode(SP2BattlePlayerResult.self, forKey: .selfPlayerResult)
        myEstimateLeaguePoint = try container.decodeIfPresent(Int.self, forKey: .myEstimateLeaguePoint)
        otherEstimateLeaguePoint = try container.decodeIfPresent(Int.self, forKey: .otherEstimateLeaguePoint)
        myTeamPercentage = try container.decodeIfPresent(Double.self, forKey: .myTeamPercentage)
        otherTeamPercentage = try container.decodeIfPresent(Double.self, forKey: .otherTeamPercentage)
        myTeamCount = try container.decodeIfPresent(Int.self, forKey: .myTeamCount)
        otherTeamCount = try container.decodeIfPresent(Int.self, forKey: .otherTeamCount)

        myTeamPlayerResults?.append(selfPlayerResult)
    }
}

struct SP2BattlePlayerResult: Decodable {
    var killCount: Int
    var assistCount: Int
    var deathCount: Int
    var specialCount: Int
    var player: SP2Player

    enum CodingKeys: String, CodingKey {
        case killCount = "kill_count"
        case assistCount = "assist_count"
        case deathCount = "death_count"
        case specialCount = "special_count"
        case player
    }
}

struct SP2Player: Decodable {
    var nickname: String
}
