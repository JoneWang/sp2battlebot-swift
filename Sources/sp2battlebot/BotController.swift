//
//  BotController.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation
import Telegrammer

enum BotControllerError: Error {
    case NotFoundChatId
    case NotFoundMessageId
}

class BotController {
    static var shared: BotController!

    let bot: Bot
    let botUser: Telegrammer.User

    // 已经启动自动战斗结果发送的对话
    // 其中保存了 message id 用于发送新战斗结果时删除上一次的结果消息
    var startedInChat = [Int64: Int?]()

    // Switch Online API headers
    var onlineSession: String

    // 保存50个 last 命令
    var lastFuncs = [(update: Telegrammer.Update) -> Bool]()
    // 用于控制获取 battle 数据轮询
    var loop = false
    // 用于 /start 时，获取一次 lastBattleNumber 而不输出
    var firstGet = true
    // 用于比较 battleNumber，如果和上次不同则认为产生了新的 battle 数据并且发送到 tg
    var lastBattleId = ""

    var gameCount = 0
    var gameVictoryCount = 0

    func started(in chatId: Int64) -> Bool {
        return startedInChat[chatId] != nil
    }

    func startedMessageId(in chatId: Int64) -> Int? {
        guard let messageId = startedInChat[chatId] else {
            return nil
        }

        return messageId
    }

    init(bot: Bot, botUser: Telegrammer.User, onlineSession: String) {
        self.bot = bot
        self.botUser = botUser
        self.onlineSession = onlineSession

        BotController.shared = self
    }

    func start(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        guard !started(in: chatId) else {
            let params = Bot.SendMessageParams(chatId: .chat(chatId), text: "@\(botUser.username!) already started.")
            try bot.sendMessage(params: params)
            return
        }
        startedInChat[chatId] = nil

        var startText: String
        startText = "@\(botUser.username!) started.\n"
        startText += "To stop, type /stop"

        let params = Bot.SendMessageParams(chatId: .chat(chatId), text: startText)
        try bot.sendMessage(params: params)

        loop = true
        startLastBattleRequestLoop(update)
    }

    func stop(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        guard started(in: chatId) else {
            let params = Bot.SendMessageParams(chatId: .chat(chatId),
                                               text: "@\(botUser.username!) already stopped.")
            _ = try bot.sendMessage(params: params)
            return
        }
        startedInChat.removeValue(forKey: chatId)
        loop = false
        firstGet = true

        let params = Bot.SendMessageParams(chatId: .chat(chatId),
                                           text: "@\(botUser.username!) stopped. To restart, type /start")
        _ = try bot.sendMessage(params: params)
    }

    func last(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        requestLastBattle(update, battleIndex: 0, block: nil)
    }

    func lastWithIndex(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let messageText = update.message?.text else {
            return
        }

        let lastPredicate = NSPredicate(format: "SELF MATCHES '^/last (0?[0-9]{1,2}|1[0-9]|49)$'")
        if !lastPredicate.evaluate(with: messageText) {
            sendLastCommandErrorMessage(update)
            return
        }

        let index = Int(String(messageText.split(separator: " ")[1]))!
        if index > 49 {
            sendLastCommandErrorMessage(update)
            return
        }
        
        requestLastBattle(update, battleIndex: index, block: nil)
    }

    func setCookie(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        let params = Bot.SendMessageParams(chatId: .chat(chatId),
                                           text: "@\(botUser.username!) stopped. To restart, type /start")
        _ = try bot.sendMessage(params: params)

        // TODO: Set cookie
    }

