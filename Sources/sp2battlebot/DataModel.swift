//
// Created by Jone Wang on 25/9/2019.
//

import Foundation
import Telegrammer

typealias TelegramUser = Telegrammer.User

// typealias TelegramChat = Telegrammer.Chat

struct User {
    var iksmSession: String?
    var telegramUser: TelegramUser

    init(iksmSession: String?, telegramUser: TelegramUser) {
        self.iksmSession = iksmSession
        self.telegramUser = telegramUser
    }
}

struct DataContext {
    var user: User
    var chat: Chat

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
            let userId = tgUser.id
            guard let user = try UserDataHelper.find(id: userId) else {
                return nil
            }

            return DataContext(user: user, chat: message.chat)
        } catch {
            print(error)
            return nil
        }
    }
}