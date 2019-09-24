//
// Created by Jone Wang on 24/9/2019.
//

import Foundation
import Telegrammer

struct TGMessageManager {
    static var shared = TGMessageManager()

    var bot: Bot!

    func send(chatId: Int64, snippet: TGMessage, parseMode: ParseMode? = nil) -> Future<Message> {
        let message = TGMessage.selector(snippet)
        print(message)
        let params = Bot.SendMessageParams(chatId: .chat(chatId),
                                           text: message,
                                           parseMode: parseMode)
        return try! bot.sendMessage(params: params)
    }

    func delete(chatId: Int64, messageId: Int) -> Future<Bool> {
        let params = Bot.DeleteMessageParams(chatId: .chat(chatId), messageId: messageId)
        return try! bot.deleteMessage(params: params)
    }
}