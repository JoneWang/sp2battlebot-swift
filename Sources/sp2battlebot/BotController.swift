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

    // battle 数据轮询队列
    let jobQueue: BasicJobQueue<DataContext>!
    // 轮询 loop 信息
    var loops = [LoopInfo]()

    init() {
        jobQueue = BasicJobQueue(bot: TGMessageManager.shared.bot)

        BotController.shared = self
    }

    func startPush(_ update: Update, _ context: BotContext!) throws {
        guard let dataContext = DataContext.from(update: update) else { return }

        let chatId = dataContext.chat.id
        let userId = dataContext.user.id

        if loops.contains(where: {
            $0.userId == userId && $0.chats.keys.contains(chatId)
        }) {
            _ = TGMessageManager.shared.send(context: dataContext,
                                             message: .alreadyStartedMessage)
            return
        }

        var loopIndex: Int!
        loopIndex = loops.firstIndex { $0.userId == userId }
        if loopIndex == nil {
            let loopInfo = LoopInfo(chats: [Int64: Int?](), userId: userId)
            loops.append(loopInfo)
            loopIndex = loops.count - 1
        }

        var loopInfo = loops[loopIndex]
        loopInfo.chats.updateValue(nil, forKey: chatId)
        loops[loopIndex] = loopInfo

        _ = TGMessageManager.shared.send(context: dataContext,
                                         message: .startedMessage)

        let interval = TimeAmount.seconds(5)
        let battlePushLoop = RepeatableJob(when: Date(),
                                           interval: interval,
                                           context: dataContext) { c in
            var context = c!
            context.loop = true
            self.requestLastBattle(context)
        }

        _ = jobQueue.scheduleRepeated(battlePushLoop)
    }

    func stopPush(_ update: Update, _ context: BotContext!) throws {
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

    func last50(_ update: Update, _ context: BotContext!) throws {
        guard let dataContext = DataContext.from(update: update) else { return }

        SP2API.battleList(context: dataContext) { battleOverview, code in
            if code == 200, let battleOverview = battleOverview {
                _ = TGMessageManager.shared.send(context: dataContext,
                                                 message: .last50OverviewMessage(battleOverview: battleOverview),
                                                 parseMode: .markdown)
            } else if code == 403 {
                self.sendAuthErrorMessage(dataContext)
            }
        }
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
        let userId = context.user.id

        guard let loopIndex = loops.firstIndex(where: {
            $0.userId == userId && $0.chats.keys.contains(chatId)
        }), let currentLoop = jobQueue.jobs.first(where: {
            $0.context?.user.id == userId
        }) else {
            _ = TGMessageManager.shared.send(context: context,
                                             message: .alreadyStoppedMessage)
            return
        }

        var loopInfo = loops[loopIndex]
        loopInfo.chats.removeValue(forKey: chatId)
        loops[loopIndex] = loopInfo

        if loopInfo.chats.count == 0 {
            currentLoop.scheduleRemoval()
            jobQueue.jobs.remove(currentLoop)
        }

        _ = TGMessageManager.shared.send(context: context, message: .stoppedMessage)
    }

    private func sendBattleToUserChat(_ context: DataContext, battle: SP2Battle) throws {
        _ = TGMessageManager.shared.send(context: context,
                                         message: .lastBattleMessage(battle: battle),
                                         chatId: context.chat.id,
                                         parseMode: .markdown)
    }

    private func sendBattleToUserChats(_ context: DataContext, battle: SP2Battle) throws {
        let userId = context.user.id

        guard let loopInfo = loops.first(where: { $0.userId == userId }) else {
            return
        }

        for chatId in loopInfo.chats.keys {
            // Send
            _ = TGMessageManager.shared.send(context: context,
                                             message: .pushBattleMessage(victoryGames: loopInfo.gameVictoryCount,
                                                                         allGames: loopInfo.gameCount,
                                                                         battle: battle),
                                             chatId: chatId,
                                             parseMode: .markdown)
                    .do { message in
                        let chatId = message.chat.id
                        if let loopIndex = self.loops.firstIndex(where: { $0.userId == userId }), context.loop {
                            var loopInfo = self.loops[loopIndex]
                            loopInfo.chats.updateValue(message.messageId, forKey: chatId)
                            self.loops[loopIndex] = loopInfo
                        }
                    }

            // Delete last push message
            if let lastPushMsgId = loopInfo.chats[chatId] as? Int, context.loop {
                _ = TGMessageManager.shared
                        .delete(context: context, messageId: lastPushMsgId, chatId: chatId)
            }
        }
    }

    private func sendBattleMessage(context: DataContext, battleMessage: TGMessage, chatId: Int64? = nil) throws {
        _ = TGMessageManager.shared.send(context: context,
                                         message: battleMessage,
                                         chatId: chatId,
                                         parseMode: .markdown)
                .do { message in
                    let userId = message.chat.id
                    let chatId = message.chat.id
                    if let loopIndex = self.loops.firstIndex(where: { $0.userId == userId }), context.loop {
                        var loopInfo = self.loops[loopIndex]
                        loopInfo.chats.updateValue(message.messageId, forKey: chatId)
                        self.loops[loopIndex] = loopInfo
                    }
                }
    }

    private func sendAuthErrorMessage(_ context: DataContext) {
        let chatId = context.chat.id
        let userId = context.user.id

        if context.user.iksmSession == nil {
            _ = TGMessageManager.shared.send(context: context,
                                             message: .iksmSessionNotSetMessage,
                                             parseMode: .markdown)
        } else {
            _ = TGMessageManager.shared.send(context: context,
                                             message: .iksmSessionInvalidMessage,
                                             parseMode: .markdown)
        }

        if loops.firstIndex(where: {
            $0.userId == userId && $0.chats.keys.contains(chatId)
        }) != nil {
            stop(context: context)
        }
    }
}

