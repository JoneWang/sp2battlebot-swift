//
//  BotController.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import CCurl
import Foundation
import Moya
import RxMoya
import RxSwift
import TelegramBotSDK

enum BotControllerError: Error {
    case NotFoundChatId
    case NotFoundMessageId
}

class BotController {
    static var shared: BotController!

    var bag = DisposeBag()

    let bot: TelegramBot

    let provider = MoyaProvider<SP2API>()

    // 已经启动自动战斗结果发送的对话
    // 其中保存了 message id 用于发送新战斗结果时删除上一次的结果消息
    var startedInChat = [Int64: Int?]()

    // Switch Online API headers
    var sp2Session: String

    // 保存50个 last 命令
    var lastFuncs = [(context: Context) -> Bool]()
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

    init(bot: TelegramBot, sp2Session: String) {
        self.bot = bot
        self.sp2Session = sp2Session

        // 生成获取最近10场战斗的 last 函数
        for i in 0..<10 {
            lastFuncs.append { [weak self] context in
                self?.requestLastBattle(context, battleIndex: i, block: nil)
                return true
            }
        }

        BotController.shared = self
    }

    func start(context: Context) -> Bool {
        guard let chatId = context.chatId else { return false }

        guard !started(in: chatId) else {
            context.respondAsync("@\(bot.username) already started.")
            return true
        }
        startedInChat[chatId] = nil

        var startText: String
        if !context.privateChat {
            startText = "@\(bot.username) started.\n"
        } else {
            startText = "@\(bot.username) started.\n"
        }
        startText += "To stop, type /stop"

        context.respondAsync(startText)

        loop = true
        startLastBattleRequestLoop(context)

        return true
    }

    func stop(context: Context) -> Bool {
        guard let chatId = context.chatId else { return false }

        guard started(in: chatId) else {
            context.respondAsync("@\(bot.username) already stopped.")
            return true
        }
        startedInChat.removeValue(forKey: chatId)
        loop = false
        firstGet = true

        context.respondSync("@\(bot.username) stopped. To restart, type /start")
        return true
    }

    func last(context: Context) -> Bool {
        requestLastBattle(context, battleIndex: 0, block: nil)
        return true
    }

    private func startLastBattleRequestLoop(_ context: Context) {
        requestLastBattle(context, requestLoop: true) { _ in
            if self.loop {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.startLastBattleRequestLoop(context)
                }
            }
        }
    }

    private func sendBattleToTG(_ context: Context,
                                battle: SP2Battle,
                                requestLoop: Bool) {
        var myTeamResults = battle.myTeamPlayerResults!
        // 将自己的结果添加到成员中
        myTeamResults.append(battle.selfPlayerResult)

        let otherTeamResults = battle.otherTeamPlayerResults!

        let sp2Message = TGSP2Message()
        
        if requestLoop {
            if battle.victory {
                sp2Message.append(content: "我们赢啦！")
            } else {
                sp2Message.append(content: "呜呜呜~输了不好意思见人了~")
            }
        
            sp2Message.append(content:
                String(format: "`当前胜率-%.0f%% 胜-%d 负-%d`",
                       Double(gameVictoryCount) / Double(gameCount) * 100,
                       gameVictoryCount,
                       gameCount - gameVictoryCount)
            )
        }
        else {
            sp2Message.append(content:
                String(format: "当前查询的战斗 %@ ID%d",
                       battle.victory ? "VICTORY" : "DEFEAT",
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
            sp2Message.append(content: String(format: "我方 \(battle.type)(%.1f)：", battle.myTeamPercentage!))
            sp2Message.append(rowsOf: generateMessageRows(myTeamResults))
            sp2Message.append(content: String(format: "对方 \(battle.type)(%.1f)：", battle.otherTeamPercentage!))
            sp2Message.append(rowsOf: generateMessageRows(otherTeamResults))
        } else if battle.type == .ranked {
            sp2Message.append(content: "我方：")
            sp2Message.append(rowsOf: generateMessageRows(myTeamResults))
            sp2Message.append(content: "对方：")
            sp2Message.append(rowsOf: generateMessageRows(otherTeamResults))
        } else if battle.type == .league {
            sp2Message.append(content: String(format: "我方 \(battle.type)(%d)：", battle.myEstimateLeaguePoint!))
            sp2Message.append(rowsOf: generateMessageRows(myTeamResults))
            sp2Message.append(content: String(format: "对方 \(battle.type)(%d)：", battle.otherEstimateLeaguePoint!))
            sp2Message.append(rowsOf: generateMessageRows(otherTeamResults))
        }

        if let chatId = context.chatId,
           let messageId = self.startedMessageId(in: chatId) {
            startedInChat[context.chatId!] = nil
            bot.deleteMessageSync(chatId: context.chatId!, messageId: messageId)
        }

        print(sp2Message.text)
        context.respondAsync(sp2Message.text, parseMode: "Markdown") { result, error in
            print("send completed")
            if let chatId = result?.chat.id, error == nil {
                self.startedInChat[chatId] = result?.messageId
            }
        }
    }
}

extension BotController {
    private func requestLastBattle(_ context: Context,
                                   battleIndex: Int = 0,
                                   requestLoop: Bool = false,
                                   block: ((Context) -> Void)?) {
        provider.rx.request(.battleList)
                .map(SP2BattleList.self)
                .subscribe { [unowned self] event in
                    switch event {
                    case .success(let response):
                        let lastBattle = response.battles[battleIndex]

                        if block == nil || (!self.firstGet &&
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
                    case .error(let error):
                        if let block = block {
                            block(context)
                        }
                        print("\(error)")
                    }
                }
                .disposed(by: bag)
    }

    private func requestBattleDetail(_ context: Context,
                                     battleId: String,
                                     requestLoop: Bool) {
        provider.rx.request(.battleDetail(id: battleId))
                .map(SP2Battle.self)
                .subscribe { [unowned self] event in
                    switch event {
                    case .success(let battle):
                        if requestLoop {
                            self.gameCount += 1
                            self.gameVictoryCount += 1
                        }
                        self.sendBattleToTG(context,
                                            battle: battle,
                                            requestLoop: requestLoop)
                    case .error(let error):
                        print("\(error)")
                    }
                }
                .disposed(by: bag)
    }
}
