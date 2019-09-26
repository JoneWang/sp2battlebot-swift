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

    // 已经启动自动战斗结果发送的对话
    // 其中保存了 message id 用于发送新战斗结果时删除上一次的结果消息
    var startedInChat = [Int64: Int?]()

    // battle 数据轮询队列
    let jobQueue: BasicJobQueue<DataContext>!
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

    init() {
        jobQueue = BasicJobQueue(bot: TGMessageManager.shared.bot)

        BotController.shared = self
    }

    private func startJobs() {
        // let interval = TimeAmount.seconds(5)
        // let battlePushLoop = RepeatableJob(when: Date(),
        //                                    interval: interval,
        //                                    context: message.chat) { chat in
        //     if let chat = chat {
        //         self.requestLastBattle(chat, requestLoop: true)
        //     }
        // }
    }

    func start(_ update: Update, _ context: BotContext!) throws {
        guard let dataContext = DataContext.from(update: update) else { return }

        let chatId = dataContext.chat.id
        if loop {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .alreadyStartedMessage)
            return
        }
        startedInChat[chatId] = nil

        _ = TGMessageManager.shared.send(context: dataContext,
                                         message: .startedMessage)

        loop = true

        let interval = TimeAmount.seconds(5)
        let battlePushLoop = RepeatableJob(when: Date(),
                                           interval: interval,
                                           context: dataContext) { c in
            self.requestLastBattle(c!, requestLoop: true)
        }

        _ = jobQueue.scheduleRepeated(battlePushLoop)
    }

    func stop(_ update: Update, _ context: BotContext!) throws {
        guard let dataContext = DataContext.from(update: update) else { return }
        stop(context: dataContext)
    }

    func last(_ update: Update, _ context: BotContext!) throws {
        guard let dataContext = DataContext.from(update: update) else { return }
        requestLastBattle(dataContext, battleIndex: 0)
    }

    func lastWithIndex(_ update: Update, _ context: BotContext!) throws {
        guard let messageText = update.message?.text else { return }
        guard let dataContext = DataContext.from(update: update) else { return }

        if dataContext.user.iksmSession == nil {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .lastCommandErrorMessage)
            return
        }

        let messageRange = NSRange(messageText.startIndex..<messageText.endIndex, in: messageText)

        let lastRegex = try NSRegularExpression(pattern: "^/last (0?[0-9]{1,2}|1[0-9]|49)$")
        let match = lastRegex.firstMatch(in: messageText, range: messageRange)
        if match == nil {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .lastCommandErrorMessage)
            return
        }

        let index = Int(String(messageText.split(separator: " ")[1]))!
        if index > 49 {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .lastCommandErrorMessage)
            return
        }

        requestLastBattle(dataContext, battleIndex: index)
    }

    func setIKSMSession(_ update: Update, _ context: BotContext!) throws {
        guard let messageText = update.message?.text else { return }
        guard var dataContext = DataContext.from(update: update) else { return }

        if dataContext.user.isBot {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .areYouHumanErrorMessage)
            return
        }

        if dataContext.chat.type != .private {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .setIKSMSessionCommandMustPrivateChatErrorMessage)
            return
        }

        guard let iksmRange = messageText.range(of: #"\b[a-z0-9]{40}$\b"#,
                                                options: .regularExpression) else {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .setIKSMSessionCommandErrorMessage,
                                             parseMode: .markdown)
            return
        }

        let iksmSession = String(messageText[iksmRange])
        do {
            if try UserDataHelper.find(id: dataContext.user.id) != nil {
                var user = dataContext.user
                user.iksmSession = iksmSession
                try UserDataHelper.update(user)
                _ = TGMessageManager.shared.send(context: dataContext,
                                                 message: .setIKSMSessionUpdateSuccessMessage)
            } else {
                dataContext.user.iksmSession = iksmSession
                try UserDataHelper.insert(dataContext.user)
                _ = TGMessageManager.shared.send(context: dataContext,
                                                 message: .setIKSMSessionAddSuccessMessage)
            }
        } catch {
            print(error)
        }
    }

    private func stop(context: DataContext) {
        let chatId = context.chat.id

        if !loop {
            _ = TGMessageManager.shared.send(context: context,
                                             message: .alreadyStoppedMessage)
            return
        }
        startedInChat.removeValue(forKey: chatId)
        loop = false
        firstGet = true

        if let notFinishedJob = jobQueue.jobs.first {
            notFinishedJob.scheduleRemoval()
        }

        _ = TGMessageManager.shared.send(context: context, message: .stoppedMessage)
    }

    private func sendBattleToChat(_ context: DataContext,
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

        try sendBattleMessage(context: context,
                              battleMessage: battleMessage,
                              requestLoop: requestLoop)

        if let messageId = self.startedMessageId(in: context.chat.id), requestLoop {
            startedInChat[context.chat.id] = nil
            _ = TGMessageManager.shared
                    .delete(context: context, messageId: messageId)
            return
        }
    }

    private func sendBattleMessage(context: DataContext,
                                   battleMessage: TGMessage,
                                   requestLoop: Bool) throws {
        _ = TGMessageManager.shared.send(context: context,
                                         message: battleMessage,
                                         parseMode: .markdown)
                .do { message in
                    let chatId = message.chat.id
                    if requestLoop {
                        self.startedInChat[chatId] = message.messageId
                    }
                }
    }

    private func sendAuthErrorMessage(_ context: DataContext) {
        if context.user.iksmSession == nil {
            _ = TGMessageManager.shared.send(context: context,
                                             message: .iksmSessionNotSetMessage,
                                             parseMode: .markdown)
        } else {
            _ = TGMessageManager.shared.send(context: context,
                                             message: .iksmSessionInvalidMessage,
                                             parseMode: .markdown)
        }

        if loop { stop(context: context) }
    }

}

extension BotController {
    private func requestLastBattle(_ context: DataContext,
                                   battleIndex: Int = 0,
                                   requestLoop: Bool = false,
                                   block: ((DataContext) -> Void)? = nil) {
        SP2API.battleList(context: context) { battles, code in
            if code == 200 {
                let lastBattle = battles[battleIndex]

                if !requestLoop ||
                           (!self.firstGet &&
                                   self.lastBattleId != "" &&
                                   lastBattle.battleId != self.lastBattleId) {
                    self.requestBattleDetail(context,
                                             battleId: lastBattle.battleId,
                                             requestLoop: requestLoop)
                } else {
                    self.firstGet = false
                }

                self.lastBattleId = lastBattle.battleId

                if let block = block {
                    block(context)
                }
            } else if code == 403 {
                self.sendAuthErrorMessage(context)
            }
        }
    }

    private func requestBattleDetail(_ context: DataContext,
                                     battleId: String,
                                     requestLoop: Bool,
                                     iksmSession: String? = nil) {
        SP2API.battle(context: context,
                      id: battleId) { battle, code in
            if code == 200, let battle = battle {
                if requestLoop {
                    self.gameCount += 1
                    if battle.victory {
                        self.gameVictoryCount += 1
                    }
                }

                do {
                    try self.sendBattleToChat(context,
                                              battle: battle,
                                              requestLoop: requestLoop)
                } catch {
                    print(error)
                }
            } else if code == 403 {
                self.sendAuthErrorMessage(context)
            }
        }
    }
}
