//
//  SP2Message.swift
//  sp2battlebot
//
//  Created by Jone Wang on 21/9/2019.
//

import Foundation

protocol TGSP2MessageRow {
    var text: String { get }
}

struct TGSP2MessageTextRow: TGSP2MessageRow {
    var text: String

    public init(content: String) {
        text = content
    }
}

struct TGSP2MessageMemberRow: TGSP2MessageRow {
    var kill: Int
    var assist: Int
    var death: Int
    var special: Int
    var nickname: String

    var text: String {
        let formatLine = "*▸*`%2d(%d)k` `%2dd %dsp` `\(String(nickname.prefix(9)))`"

        return String(format: formatLine,
                      kill + assist,
                      assist,
                      death,
                      special)
    }
}

class TGSP2Message {
    var rows = [TGSP2MessageRow]()

    var text: String {
        var stringMessage = ""
        for row in rows {
            stringMessage += row.text + "\n"
        }

        return stringMessage
    }

    func append(row: TGSP2MessageRow) {
        rows.append(row)
    }

    func append(rowsOf newRows: [TGSP2MessageRow]) {
        rows.append(contentsOf: newRows)
    }

    func append(content: String) {
        append(row: TGSP2MessageTextRow(content: content))
    }
}