extension BotController {
    private func requestLastBattle(_ context: DataContext,
                                   battleIndex: Int = 0,
                                   block: ((DataContext) -> Void)? = nil) {
        SP2API.battleList(context: context) { battleOverview, code in
            if code == 200, let battleOverview = battleOverview {
                let lastBattle = battleOverview.battles[battleIndex]
                print(lastBattle.battleId)

                if context.loop {
                    guard let loopIndex = self.loops.firstIndex(where: {
                        $0.userId == context.user.id
                    }) else { return }
                    var loopInfo = self.loops[loopIndex]

                    if loopInfo.lastBattleId != nil &&
                               lastBattle.battleId != loopInfo.lastBattleId {
                        self.requestBattleDetail(context,
                                                 battleId: lastBattle.battleId)
                    }

                    loopInfo.lastBattleId = lastBattle.battleId
                    self.loops[loopIndex] = loopInfo
                } else {
                    self.requestBattleDetail(context, battleId: lastBattle.battleId)
                }

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
                                     iksmSession: String? = nil) {
        SP2API.battle(context: context, id: battleId) { battle, code in
            if code == 200, let battle = battle {
                if context.loop {
                    guard let loopIndex = self.loops.firstIndex(where: {
                        $0.userId == context.user.id
                    }) else { return }
                    var loopInfo = self.loops[loopIndex]

                    loopInfo.gameCount += 1
                    if battle.victory {
                        loopInfo.gameVictoryCount += 1
                    }

                    self.loops[loopIndex] = loopInfo

                    do {
                        try self.sendBattleToUserChats(context, battle: battle)
                    } catch {
                        print(error)
                    }
                } else {
                    do {
                        try self.sendBattleToUserChat(context, battle: battle)
                    } catch {
                        print(error)
                    }
                }

            } else if code == 403 {
                self.sendAuthErrorMessage(context)
            }
        }
    }
}
