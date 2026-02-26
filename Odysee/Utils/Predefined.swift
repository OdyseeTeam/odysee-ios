//
//  Predefined.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import Foundation

enum Predefined {
    struct Language: Identifiable {
        let code: String
        let engName: String
        let name: String

        var id: String {
            code
        }
    }

    static let supportedLanguages: [Language] = [
        .init(code: "af", engName: "Afrikaans", name: "Afrikaans"),
        .init(code: "ar", engName: "Arabic", name: "العربية"),
        .init(code: "bg", engName: "Bulgarian", name: "Български"),
        .init(code: "bn", engName: "Bengali", name: "বাংলা"),
        .init(code: "ca", engName: "Catalan", name: "Català"),
        .init(code: "cs", engName: "Czech", name: "Česky"),
        .init(code: "cy", engName: "Welsh", name: "Cymraeg"),
        .init(code: "da", engName: "Danish", name: "Dansk"),
        .init(code: "de", engName: "German", name: "Deutsch"),
        .init(code: "el", engName: "Greek", name: "Ελληνικά"),
        .init(code: "en", engName: "English", name: "English"),
        .init(code: "eo", engName: "Esperanto", name: "Esperanto"),
        .init(code: "es", engName: "Spanish", name: "Español"),
        .init(code: "et", engName: "Estonian", name: "Eesti"),
        .init(code: "fa", engName: "Persian", name: "فارسی"),
        .init(code: "fi", engName: "Finnish", name: "Suomi"),
        .init(code: "fr", engName: "French", name: "Français"),
        .init(code: "gu", engName: "Gujarati", name: "ગુજરાતી"),
        .init(code: "he", engName: "Hebrew", name: "עברית"),
        .init(code: "hi", engName: "Hindi", name: "हिन्दी"),
        .init(code: "hr", engName: "Croatian", name: "Hrvatski"),
        .init(code: "hu", engName: "Hungarian", name: "Magyar"),
        .init(code: "it", engName: "Italian", name: "Italiano"),
        .init(code: "id", engName: "Indonesian", name: "Bahasa Indonesia"),
        .init(code: "ja", engName: "Japanese", name: "日本語"),
        .init(code: "jv", engName: "Javanese", name: "Basa Jawa"),
        .init(code: "kn", engName: "Kannada", name: "ಕನ್ನಡ"),
        .init(code: "ko", engName: "Korean", name: "한국어"),
        .init(code: "lt", engName: "Lithuanian", name: "Lietuvių"),
        .init(code: "lv", engName: "Latvian", name: "Latviešu"),
        .init(code: "ml", engName: "Malayalam", name: "മലയാളം"),
        .init(code: "mr", engName: "Marathi", name: "मराठी"),
        .init(code: "ms", engName: "Malay", name: "Bahasa Melayu"),
        .init(code: "ne", engName: "Nepali", name: "नेपाली"),
        .init(code: "nl", engName: "Dutch", name: "Nederlands"),
        .init(code: "nn", engName: "Norwegian Nynorsk", name: "Norsk (nynorsk)"),
        .init(code: "no", engName: "Norwegian", name: "Norsk (bokmål / riksmål)"),
        .init(code: "pa", engName: "Panjabi / Punjabi", name: "ਪੰਜਾਬੀ / पंजाबी / پنجابي"),
        .init(code: "pl", engName: "Polish", name: "Polski"),
        .init(code: "pt", engName: "Portuguese", name: "Português"),
        .init(code: "pt-BR", engName: "Portuguese (Brazil)", name: "Português (Brasil)"),
        .init(code: "ro", engName: "Romanian", name: "Română"),
        .init(code: "ru", engName: "Russian", name: "Русский"),
        .init(code: "sk", engName: "Slovak", name: "Slovenčina"),
        .init(code: "sl", engName: "Slovenian", name: "Slovenščina"),
        .init(code: "sr", engName: "Serbian", name: "Српски"),
        .init(code: "sv", engName: "Swedish", name: "Svenska"),
        .init(code: "ta", engName: "Tamil", name: "தமிழ்"),
        .init(code: "th", engName: "Thai", name: "ไทย / Phasa Thai"),
        .init(code: "tl", engName: "Tagalog", name: "Tagalog"),
        .init(code: "tr", engName: "Turkish", name: "Türkçe"),
        .init(code: "uk", engName: "Ukrainian", name: "Українська"),
        .init(code: "ur", engName: "Urdu", name: "اردو"),
        .init(code: "vi", engName: "Vietnamese", name: "Tiếng Việt"),
        .init(code: "zh-Hans", engName: "Chinese (Simplified)", name: "中文 (简体)"),
        .init(code: "zh-Hant", engName: "Chinese (Traditional)", name: "中文 (繁體)"),
    ].sorted(by: { $0.name < $1.name })

    static let licenses: [License] = [
        License(name: "None", url: nil),
        License(name: "Public domain", url: nil),
        License(
            name: "CC BY 4.0",
            url: "https://creativecommons.org/licenses/by/4.0/legalcode"
        ),
        License(
            name: "CC BY-SA 4.0",
            url: "https://creativecommons.org/licenses/by-sa/4.0/legalcode"
        ),
        License(
            name: "CC BY-ND 4.0",
            url: "https://creativecommons.org/licenses/by-nd/4.0/legalcode"
        ),
        License(
            name: "CC BY-NC 4.0",
            url: "https://creativecommons.org/licenses/by-nc/4.0/legalcode"
        ),
        License(
            name: "CC BY-NC-SA 4.0",
            url: "https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode"
        ),
        License(
            name: "CC BY-NC-ND 4.0",
            url: "https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode"
        ),
        License(name: "Copyrighted", url: nil),
        License(name: "Other", url: nil),
    ]
}
