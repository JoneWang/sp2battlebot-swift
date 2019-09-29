//
// Created by Jone Wang on 25/9/2019.
//

import Foundation
import Telegrammer

typealias TelegramUser = Telegrammer.User

struct User {
    var id: Int64
    var isBot: Bool
    var username: String?
    var firstName: String
    var lastName: String?
    var iksmSession: String?

    var showName: String {
        get {
            if let un = username {
                return "@\(un)"
            } else {
                return firstName
            }
        }
    }

    init(telegramUser: TelegramUser) {
        self.id = telegramUser.id
        self.isBot = telegramUser.isBot
        self.username = telegramUser.username
        self.firstName = telegramUser.firstName
        self.lastName = telegramUser.lastName
    }

    init(id: Int64,
         isBot: Bool,
         username: String? = nil,
         firstName: String,
         lastName: String? = nil,
         iksmSession: String? = nil) {
        self.id = id
        self.isBot = isBot
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.iksmSession = iksmSession
    }
}

struct DataContext {
    var user: User
    var chat: Chat
    var loop: Bool = false

    init(user: User, chat: Chat) {
        self.user = user
        self.chat = chat
    }

    static func from(update: Update) -> DataContext? {
        guard let message = update.message,
              let tgUser = message.from else {
            return nil
        }

        do {
            var user = User(telegramUser: tgUser)

            let storeUser = try UserDataHelper.find(id: tgUser.id)
            if let storeUser = storeUser {
                let iksmSession = storeUser.iksmSession

                user.iksmSession = iksmSession
            }

            return DataContext(user: user, chat: message.chat)
        } catch {
            print(error)
            return nil
        }
    }
}

struct LoopInfo {
    // Started all chat
    var chats: [Int64: Int?]
    var userId: Int64
    var lastBattleId: String?
    var gameCount = 0
    var gameVictoryCount = 0
}
