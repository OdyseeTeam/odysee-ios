//
//  Predefined.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import Foundation

enum Predefined {
    typealias Language = (code: String, engName: String, name: String)

    static let supportedLanguages: [Language] = [
        (code: "af", engName: "Afrikaans", name: "Afrikaans"),
        (code: "ar", engName: "Arabic", name: "العربية"),
        (code: "bg", engName: "Bulgarian", name: "Български"),
        (code: "bn", engName: "Bengali", name: "বাংলা"),
        (code: "ca", engName: "Catalan", name: "Català"),
        (code: "cs", engName: "Czech", name: "Česky"),
        (code: "cy", engName: "Welsh", name: "Cymraeg"),
        (code: "da", engName: "Danish", name: "Dansk"),
        (code: "de", engName: "German", name: "Deutsch"),
        (code: "el", engName: "Greek", name: "Ελληνικά"),
        (code: "en", engName: "English", name: "English"),
        (code: "eo", engName: "Esperanto", name: "Esperanto"),
        (code: "es", engName: "Spanish", name: "Español"),
        (code: "et", engName: "Estonian", name: "Eesti"),
        (code: "fa", engName: "Persian", name: "فارسی"),
        (code: "fi", engName: "Finnish", name: "Suomi"),
        (code: "fr", engName: "French", name: "Français"),
        (code: "gu", engName: "Gujarati", name: "ગુજરાતી"),
        (code: "he", engName: "Hebrew", name: "עברית"),
        (code: "hi", engName: "Hindi", name: "हिन्दी"),
        (code: "hr", engName: "Croatian", name: "Hrvatski"),
        (code: "hu", engName: "Hungarian", name: "Magyar"),
        (code: "it", engName: "Italian", name: "Italiano"),
        (code: "id", engName: "Indonesian", name: "Bahasa Indonesia"),
        (code: "ja", engName: "Japanese", name: "日本語"),
        (code: "jv", engName: "Javanese", name: "Basa Jawa"),
        (code: "kn", engName: "Kannada", name: "ಕನ್ನಡ"),
        (code: "ko", engName: "Korean", name: "한국어"),
        (code: "lt", engName: "Lithuanian", name: "Lietuvių"),
        (code: "lv", engName: "Latvian", name: "Latviešu"),
        (code: "ml", engName: "Malayalam", name: "മലയാളം"),
        (code: "mr", engName: "Marathi", name: "मराठी"),
        (code: "ms", engName: "Malay", name: "Bahasa Melayu"),
        (code: "ne", engName: "Nepali", name: "नेपाली"),
        (code: "nl", engName: "Dutch", name: "Nederlands"),
        (code: "nn", engName: "Norwegian Nynorsk", name: "Norsk (nynorsk)"),
        (code: "no", engName: "Norwegian", name: "Norsk (bokmål / riksmål)"),
        (code: "pa", engName: "Panjabi / Punjabi", name: "ਪੰਜਾਬੀ / पंजाबी / پنجابي"),
        (code: "pl", engName: "Polish", name: "Polski"),
        (code: "pt", engName: "Portuguese", name: "Português"),
        (code: "pt-BR", engName: "Portuguese (Brazil)", name: "Português (Brasil)"),
        (code: "ro", engName: "Romanian", name: "Română"),
        (code: "ru", engName: "Russian", name: "Русский"),
        (code: "sk", engName: "Slovak", name: "Slovenčina"),
        (code: "sl", engName: "Slovenian", name: "Slovenščina"),
        (code: "sr", engName: "Serbian", name: "Српски"),
        (code: "sv", engName: "Swedish", name: "Svenska"),
        (code: "ta", engName: "Tamil", name: "தமிழ்"),
        (code: "th", engName: "Thai", name: "ไทย / Phasa Thai"),
        (code: "tl", engName: "Tagalog", name: "Tagalog"),
        (code: "tr", engName: "Turkish", name: "Türkçe"),
        (code: "uk", engName: "Ukrainian", name: "Українська"),
        (code: "ur", engName: "Urdu", name: "اردو"),
        (code: "vi", engName: "Vietnamese", name: "Tiếng Việt"),
        (code: "zh-Hans", engName: "Chinese (Simplified)", name: "中文 (简体)"),
        (code: "zh-Hant", engName: "Chinese (Traditional)", name: "中文 (繁體)"),
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
