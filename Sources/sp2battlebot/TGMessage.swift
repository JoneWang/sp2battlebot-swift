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
    case startedMessage
    case stoppedMessage
    case alreadyStartedMessage
    case alreadyStoppedMessage
    case iksmSessionInvalidMessage
    case iksmSessionNotSetMessage
    case setIKSMSessionCommandMustPrivateChatErrorMessage
    case setIKSMSessionCommandErrorMessage
    case setIKSMSessionUpdateSuccessMessage
    case setIKSMSessionAddSuccessMessage
    case areYouHumanErrorMessage
}

extension TGMessage {

    static func selector(context: DataContext, message: TGMessage) -> String {
        switch message {
        case .pushBattleMessage(let victoryGames, let allGames, let battle):
            return pushBattleMessage(context, victoryGames: victoryGames, allGames: allGames, battle: battle)
        case .lastBattleMessage(let battle):
            return lastBattleMessage(context, battle: battle)
        case .lastCommandErrorMessage:
            return lastCommandErrorMessage(context)
        case .startedMessage:
            return startedMessage(context)
        case .stoppedMessage:
            return stoppedMessage(context)
        case .alreadyStartedMessage:
            return alreadyStartedMessage(context)
        case .alreadyStoppedMessage:
            return alreadyStoppedMessage(context)
        case .iksmSessionInvalidMessage:
            return iksmSessionInvalidMessage(context)
        case .iksmSessionNotSetMessage:
            return iksmSessionNotSetMessage(context)
        case .setIKSMSessionCommandMustPrivateChatErrorMessage:
            return setIKSMSessionCommandMustPrivateChatErrorMessage(context)
        case .setIKSMSessionCommandErrorMessage:
            return setIKSMSessionCommandErrorMessage(context)
        case .setIKSMSessionUpdateSuccessMessage:
            return setIKSMSessionUpdateSuccessMessage(context)
        case .setIKSMSessionAddSuccessMessage:
            return setIKSMSessionAddSuccessMessage(context)
        case .areYouHumanErrorMessage:
            return areYouHumanErrorMessage(context)
        }
    }

    static func pushBattleMessage(_ context: DataContext, victoryGames: Int, allGames: Int, battle: SP2Battle) -> String {
        var lines = [String]()

        if battle.victory {
            lines.append("我们赢啦！")
        } else {
            lines.append("呜呜呜~输了不好意思见人了~")
        }

        lines.append(String(format: "`当前胜率%.0f%%  胜%d  负%d`",
                            Double(victoryGames) / Double(allGames) * 100,
                            victoryGames,
                            allGames - victoryGames))

        lines.append(battleTeamTitle(myTeam: true, battle: battle))
        lines.append(battlePlayerResult(results: battle.myTeamPlayerResults!))

        lines.append(battleTeamTitle(myTeam: false, battle: battle))
        lines.append(battlePlayerResult(results: battle.otherTeamPlayerResults!))

        return lines.joined(separator: "\n")
    }

    static func lastBattleMessage(_ context: DataContext, battle: SP2Battle) -> String {
        var lines = [String]()

        let result = battle.victory ? "VICTORY" : "DEFEAT"
        lines.append("当前查询的战斗 \(result) ID\(battle.battleId)")

        lines.append(battleTeamTitle(myTeam: true, battle: battle))
        lines.append(battlePlayerResult(results: battle.myTeamPlayerResults!))

        lines.append(battleTeamTitle(myTeam: false, battle: battle))
        lines.append(battlePlayerResult(results: battle.otherTeamPlayerResults!))

        return lines.joined(separator: "\n")
    }

    static func lastCommandErrorMessage(_ context: DataContext) -> String {
        "Command error.\nType /last [0~49] ."
    }

    static func startedMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "@\(botUsername) started.\n To stop, type /stop"
    }

    static func stoppedMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "@\(botUsername) stopped.\n To restart, type /start"
    }

    static func alreadyStartedMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "@\(botUsername) already started."
    }

    static func alreadyStoppedMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "@\(botUsername) already stopped."
    }

    static func iksmSessionInvalidMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "The `iksm_session` invalid.\nTo reset, send /setiksm `[iksm_session]` to @\(botUsername)."
    }

    static func iksmSessionNotSetMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "Your `iksm_session` not set.\nTo set, send /setiksm `[iksm_session]` to @\(botUsername)."
    }

    static func setIKSMSessionCommandMustPrivateChatErrorMessage(_ context: DataContext) -> String {
        let botUsername = TGMessageManager.shared.botUser.username!
        return "Command /setiksm must send to @\(botUsername)."
    }

    static func setIKSMSessionCommandErrorMessage(_ context: DataContext) -> String {
        "Type error.\nPlease type /setiksm `[iksm_session]`.\nIf you don't know `iksm_session`, to do balabala."
    }

    static func setIKSMSessionUpdateSuccessMessage(_ context: DataContext) -> String {
        "Success! You set a new iksm_session."
    }

    static func setIKSMSessionAddSuccessMessage(_ context: DataContext) -> String {
        "Oh~ Nice to meet you.\nNow you'll know me with /help."
    }

    static func areYouHumanErrorMessage(_ context: DataContext) -> String {
        "Are you human? keke~"
    }
}

extension TGMessage {
    private static func battleTeamTitle(myTeam: Bool, battle: SP2Battle) -> String {
        let teamName = myTeam ? "我方" : "对方"

        var point: String
        switch battle.type {
        case .regular:
            point = (myTeam ?
                    battle.myTeamPercentage : battle.otherTeamPercentage)?
                    .format(" (%.1f)") ?? ""
        case .ranked:
            point = " "
        case .league:
            point = (myTeam ?
                    battle.myEstimateLeaguePoint : battle.otherEstimateLeaguePoint)?
                    .format(" (%d)") ?? ""
        }

        return "\(teamName) \(battle.type)\(point)："
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