    private func startLastBattleRequestLoop(_ update: Telegrammer.Update) {
        requestLastBattle(update, requestLoop: true) { update in
            if self.loop {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.startLastBattleRequestLoop(update)
                }
            }
        }
    }

    private func sendBattleToTG(_ update: Telegrammer.Update,
                                battle: SP2Battle,
                                requestLoop: Bool) throws {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        var myTeamResults = battle.myTeamPlayerResults!
        // 将自己的结果添加到成员中
        myTeamResults.append(battle.selfPlayerResult)

        let otherTeamResults = battle.otherTeamPlayerResults!

        let battleMessage = TGSP2Message()

        if requestLoop {
            if battle.victory {
                gameVictoryCount += 1
                battleMessage.append(content: "我们赢啦！")
            } else {
                battleMessage.append(content: "呜呜呜~输了不好意思见人了~")
            }

            battleMessage.append(content:
                                 String(format: "`当前胜率-%.0f%% 胜-%d 负-%d`",
                                        Double(gameVictoryCount) / Double(gameCount) * 100,
                                        gameVictoryCount,
                                        gameCount - gameVictoryCount))
        } else {
            let result = battle.victory ? "VICTORY" : "DEFEAT"
            battleMessage.append(content:
                                 String(format: "当前查询的战斗 \(result) ID%d",
                                        battle.battleId))
        }

        let generateMessageRows: ([SP2BattlePlayerResult]) -> [TGSP2MessageMemberRow] = { results in
            results.map { result -> TGSP2MessageMemberRow in
                TGSP2MessageMemberRow(kill: result.killCount,
                                      assist: result.assistCount,
                                      death: result.deathCount,
                                      special: result.specialCount,
                                      nickname: result.player.nickname)
            }
        }

        if battle.type == .regular {
            battleMessage.append(content: String(format: "我方 \(battle.type) (%.1f)：", battle.myTeamPercentage!))
            battleMessage.append(rowsOf: generateMessageRows(myTeamResults))
            battleMessage.append(content: String(format: "对方 \(battle.type) (%.1f)：", battle.otherTeamPercentage!))
            battleMessage.append(rowsOf: generateMessageRows(otherTeamResults))
        } else if battle.type == .ranked {
            battleMessage.append(content: "我方：")
            battleMessage.append(rowsOf: generateMessageRows(myTeamResults))
            battleMessage.append(content: "对方：")
            battleMessage.append(rowsOf: generateMessageRows(otherTeamResults))
        } else if battle.type == .league {
            battleMessage.append(content: String(format: "我方 \(battle.type) (%d)：", battle.myEstimateLeaguePoint!))
            battleMessage.append(rowsOf: generateMessageRows(myTeamResults))
            battleMessage.append(content: String(format: "对方 \(battle.type) (%d)：", battle.otherEstimateLeaguePoint!))
            battleMessage.append(rowsOf: generateMessageRows(otherTeamResults))
        }

        if let messageId = self.startedMessageId(in: chatId), requestLoop {
            startedInChat[chatId] = nil
            let params = Bot.DeleteMessageParams(chatId: .chat(chatId), messageId: messageId)
            _ = try bot.deleteMessage(params: params).do { success in
                if success {
                    try! self.sendBattleMessage(chatId: .chat(chatId),
                                                battleMessage: battleMessage,
                                                requestLoop: requestLoop)
                }
            }
            return
        }

        try sendBattleMessage(chatId: .chat(chatId),
                              battleMessage: battleMessage,
                              requestLoop: requestLoop)
    }

    private func sendBattleMessage(chatId: Telegrammer.ChatId,
                                   battleMessage: TGSP2Message,
                                   requestLoop: Bool) throws {
        print(battleMessage.text)
        let params = Bot.SendMessageParams(chatId: chatId,
                                           text: battleMessage.text,
                                           parseMode: .markdown)
        _ = try bot.sendMessage(params: params).do { message in
            let chatId = message.chat.id
            if requestLoop {
                self.startedInChat[chatId] = message.messageId
            }
        }
    }

    private func sendAuthErrorMessage(_ update: Telegrammer.Update) {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        let params = Bot.SendMessageParams(chatId: .chat(chatId),
                                           text: "Cookie invalid.\nTo reset, type /setcookie .",
                                           parseMode: .markdown)
        _ = try! bot.sendMessage(params: params)

        if loop { try! stop(update, nil) }
    }

    private func sendLastCommandErrorMessage(_ update: Telegrammer.Update) {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        let params = Bot.SendMessageParams(chatId: .chat(chatId),
                                           text: "Command error.\nType /last [0~49] .",
                                           parseMode: .markdown)
        _ = try! bot.sendMessage(params: params)
    }
}

extension BotController {
    private func requestLastBattle(_ update: Telegrammer.Update,
                                   battleIndex: Int = 0,
                                   requestLoop: Bool = false,
                                   block: ((Telegrammer.Update) -> Void)?) {
        SP2API2.battleList { battles, code in
            if code == 200 {
                let lastBattle = battles[battleIndex]

                if block == nil || (
                        !self.firstGet &&
                        self.lastBattleId != "" &&
                        lastBattle.battleId != self.lastBattleId) {
                    self.requestBattleDetail(update,
                                             battleId: lastBattle.battleId,
                                             requestLoop: requestLoop)
                } else {
                    self.firstGet = false
                }

                self.lastBattleId = lastBattle.battleId

                if let block = block {
                    block(update)
                }
            } else if code == 403 {
                self.sendAuthErrorMessage(update)
            }
        }
    }

    private func requestBattleDetail(_ update: Telegrammer.Update,
                                     battleId: String,
                                     requestLoop: Bool) {
        SP2API2.battle(id: battleId) { battle, code in
            if code == 200 {
                if requestLoop {
                    self.gameCount += 1
                }
                do {
                    try self.sendBattleToTG(update,
                                            battle: battle,
                                            requestLoop: requestLoop)
                } catch {
                    print(error)
                }
            } else if code == 403 {
                self.sendAuthErrorMessage(update)
            }
        }
    }
}
