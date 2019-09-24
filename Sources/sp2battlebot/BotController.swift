//
//  BotController.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation
import NIO
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

    // battle 数据轮询队列
    let jobQueue: BasicJobQueue<Chat>!
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

    init(botUser: User, onlineSession: String) {
        self.botUser = botUser
        self.onlineSession = onlineSession

        jobQueue = BasicJobQueue(bot: TGMessageManager.shared.bot)

        BotController.shared = self
    }

    func start(_ update: Update, _ context: BotContext!) throws {
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

        let interval = TimeAmount.seconds(5)
        let battlePushLoop = RepeatableJob(when: Date(),
                                           interval: interval,
                                           context: message.chat) { chat in
            if let chat = chat {
                self.requestLastBattle(chat, requestLoop: true)
            }
        }

        _ = jobQueue.scheduleRepeated(battlePushLoop)
    }

    func stop(_ update: Update, _ context: BotContext!) throws {
        guard let chat = update.message?.chat else { return }
        stop(chat: chat)
    }

    func last(_ update: Update, _ context: BotContext!) throws {
        guard let chat = update.message?.chat else { return }
        requestLastBattle(chat, battleIndex: 0, block: nil)
    }

    func lastWithIndex(_ update: Update, _ context: BotContext!) throws {
        guard let messageText = update.message?.text else { return }
        guard let chat = update.message?.chat else { return }

        let messageRange = NSRange(messageText.startIndex..<messageText.endIndex, in: messageText)

        let lastRegex = try NSRegularExpression(pattern: "^/last (0?[0-9]{1,2}|1[0-9]|49)$")
        let match = lastRegex.firstMatch(in: messageText, range: messageRange)
        if match == nil {
            _ = TGMessageManager.shared.send(chatId: chat.id,
                                             snippet: .lastCommandErrorMessage)
            return
        }

        let index = Int(String(messageText.split(separator: " ")[1]))!
        if index > 49 {
            _ = TGMessageManager.shared.send(chatId: chat.id,
                                             snippet: .lastCommandErrorMessage)
            return
        }

        requestLastBattle(chat, battleIndex: index, block: nil)
    }

    func setCookie(_ update: Update, _ context: BotContext!) throws {
        // TODO: Set cookie
    }

    private func stop(chat: Chat) {
        if !loop {
            _ = TGMessageManager.shared.send(chatId: chat.id,
                                             snippet: .alreadyStoppedMessage(botUser: botUser))
            return
        }
        startedInChat.removeValue(forKey: chat.id)
        loop = false
        firstGet = true

        if let notFinishedJob = jobQueue.jobs.first {
            notFinishedJob.scheduleRemoval()
        }

        _ = TGMessageManager.shared.send(chatId: chat.id, snippet: .stoppedMessage(botUser: botUser))
    }

    private func sendBattleToChat(_ chat: Chat,
                                  battle: SP2Battle,
                                  requestLoop: Bool) throws {
        var battleMessage: TGMessage
        if requestLoop {
            battleMessage = .pushBattleMessage(victoryGames: gameVictoryCount,
                                               allGames: gameCount,
                                               battle: battle)
        } else {
            battleMessage = .lastBattleMessage(battle: battle)
        }

        try sendBattleMessage(chatId: chat.id,
                              battleMessage: battleMessage,
                              requestLoop: requestLoop)

        if let messageId = self.startedMessageId(in: chat.id), requestLoop {
            startedInChat[chat.id] = nil
            _ = TGMessageManager.shared
                    .delete(chatId: chat.id, messageId: messageId)
            return
        }
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

    private func sendAuthErrorMessage(_ chat: Chat) {
        _ = TGMessageManager.shared.send(chatId: chat.id,
                                         snippet: .cookieInvalidMessage)

        if loop { stop(chat: chat) }
    }
}

extension BotController {
    private func requestLastBattle(_ chat: Chat,
                                   battleIndex: Int = 0,
                                   requestLoop: Bool = false,
                                   block: ((Chat) -> Void)? = nil) {
        SP2API2.battleList { battles, code in
            if code == 200 {
                let lastBattle = battles[battleIndex]

                if !requestLoop ||
                           (!self.firstGet &&
                                   self.lastBattleId != "" &&
                                   lastBattle.battleId != self.lastBattleId) {
                    self.requestBattleDetail(chat,
                                             battleId: lastBattle.battleId,
                                             requestLoop: requestLoop)
                } else {
                    self.firstGet = false
                }

                self.lastBattleId = lastBattle.battleId

                if let block = block {
                    block(chat)
                }
            } else if code == 403 {
                self.sendAuthErrorMessage(chat)
            }
        }
    }

    private func requestBattleDetail(_ chat: Chat,
                                     battleId: String,
                                     requestLoop: Bool) {
        SP2API2.battle(id: battleId) { battle, code in
            if code == 200 {
                if requestLoop {
                    self.gameCount += 1
                    if battle.victory {
                        self.gameVictoryCount += 1
                    }
                }

                do {
                    try self.sendBattleToChat(chat,
                                              battle: battle,
                                              requestLoop: requestLoop)
                } catch {
                    print(error)
                }
            } else if code == 403 {
                self.sendAuthErrorMessage(chat)
            }
        }
    }
}
