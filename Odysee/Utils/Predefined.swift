//
//  Predefined.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 22/03/2021.
//

import Foundation

enum Predefined {
    static let publishLanguages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "zh", name: "Chinese"),
        Language(code: "fr", name: "French"),
        Language(code: "de", name: "German"),
        Language(code: "jp", name: "Japanese"),
        Language(code: "ru", name: "Russian"),
        Language(code: "es", name: "Spanish"),
        Language(code: "id", name: "Indonesian"),
        Language(code: "it", name: "Italian"),
        Language(code: "nl", name: "Dutch"),
        Language(code: "tr", name: "Turkish"),
        Language(code: "pl", name: "Polish"),
        Language(code: "ms", name: "Malay"),
        Language(code: "pt", name: "Portuguese"),
        Language(code: "vi", name: "Vietnamese"),
        Language(code: "th", name: "Thai"),
        Language(code: "ar", name: "Arabic"),
        Language(code: "cs", name: "Czech"),
        Language(code: "hr", name: "Croatian"),
        Language(code: "km", name: "Cambodian"),
        Language(code: "ko", name: "Korean"),
        Language(code: "no", name: "Norwegian"),
        Language(code: "ro", name: "Romanian"),
        Language(code: "hi", name: "Hindi"),
        Language(code: "el", name: "Greek"),
        Language(code: "ca", name: "Catalan"),
    ]

    static let licenses: [License] = [
        License(name: "None", url: nil),
        License(name: "Public domain", url: nil),
        License(
            name: "Creative Commons Attribution 4.0 International",
            url: "https://creativecommons.org/licenses/by/4.0/legalcode"
        ),
        License(
            name: "Creative Commons Attribution-ShareAlike 4.0 International",
            url: "https://creativecommons.org/licenses/by-sa/4.0/legalcode"
        ),
        License(
            name: "Creative Commons Attribution-NoDerivatives 4.0 International",
            url: "https://creativecommons.org/licenses/by-nd/4.0/legalcode"
        ),
        License(
            name: "Creative Commons Attribution-NonCommercial 4.0 International",
            url: "https://creativecommons.org/licenses/by-nc/4.0/legalcode"
        ),
        License(
            name: "Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International",
            url: "https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode"
        ),
        License(
            name: "Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International",
            url: "https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode"
        ),
        License(name: "Copyrighted", url: nil),
        License(name: "Other", url: nil),
    ]
}
