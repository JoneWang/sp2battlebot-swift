//
//  SP2Message.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation
import Telegrammer

enum TGMessage {
    case pushBattleMessage(victoryGames: Int, allGames: Int, battle: SP2Battle)
    case lastBattleMessage(battle: SP2Battle)
    case lastCommandErrorMessage
    case startedMessage(botUser: User)
    case stoppedMessage(botUser: User)
    case alreadyStartedMessage(botUser: User)
    case alreadyStoppedMessage(botUser: User)
    case cookieInvalidMessage
}

extension TGMessage {

    static func selector(_ s: TGMessage) -> String {
        switch s {
        case .pushBattleMessage(let victoryGames, let allGames, let battle):
            return pushBattleMessage(victoryGames: victoryGames, allGames: allGames, battle: battle)
        case .lastBattleMessage(let battle):
            return lastBattleMessage(battle: battle)
        case .lastCommandErrorMessage:
            return lastCommandErrorMessage()
        case .startedMessage(let botUser):
            return startedMessage(botUser: botUser)
        case .stoppedMessage(let botUser):
            return stoppedMessage(botUser: botUser)
        case .alreadyStartedMessage(let botUser):
            return alreadyStartedMessage(botUser: botUser)
        case .alreadyStoppedMessage(let botUser):
            return alreadyStoppedMessage(botUser: botUser)
        case .cookieInvalidMessage:
            return cookieInvalidMessage()
        }
    }

    static func pushBattleMessage(victoryGames: Int, allGames: Int, battle: SP2Battle) -> String {
        var lines = [String]()

        if battle.victory {
            lines.append("我们赢啦！")
        } else {
            lines.append("呜呜呜~输了不好意思见人了~")
        }

        lines.append(String(format: "`当前胜率 %.0f%%  胜 %d  负 %d`",
                            Double(victoryGames) / Double(allGames) * 100,
                            victoryGames,
                            allGames - victoryGames))

        lines.append(battleTeamTitle(myTeam: true, battle: battle))
        lines.append(battlePlayerResult(results: battle.myTeamPlayerResults!))

        lines.append(battleTeamTitle(myTeam: false, battle: battle))
        lines.append(battlePlayerResult(results: battle.otherTeamPlayerResults!))

        return lines.joined(separator: "\n")
    }

    static func lastBattleMessage(battle: SP2Battle) -> String {
        var lines = [String]()

        let result = battle.victory ? "VICTORY" : "DEFEAT"
        lines.append("当前查询的战斗 \(result) ID\(battle.battleId)")

        lines.append(battleTeamTitle(myTeam: true, battle: battle))
        lines.append(battlePlayerResult(results: battle.myTeamPlayerResults!))

        lines.append(battleTeamTitle(myTeam: false, battle: battle))
        lines.append(battlePlayerResult(results: battle.otherTeamPlayerResults!))

        return lines.joined(separator: "\n")
    }

    static func lastCommandErrorMessage() -> String {
        "Command error.\nType /last [0~49] ."
    }

    static func startedMessage(botUser: User) -> String {
        "@\(botUser.username!) started.\n To stop, type /stop"
    }

    static func stoppedMessage(botUser: User) -> String {
        "@\(botUser.username!) stopped.\n To restart, type /start"
    }

    static func alreadyStartedMessage(botUser: User) -> String {
        "@\(botUser.username!) already started."
    }

    static func alreadyStoppedMessage(botUser: User) -> String {
        "@\(botUser.username!) already stopped."
    }

    static func cookieInvalidMessage() -> String {
        "Cookie invalid.\nTo reset, type /setcookie ."
    }
}

extension TGMessage {
    private static func battleTeamTitle(myTeam: Bool, battle: SP2Battle) -> String {
        let teamName = myTeam ? "我方" : "对方"

        var point = ""
        switch battle.type {
        case .regular:
            point = [battle.myTeamPercentage,
                     battle.otherTeamPercentage][myTeam.intValue]?
                    .format("(%.1f)") ?? ""
        case .ranked:
            point = ""
        case .league:
            point = [battle.myEstimateLeaguePoint,
                     battle.otherEstimateLeaguePoint][myTeam.intValue]?
                    .format("(%d)") ?? ""
        }

        return "\(teamName) \(battle.type) \(point)："
    }

    private static func battlePlayerResult(results: [SP2BattlePlayerResult]) -> String {
        results.map { result -> String in
                    let nickname = String(result.player.nickname.prefix(9))

                    let formatLine = "*▸*`%2d(%d)k` `%2dd %dsp` `\(nickname)`"
                    return String(format: formatLine,
                                  result.killCount + result.assistCount,
                                  result.assistCount,
                                  result.deathCount,
                                  result.specialCount)
                }
                .joined(separator: "\n")
    }
}
