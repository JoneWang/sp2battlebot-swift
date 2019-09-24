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
        startedInChat[chatId] != nil
    }

    func startedMessageId(in chatId: Int64) -> Int? {
        guard let messageId = startedInChat[chatId] else {
            return nil
        }

        return messageId
    }

    init(botUser: Telegrammer.User, onlineSession: String) {
        self.botUser = botUser
        self.onlineSession = onlineSession

        BotController.shared = self
    }

    func start(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        if loop {
            _ = TGMessageManager.shared.send(chatId: chatId,
                                             snippet: .alreadyStartedMessage(botUser: botUser))
            return
        }
        startedInChat[chatId] = nil

        _ = TGMessageManager.shared.send(chatId: chatId,
                                         snippet: .startedMessage(botUser: botUser))

        loop = true
        startLastBattleRequestLoop(update)
    }

    func stop(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        if !loop {
            _ = TGMessageManager.shared.send(chatId: chatId,
                                             snippet: .alreadyStoppedMessage(botUser: botUser))
            return
        }
        startedInChat.removeValue(forKey: chatId)
        loop = false
        firstGet = true

        _ = TGMessageManager.shared.send(chatId: chatId, snippet: .stoppedMessage(botUser: botUser))
    }

    func last(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        requestLastBattle(update, battleIndex: 0, block: nil)
    }

    func lastWithIndex(_ update: Telegrammer.Update, _ context: BotContext!) throws {
        guard let messageText = update.message?.text else { return }
        guard let chatId = update.message?.chat.id else { return }

        let messageRange = NSRange(messageText.startIndex..<messageText.endIndex, in: messageText)

        let lastRegex = try NSRegularExpression(pattern: "^/last (0?[0-9]{1,2}|1[0-9]|49)$")
        let match = lastRegex.firstMatch(in: messageText, range: messageRange)
        if match == nil {
            _ = TGMessageManager.shared.send(chatId: chatId,
                                             snippet: .lastCommandErrorMessage)
            return
        }

        let index = Int(String(messageText.split(separator: " ")[1]))!
        if index > 49 {
            _ = TGMessageManager.shared.send(chatId: chatId,
                                             snippet: .lastCommandErrorMessage)
            return
        }

        requestLastBattle(update, battleIndex: index, block: nil)
    }

    func setCookie(_ update: Telegrammer.Update, _ context: BotContext!) throws {
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
        guard let chatId = update.message?.chat.id else { return }

        var battleMessage: TGMessage
        if requestLoop {
            battleMessage = .pushBattleMessage(victoryGames: gameVictoryCount,
                                               allGames: gameCount,
                                               battle: battle)
        } else {
            battleMessage = .lastBattleMessage(battle: battle)
        }

        if let messageId = self.startedMessageId(in: chatId), requestLoop {
            startedInChat[chatId] = nil
            _ = TGMessageManager.shared
                    .delete(chatId: chatId, messageId: messageId)
                    .do { success in
                        if success {
                            try! self.sendBattleMessage(chatId: chatId,
                                                        battleMessage: battleMessage,
                                                        requestLoop: requestLoop)
                        }
                    }
            return
        }

        try sendBattleMessage(chatId: chatId,
                              battleMessage: battleMessage,
                              requestLoop: requestLoop)
    }

    private func sendBattleMessage(chatId: Int64,
                                   battleMessage: TGMessage,
                                   requestLoop: Bool) throws {
        _ = TGMessageManager.shared
                .send(chatId: chatId,
                      snippet: battleMessage,
                      parseMode: .markdown)
                .do { message in
                    let chatId = message.chat.id
                    if requestLoop {
                        self.startedInChat[chatId] = message.messageId
                    }
                }
    }

    private func sendAuthErrorMessage(_ update: Telegrammer.Update) {
        guard let message = update.message else { return }
        let chatId = message.chat.id

        _ = TGMessageManager.shared.send(chatId: chatId,
                                         snippet: .cookieInvalidMessage)

        if loop { try! stop(update, nil) }
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
