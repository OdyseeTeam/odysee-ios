//
//  Constants.swift
//  Odysee
//
//  Created by Akinwale Ariwodola on 14/10/2021.
//

import Foundation

enum Constants {
    static let NotTags: [String] = [
        // MATURE TAGS
        "porn",
        "porno",
        "nsfw",
        "mature",
        "xxx",
        "sex",
        "creampie",
        "blowjob",
        "handjob",
        "vagina",
        "boobs",
        "big boobs",
        "big dick",
        "pussy",
        "cumshot",
        "anal",
        "hard fucking",
        "ass",
        "fuck",
        "hentai",

        // obnoxious, but necessary
        "pron",
        "p0rn",
        "pr0n",
        "s3x",

        // even more, because Apple
        "camporn",
        "fetish",
        "pornographic",
        "pornography",
        // END MATURE TAGS

        // MISC
        "c:unlisted",
    ]

    static let BlockedSearchTerms = [
        // Apple wants everything to be as clean as possible, US edition
        "1488",
        "coon",
        "coonass",
        "coons",
        "chinaman",
        "chinamen",
        "ching chong",
        "dindu",
        "great replacement",
        "nazi",
        "nazis",
        "jew",
        "jews",
        "kike",
        "kikes",
        "negro",
        "negroes",
        "nigga",
        "niggas",
        "nigger",
        "niggers",
        "raghead",
        "ragheads",
        "spic",
        "spick",
        "spics",
        "spicks",
        "spig",
        "spik",
        "spigs",
        "spigotty",
        "spiks",
        "the great replacement",
        "towelhead",
        "towelheads",
    ]

    static let MembersOnly = "c:members-only"

    static let InternalTagPrefix = "c:"
    enum ControlTags: String, CustomStringConvertible, Identifiable, CaseIterable {
        var id: String {
            rawValue
        }

        case disableSupport = "disable-support"
        case disableReactionsVideo = "c:disable-reactions-video"
        case disableSlimesVideo = "c:disable-slimes-video"

        var description: String {
            switch self {
            case .disableSupport: __("Disable Tipping and Boosting")
            case .disableReactionsVideo: __("Disable Likes/Dislikes - Content")
            case .disableSlimesVideo: __("Disable Dislikes - Content")
            }
        }

        static var All: [String] {
            allCases.map(\.rawValue)
        }
    }

    static let KnownTags = [
        "activism",
        "adventure",
        "agnostic",
        "aliens",
        "altcoins",
        "amazon",
        "anarchy",
        "android",
        "animal",
        "animals",
        "animation",
        "anime",
        "apple",
        "arcade",
        "ark",
        "art",
        "artist",
        "atheism",
        "atheist",
        "audio",
        "australia",
        "auto",
        "automotive",
        "bass",
        "batman",
        "battle royale",
        "beach",
        "beat",
        "beats",
        "beliefs",
        "bible",
        "bitcoin gratis",
        "bitcoin price",
        "bitcoin",
        "black ops 3",
        "black ops",
        "blockchain",
        "bo1",
        "bo2",
        "bo3",
        "bo4",
        "bodybuilding",
        "boss",
        "brasil",
        "btc",
        "building",
        "business",
        "california",
        "call of duty",
        "camping",
        "canon",
        "capcom",
        "car",
        "cars",
        "cartoon",
        "cat",
        "cbs",
        "censorship",
        "chill",
        "chris",
        "christ",
        "christian",
        "christianity",
        "christmas",
        "church",
        "clips",
        "cnn",
        "cod",
        "combat",
        "comedy",
        "comic",
        "comics",
        "commentary",
        "community",
        "computer",
        "consciousness",
        "conservative",
        "console",
        "conspiracy",
        "cosplay",
        "cover",
        "crafting",
        "crash",
        "creepy",
        "creepypasta",
        "crypto",
        "cryptocurrency",
        "culture",
        "cute",
        "daily vlog",
        "daily",
        "dance",
        "dantdm",
        "day",
        "dayz",
        "dc",
        "death",
        "democrat",
        "design",
        "destiny 2",
        "destiny",
        "discord",
        "disney",
        "diy",
        "dj",
        "dlc",
        "dog",
        "donald trump",
        "dope",
        "dota 2",
        "dota",
        "dragon",
        "drama",
        "drawing",
        "driving",
        "drone",
        "dubstep",
        "duty",
        "earth",
        "economics",
        "economy",
        "edit",
        "edm",
        "education",
        "eggs",
        "electronic",
        "england",
        "entertainment",
        "epic",
        "eth",
        "ethereum",
        "exploration",
        "extreme",
        "facebook",
        "fail",
        "fake news",
        "fallout 4",
        "family friendly",
        "family",
        "fantasy",
        "far cry 5",
        "fashion",
        "fiction",
        "film & animation",
        "film",
        "final fantasy",
        "final",
        "fire",
        "first look",
        "fitness",
        "flash",
        "flat earth",
        "food",
        "football",
        "fortnite",
        "fox news",
        "fox",
        "fps",
        "fpv",
        "free speech",
        "freedom",
        "freestyle",
        "full time rving",
        "fun",
        "funny moments",
        "funny",
        "future bass",
        "future",
        "galaxy",
        "game reviews",
        "game",
        "gameplay",
        "gamer",
        "gamers",
        "games",
        "gaming",
        "garden",
        "germany",
        "ghost",
        "god",
        "gold",
        "government",
        "grand theft auto",
        "gta v",
        "gta",
        "guitar",
        "gun",
        "guns",
        "guru",
        "hack",
        "halloween",
        "halo",
        "hangoutsonair",
        "happy",
        "hardcore",
        "health",
        "help",
        "hero",
        "hilarious",
        "hillary clinton",
        "hip hop",
        "hiphop",
        "history",
        "hoa",
        "holiday",
        "horror",
        "house",
        "how to",
        "how-to",
        "howto",
        "humor",
        "humour",
        "ico",
        "illuminati",
        "indie",
        "industry",
        "insane",
        "instrumental",
        "investing",
        "ios",
        "iphone",
        "island",
        "jesus",
        "juvenile fiction",
        "knife",
        "latest news",
        "lbrytvpaidbeta",
        "league of legends",
        "league",
        "learning",
        "lee",
        "lessons",
        "lets play",
        "lets",
        "level",
        "liberal",
        "libertarian",
        "liberty",
        "light",
        "linux",
        "litecoin",
        "lol",
        "loot",
        "lord",
        "love",
        "magic",
        "manga",
        "mario",
        "marvel",
        "mass effect",
        "master",
        "mature",
        "media",
        "meme",
        "memes",
        "metal",
        "microsoft",
        "military",
        "minecraft",
        "mining",
        "mix",
        "mmo",
        "mmorpg",
        "mobile",
        "mod",
        "modded",
        "mods",
        "mojang",
        "money",
        "motivation",
        "movie",
        "movies",
        "msnbc",
        "multiplayer",
        "music video",
        "music",
        "muslim",
        "mw2",
        "mw3",
        "nasa",
        "nature",
        "nbc",
        "new music",
        "news radio",
        "news",
        "ninja",
        "nintendo switch",
        "nintendo",
        "non-profits",
        "noob",
        "nvidia",
        "online learning",
        "online",
        "open world",
        "outdoor",
        "overwatch",
        "pacman",
        "paladins",
        "paranormal",
        "parody",
        "patreon",
        "paypal",
        "pc game",
        "pc gaming",
        "pc",
        "peace",
        "pets",
        "photography",
        "planet",
        "play",
        "player",
        "playing",
        "playlist",
        "plays",
        "playstation",
        "playthrough",
        "podcast",
        "poetry",
        "pokemon",
        "political",
        "politics",
        "pop culture",
        "pop",
        "portugal",
        "post",
        "prank",
        "press",
        "pro",
        "progressive talk",
        "progressive",
        "ps2",
        "ps3",
        "ps4",
        "pubg mobile",
        "pubg",
        "puzzle",
        "pvp",
        "quad",
        "quest",
        "race",
        "racing",
        "rainbow",
        "random",
        "rant",
        "rap",
        "raw",
        "rda",
        "react",
        "reaction",
        "reading",
        "reaper",
        "religion",
        "remix",
        "republican",
        "resident evil",
        "retro",
        "reviews",
        "ripple",
        "roblox",
        "rock",
        "role-playing game",
        "role-playing",
        "rpg",
        "rta",
        "rv park",
        "rv",
        "samsung",
        "sandbox",
        "satire",
        "school",
        "sci-fi",
        "science fiction",
        "science",
        "scotland",
        "season",
        "secret",
        "secular talk",
        "secular",
        "sega",
        "senate",
        "server",
        "sharefactory",
        "shooter game",
        "shooting",
        "silly",
        "sims 4",
        "sims",
        "simulation",
        "singing",
        "skyrim",
        "smok",
        "sniper",
        "sniping",
        "software",
        "solar",
        "song",
        "sony",
        "soul",
        "sound",
        "space",
        "special",
        "spirituality",
        "sports",
        "squad gameplay",
        "star wars",
        "star",
        "steam",
        "stories",
        "strategy",
        "stream",
        "studio",
        "stupid",
        "style",
        "subscribe",
        "super smash bros",
        "survival horror",
        "survival",
        "switch",
        "tactical",
        "teaser",
        "tech",
        "technology",
        "timelapse",
        "top 10",
        "tourism",
        "trading",
        "trailer",
        "training",
        "trap",
        "travel trailer",
        "travel",
        "trending",
        "truck",
        "trump",
        "truth",
        "tutorial",
        "twitch",
        "twitter",
        "ubisoft",
        "ufo",
        "unboxing",
        "united states",
        "universe",
        "vacation",
        "vape",
        "vaping",
        "vapor",
        "vegan",
        "video blog",
        "video game culture",
        "video game",
        "video games",
        "videogame",
        "videogames",
        "viral",
        "vlogging",
        "vr",
        "walkthrough",
        "war",
        "warrior",
        "water",
        "weapons",
        "weird",
        "wii u",
        "wii",
        "windows",
        "workout",
        "world of warcraft",
        "world",
        "wrestling",
        "ww2",
        "wwe",
        "xbox",
        "xbox360",
        "zombie",
        "zombies",
        "19th century",
        "4k",

        "español",
        "tecnología",
        "criptomonedas",
        "economía",
        "bitcoin",
        "educación",
        "videojuegos",
        "música",
        "noticias",
        "ciencia",
        "deportes",
        "latinoamérica",
        "latam",
        "conspiración",
        "humor",
        "política",
        "tutoriales",
    ]

    static func FreeSticker(name: String) -> ImageResource? {
        switch name {
        case "ACTUALLY": .ACTUALLY
        case "BAN": .BAN
        case "BILL_CLINTON": .BILL_CLINTON
        case "BILL_COSBY": .BILL_COSBY
        case "BRAVO": .BRAVO
        case "BULL_RIDE": .BULL_RIDE
        case "CAT": .CAT
        case "CHE_GUEVARA": .CHE_GUEVARA
        case "DOGE": .DOGE
        case "DONALD_TRUMP": .DONALD_TRUMP
        case "EGG_CARTON": .EGG_CARTON
        case "ELIMINATED": .ELIMINATED
        case "EPSTEIN_ISLAND": .EPSTEIN_ISLAND
        case "FAIL": .FAIL
        case "FIRE": .FIRE
        case "GRR": .GRR
        case "HYPE": .HYPE
        case "INTERESTING": .INTERESTING
        case "KANYE_WEST": .KANYE_WEST
        case "KURT_COBAIN": .KURT_COBAIN
        case "MONEY_PRINTER": .MONEY_PRINTER
        case "MOUNT_RUSHMORE": .MOUNT_RUSHMORE
        case "PANTS_1": .PANTS_1
        case "PISS": .PISS
        case "PREGNANT_MAN_BLONDE": .PREGNANT_MAN_BLONDE
        case "ROCKET_SPACEMAN": .ROCKET_SPACEMAN
        case "SALTY": .SALTY
        case "SICK_FLAME": .SICK_FLAME
        case "SICK_SKULL": .SICK_SKULL
        case "SLIME": .SLIME
        case "SPHAGETTI_BATH": .SPHAGETTI_BATH
        case "TAYLOR_SWIFT": .TAYLOR_SWIFT
        case "THUG_LIFE": .THUG_LIFE
        case "THUMBS_UP": .THUMBS_UP
        case "TRAP": .TRAP
        case "TRASH": .TRASH
        case "WAITING": .WAITING
        case "WHUUT": .WHUUT
        case "WOW": .WOW
        default: nil
        }
    }

    static func PaidSticker(name: String) -> ImageResource? {
        switch name {
        case "BIG_LBC_TIP": .BIG_LBC_TIP
        case "BIG_TIP": .BIG_TIP
        case "BITE_LBC_CLOSEUP": .BITE_LBC_CLOSEUP
        case "BITE_TIP": .BITE_TIP
        case "BITE_TIP_CLOSEUP": .BITE_TIP_CLOSEUP
        case "COMET_TIP": .COMET_TIP
        case "FORTUNE_CHEST": .FORTUNE_CHEST
        case "FORTUNE_CHEST_LBC": .FORTUNE_CHEST_LBC
        case "LARGE_LBC_TIP": .LARGE_LBC_TIP
        case "LARGE_TIP": .LARGE_TIP
        case "LBC_COMET_TIP": .LBC_COMET_TIP
        case "MEDIUM_LBC_TIP": .MEDIUM_LBC_TIP
        case "MEDIUM_TIP": .MEDIUM_TIP
        case "SILVER_ODYSEE_COIN": .SILVER_ODYSEE_COIN
        case "SMALL_LBC_TIP": .SMALL_LBC_TIP
        case "SMALL_TIP": .SMALL_TIP
        case "TIP_HAND_FLIP": .TIP_HAND_FLIP
        case "TIP_HAND_FLIP_COIN": .TIP_HAND_FLIP_COIN
        case "TIP_HAND_FLIP_LBC": .TIP_HAND_FLIP_LBC
        default: nil
        }
    }

    static func OdyseeEmote(name: String) -> ImageResource? {
        switch name {
        case "alien": .alien
        case "angry_1": .angry1
        case "angry_2": .angry2
        case "angry_3": .angry3
        case "angry_4": .angry4
        case "blind": .blind
        case "block": .block
        case "bomb": .bomb
        case "brain_chip": .brainChip
        case "confirm": .confirm
        case "confused_1": .confused1
        case "confused_2": .confused2
        case "cooking_something_nice": .cookingSomethingNice
        case "cry_1": .cry1
        case "cry_2": .cry2
        case "cry_3": .cry3
        case "cry_4": .cry4
        case "cry_5": .cry5
        case "donut": .donut
        case "eggplant": .eggplant
        case "eggplant_with_condom": .eggplantWithCondom
        case "fire_up": .fireUp
        case "flat_earth": .flatEarth
        case "flying_saucer": .flyingSaucer
        case "heart_chopper": .heartChopper
        case "hyper_troll": .hyperTroll
        case "ice_cream": .iceCream
        case "idk": .idk
        case "illuminati_1": .illuminati1
        case "illuminati_2": .illuminati2
        case "kiss_1": .kiss1
        case "kiss_2": .kiss2
        case "laser_gun": .laserGun
        case "laughing_1": .laughing1
        case "laughing_2": .laughing2
        case "lollipop": .lollipop
        case "love_1": .love1
        case "love_2": .love2
        case "monster": .monster
        case "mushroom": .mushroom
        case "nail_it": .nailIt
        case "no": .no
        case "ouch": .ouch
        case "peace": .peace
        case "pizza": .pizza
        case "rabbit_hole": .rabbitHole
        case "rainbow_puke_1": .rainbowPuke1
        case "rainbow_puke_2": .rainbowPuke2
        case "rock": .rock
        case "sad": .sad
        case "salty": .salty
        case "scary": .scary
        case "sleep": .sleep
        case "slime_down": .slimeDown
        case "smelly_socks": .smellySocks
        case "smile_1": .smile1
        case "smile_2": .smile2
        case "space_chad": .spaceChad
        case "space_doge": .spaceDoge
        case "space_green_wojak": .spaceGreenWojak
        case "space_julian": .spaceJulian
        case "space_red_wojak": .spaceRedWojak
        case "space_resitas": .spaceResitas
        case "space_tom": .spaceTom
        case "spock": .spock
        case "star": .star
        case "sunny_day": .sunnyDay
        case "surprised": .surprised
        case "sweet": .sweet
        case "thinking_1": .thinking1
        case "thinking_2": .thinking2
        case "thumb_down": .thumbDown
        case "thumb_up_1": .thumbUp1
        case "thumb_up_2": .thumbUp2
        case "tinfoil_hat": .tinfoilHat
        case "troll_king": .trollKing
        case "ufo": .ufo
        case "waiting": .waiting
        case "what": .what
        case "woodoo_doll": .woodooDoll
        default: nil
        }
    }

    static func SmilesTwemote(name: String) -> ImageResource? {
        switch name {
        case "alien_1": .alien1
        case "angry": .angry
        case "anguished": .anguished
        case "astonished": .astonished
        case "blush": .blush
        case "clown_face": .clownFace
        case "cold": .cold
        case "cold_sweat": .coldSweat
        case "confounded": .confounded
        case "confused": .confused
        case "cowboy_hat_face": .cowboyHatFace
        case "cry": .cry
        case "disappointed": .disappointed
        case "disappointed_relieved": .disappointedRelieved
        case "disguised_face": .disguisedFace
        case "dizzy_face": .dizzyFace
        case "drooling_face": .droolingFace
        case "exhaling": .exhaling
        case "exploding_head": .explodingHead
        case "expressionless": .expressionless
        case "face_in_clouds": .faceInClouds
        case "face_with_head_bandage": .faceWithHeadBandage
        case "face_with_thermometer": .faceWithThermometer
        case "fearful": .fearful
        case "flushed": .flushed
        case "frowning": .frowning
        case "frowning_face": .frowningFace
        case "full_moon_face": .fullMoonFace
        case "grimacing": .grimacing
        case "grin": .grin
        case "grinning": .grinning
        case "hand_over_mouth": .handOverMouth
        case "heart_eyes": .heartEyes
        case "hot": .hot
        case "hugging": .hugging
        case "hushed": .hushed
        case "imp": .imp
        case "innocent": .innocent
        case "jack_o_lantern": .jackOLantern
        case "japanese_goblin": .japaneseGoblin
        case "japanese_ogre": .japaneseOgre
        case "joy": .joy
        case "kissing": .kissing
        case "kissing_closed_eyes": .kissingClosedEyes
        case "kissing_heart": .kissingHeart
        case "kissing_smiling_eyes": .kissingSmilingEyes
        case "laughing": .laughing
        case "lying_face": .lyingFace
        case "mask": .mask
        case "melting_face": .meltingFace
        case "moai": .moai
        case "money_mouth_face": .moneyMouthFace
        case "monocle": .monocle
        case "nauseated_face": .nauseatedFace
        case "nerd_face": .nerdFace
        case "neutral_face": .neutralFace
        case "new_moon_face": .newMoonFace
        case "no_mouth": .noMouth
        case "open_mouth": .openMouth
        case "partying": .partying
        case "pensive": .pensive
        case "persevere": .persevere
        case "pleading": .pleading
        case "rage": .rage
        case "raised_eyebrow": .raisedEyebrow
        case "relaxed": .relaxed
        case "relieved": .relieved
        case "robot": .robot
        case "rofl": .rofl
        case "roll_eyes": .rollEyes
        case "santa_claus": .santaClaus
        case "scream": .scream
        case "shushing": .shushing
        case "skull": .skull
        case "sleeping": .sleeping
        case "sleepy": .sleepy
        case "slight_smile": .slightSmile
        case "slightly_frowning_face": .slightlyFrowningFace
        case "smile": .smile
        case "smiley": .smiley
        case "smiling_face_with_hearts": .smilingFaceWithHearts
        case "smiling_face_with_tear": .smilingFaceWithTear
        case "smiling_imp": .smilingImp
        case "smirk": .smirk
        case "sneezing_face": .sneezingFace
        case "sob": .sob
        case "space_invader": .spaceInvader
        case "spiral_eyes": .spiralEyes
        case "star_struck": .starStruck
        case "stuck_out_tongue": .stuckOutTongue
        case "stuck_out_tongue_closed_eyes": .stuckOutTongueClosedEyes
        case "stuck_out_tongue_winking_eye": .stuckOutTongueWinkingEye
        case "sunglasses": .sunglasses
        case "sweat": .sweat
        case "sweat_smile": .sweatSmile
        case "symbols_over_mouth": .symbolsOverMouth
        case "thinking": .thinking
        case "tired_face": .tiredFace
        case "triump": .triump
        case "unamused": .unamused
        case "upside_down_face": .upsideDownFace
        case "vomiting": .vomiting
        case "weary": .weary
        case "wink": .wink
        case "woozy": .woozy
        case "worried": .worried
        case "yawning": .yawning
        case "yum": .yum
        case "zany": .zany
        case "zipper_mouth_face": .zipperMouthFace
        default: nil
        }
    }

    static func HandsignalsTwemote(name: String) -> ImageResource? {
        switch name {
        case "backhand_index_pointing_down": .backhandIndexPointingDown
        case "backhand_index_pointing_left": .backhandIndexPointingLeft
        case "backhand_index_pointing_right": .backhandIndexPointingRight
        case "backhand_index_pointing_up": .backhandIndexPointingUp
        case "call_me_hand": .callMeHand
        case "clapping_hands": .clappingHands
        case "crossed_fingers": .crossedFingers
        case "folded_hands": .foldedHands
        case "hand_with_index_finger_and_thumb_crossed": .handWithIndexFingerAndThumbCrossed
        case "handshake": .handshake
        case "heart_hands": .heartHands
        case "index_pointing_at_the_viewer": .indexPointingAtTheViewer
        case "index_pointing_up": .indexPointingUp
        case "left_facing_fist": .leftFacingFist
        case "leftwards_hand": .leftwardsHand
        case "love_you_gesture": .loveYouGesture
        case "middle_finger": .middleFinger
        case "ok_hand": .okHand
        case "oncoming_fist": .oncomingFist
        case "open_hands": .openHands
        case "palm_down_hand": .palmDownHand
        case "palm_up_hand": .palmUpHand
        case "palms_up_together": .palmsUpTogether
        case "pinched_fingers": .pinchedFingers
        case "pinching_hand": .pinchingHand
        case "raised_back_of_hand": .raisedBackOfHand
        case "raised_fist": .raisedFist
        case "raised_hand": .raisedHand
        case "raised_hand_with_fingers_splayed": .raisedHandWithFingersSplayed
        case "raising_hands": .raisingHands
        case "right_facing_fist": .rightFacingFist
        case "rightwards_hand": .rightwardsHand
        case "sign_of_the_horns": .signOfTheHorns
        case "thumbs_down": .thumbsDown
        case "thumbs_up": .thumbsUp
        case "victory_hand": .victoryHand
        case "vulcan_salute": .vulcanSalute
        case "waving_hand": .wavingHand
        default: nil
        }
    }

    static func ActivitiesTwemote(name: String) -> ImageResource? {
        switch name {
        case "accordion": .accordion
        case "adhesive_bandage": .adhesiveBandage
        case "airplane": .airplane
        case "american_football": .americanFootball
        case "arcade": .arcade
        case "artist_palette": .artistPalette
        case "automobile": .automobile
        case "axe": .axe
        case "backpack": .backpack
        case "badminton": .badminton
        case "banjo": .banjo
        case "baseball": .baseball
        case "basketball": .basketball
        case "bathtub": .bathtub
        case "bicycle": .bicycle
        case "boomerang": .boomerang
        case "bow_and_arrow": .bowAndArrow
        case "bowling": .bowling
        case "boxing_glove": .boxingGlove
        case "broom": .broom
        case "bucket": .bucket
        case "bus": .bus
        case "canoe": .canoe
        case "carousel_horse": .carouselHorse
        case "carpentry_saw": .carpentrySaw
        case "cigarette": .cigarette
        case "cricket_game": .cricketGame
        case "crystal_ball": .crystalBall
        case "curling_stone": .curlingStone
        case "dart": .dart
        case "diving_mask": .divingMask
        case "drum": .drum
        case "field_hockey": .fieldHockey
        case "fishing_pole": .fishingPole
        case "flying_saucer": .flyingSaucer
        case "game_die": .gameDie
        case "gameboy": .gameboy
        case "golf": .golf
        case "guitar": .guitar
        case "hammer": .hammer
        case "hammer_and_pick": .hammerAndPick
        case "hammer_and_wrench": .hammerAndWrench
        case "headphone": .headphone
        case "helicopter": .helicopter
        case "ice_hockey": .iceHockey
        case "joystick": .joystick
        case "kick_scooter": .kickScooter
        case "lacrosse": .lacrosse
        case "long_drum": .longDrum
        case "magic_wand": .magicWand
        case "martial_arts_uniform": .martialArtsUniform
        case "microphone": .microphone
        case "microscope": .microscope
        case "minibus": .minibus
        case "motor_scooter": .motorScooter
        case "motorcycle": .motorcycle
        case "musical_keyboard": .musicalKeyboard
        case "musical_score": .musicalScore
        case "parachute": .parachute
        case "pc": .pc
        case "pick": .pick
        case "pill": .pill
        case "ping_pong": .pingPong
        case "playground_slide": .playgroundSlide
        case "plunger": .plunger
        case "postal_horn": .postalHorn
        case "ps5": .ps5
        case "racing_car": .racingCar
        case "razor": .razor
        case "rocket": .rocket
        case "roller_skate": .rollerSkate
        case "rugby_football": .rugbyFootball
        case "sailboat": .sailboat
        case "saxophone": .saxophone
        case "scissors": .scissors
        case "screwdriver": .screwdriver
        case "sewing_needle": .sewingNeedle
        case "shower": .shower
        case "skateboard": .skateboard
        case "slot_machine": .slotMachine
        case "smartphone": .smartphone
        case "soccer": .soccer
        case "softball": .softball
        case "straight_ruler": .straightRuler
        case "switch": .switch
        case "tennis": .tennis
        case "toilet": .toilet
        case "toothbrush": .toothbrush
        case "tractor": .tractor
        case "train": .train
        case "trolleybus": .trolleybus
        case "trumpet": .trumpet
        case "video_game": .videoGame
        case "violin": .violin
        case "volleyball": .volleyball
        case "vr": .vr
        case "wrench": .wrench
        case "xbox": .xbox
        default: nil
        }
    }

    static func SymbolsTwemote(name: String) -> ImageResource? {
        switch name {
        case "anger_symbol": .angerSymbol
        case "beating_heart": .beatingHeart
        case "black_heart": .blackHeart
        case "blue_heart": .blueHeart
        case "broken_heart": .brokenHeart
        case "brown_heart": .brownHeart
        case "collision": .collision
        case "comet": .comet
        case "cyclone": .cyclone
        case "fire": .fire
        case "first_quarter_moon_face": .firstQuarterMoonFace
        case "glowing_star": .glowingStar
        case "green_heart": .greenHeart
        case "growing_heart": .growingHeart
        case "heart": .heart
        case "heart_exclamation": .heartExclamation
        case "heart_on_fire": .heartOnFire
        case "heart_with_arrow": .heartWithArrow
        case "heart_with_ribbon": .heartWithRibbon
        case "high_voltage": .highVoltage
        case "hundred_points": .hundredPoints
        case "kiss_mark": .kissMark
        case "mending_heart": .mendingHeart
        case "no_entry": .noEntry
        case "orange_hear": .orangeHear
        case "pixel_heart": .pixelHeart
        case "prohibited": .prohibited
        case "purple_heart": .purpleHeart
        case "rainbow": .rainbow
        case "recycling": .recycling
        case "revolving_hearts": .revolvingHearts
        case "right_anger_bubble": .rightAngerBubble
        case "ringed_planet": .ringedPlanet
        case "snowflake": .snowflake
        case "sparkling_heart": .sparklingHeart
        case "speech_balloon": .speechBalloon
        case "sun": .sun
        case "thought_balloon": .thoughtBalloon
        case "two_hearts": .twoHearts
        case "warning": .warning
        case "white_heart": .whiteHeart
        case "yellow_heart": .yellowHeart
        case "zzz": .zzz
        default: nil
        }
    }

    static func NatureTwemote(name: String) -> ImageResource? {
        switch name {
        case "ant": .ant
        case "bat": .bat
        case "bear": .bear
        case "beetle": .beetle
        case "bird": .bird
        case "bison": .bison
        case "blowfish": .blowfish
        case "boar": .boar
        case "bug": .bug
        case "butterfly": .butterfly
        case "cactus": .cactus
        case "camel": .camel
        case "cat": .cat
        case "cherry_blossom": .cherryBlossom
        case "chicken": .chicken
        case "cockroach": .cockroach
        case "cow": .cow
        case "crab": .crab
        case "cricket": .cricket
        case "crocodile": .crocodile
        case "deciduous_tree": .deciduousTree
        case "deer": .deer
        case "dodo": .dodo
        case "dog": .dog
        case "dolphin": .dolphin
        case "dove": .dove
        case "dragon_face": .dragonFace
        case "duck": .duck
        case "eagle": .eagle
        case "elephant": .elephant
        case "evergreen_tree": .evergreenTree
        case "fish": .fish
        case "flamingo": .flamingo
        case "fly": .fly
        case "fox": .fox
        case "frog": .frog
        case "giraffe": .giraffe
        case "goat": .goat
        case "gorilla": .gorilla
        case "hamster": .hamster
        case "hear_no_evil": .hearNoEvil
        case "hedgehog": .hedgehog
        case "herb": .herb
        case "hippopotamus": .hippopotamus
        case "honeybee": .honeybee
        case "horse_face": .horseFace
        case "kangaroo": .kangaroo
        case "koala": .koala
        case "lady_beetle": .ladyBeetle
        case "leopard": .leopard
        case "lion": .lion
        case "lizard": .lizard
        case "llama": .llama
        case "lobster": .lobster
        case "lotus": .lotus
        case "mammoth": .mammoth
        case "monkey": .monkey
        case "mosquito": .mosquito
        case "mouse": .mouse
        case "octopus": .octopus
        case "otter": .otter
        case "owl": .owl
        case "palm_tree": .palmTree
        case "panda": .panda
        case "parrot": .parrot
        case "peacock": .peacock
        case "penguin": .penguin
        case "pig": .pig
        case "polar_bear": .polarBear
        case "rabbit": .rabbit
        case "raccoon": .raccoon
        case "rhinoceros": .rhinoceros
        case "rose": .rose
        case "sauropod": .sauropod
        case "scorpion": .scorpion
        case "seal": .seal
        case "see_no_evil": .seeNoEvil
        case "shark": .shark
        case "shrimp": .shrimp
        case "skunk": .skunk
        case "sloth": .sloth
        case "snail": .snail
        case "snake": .snake
        case "speak_no_evil": .speakNoEvil
        case "spider": .spider
        case "spiral_shell": .spiralShell
        case "squid": .squid
        case "swan": .swan
        case "t-rex": .tRex
        case "tiger": .tiger
        case "tropical_fish": .tropicalFish
        case "tulip": .tulip
        case "turtle": .turtle
        case "unicorn": .unicorn
        case "whale": .whale
        case "wolf": .wolf
        case "worm": .worm
        case "zebra": .zebra
        default: nil
        }
    }

    static func FoodTwemote(name: String) -> ImageResource? {
        switch name {
        case "avocado": .avocado
        case "baby_bottle": .babyBottle
        case "bacon": .bacon
        case "bagel": .bagel
        case "banana": .banana
        case "beans": .beans
        case "beer_mug": .beerMug
        case "bell_pepper": .bellPepper
        case "bento_box": .bentoBox
        case "beverage_box": .beverageBox
        case "birthday_cake": .birthdayCake
        case "blueberries": .blueberries
        case "bottle_with_popping_cork": .bottleWithPoppingCork
        case "bowl_with_spoon": .bowlWithSpoon
        case "bread": .bread
        case "broccoli": .broccoli
        case "bubble_tea": .bubbleTea
        case "burrito": .burrito
        case "butter": .butter
        case "carrot": .carrot
        case "cheese_wedge": .cheeseWedge
        case "cherries": .cherries
        case "chestnut": .chestnut
        case "chocolate_bar": .chocolateBar
        case "chopsticks": .chopsticks
        case "clinking_beer_mugs": .clinkingBeerMugs
        case "clinking_glasses": .clinkingGlasses
        case "cocktail_glass": .cocktailGlass
        case "coconut": .coconut
        case "cooked_rice": .cookedRice
        case "cookie": .cookie
        case "cooking": .cooking
        case "croissant": .croissant
        case "cucumber": .cucumber
        case "cup_with_straw": .cupWithStraw
        case "cupcake": .cupcake
        case "curry_rice": .curryRice
        case "custard": .custard
        case "cut_of_meat": .cutOfMeat
        case "dango": .dango
        case "doughnut": .doughnut
        case "dumpling": .dumpling
        case "ear_of_corn": .earOfCorn
        case "egg": .egg
        case "falafel": .falafel
        case "fish_cake_with_swirl": .fishCakeWithSwirl
        case "flatbread": .flatbread
        case "fondue": .fondue
        case "fork_and_knife": .forkAndKnife
        case "fortune_cookie": .fortuneCookie
        case "french_fries": .frenchFries
        case "fried_shrimp": .friedShrimp
        case "garlic": .garlic
        case "glass_of_milk": .glassOfMilk
        case "grapes": .grapes
        case "green_apple": .greenApple
        case "green_salad": .greenSalad
        case "hamburger": .hamburger
        case "hot_beverage": .hotBeverage
        case "hot_dog": .hotDog
        case "hot_pepper": .hotPepper
        case "kiwi_fruit": .kiwiFruit
        case "leafy_green": .leafyGreen
        case "lemon": .lemon
        case "mango": .mango
        case "mate": .mate
        case "meat_on_bone": .meatOnBone
        case "melon": .melon
        case "moon_cake": .moonCake
        case "oden": .oden
        case "olive": .olive
        case "onion": .onion
        case "pancakes": .pancakes
        case "peach": .peach
        case "peanuts": .peanuts
        case "pear": .pear
        case "pie": .pie
        case "pineapple": .pineapple
        case "popcorn": .popcorn
        case "pot_of_food": .potOfFood
        case "potato": .potato
        case "poultry_leg": .poultryLeg
        case "pretzel": .pretzel
        case "red_apple": .redApple
        case "rice_ball": .riceBall
        case "rice_cracker": .riceCracker
        case "roasted_sweet_potato": .roastedSweetPotato
        case "sake": .sake
        case "salt": .salt
        case "sandwich": .sandwich
        case "shallow_pan_of_food": .shallowPanOfFood
        case "shaved_ice": .shavedIce
        case "shortcake": .shortcake
        case "soft_ice_cream": .softIceCream
        case "spaghetti": .spaghetti
        case "steaming_bowl": .steamingBowl
        case "strawberry": .strawberry
        case "stuffed_flatbread": .stuffedFlatbread
        case "sushi": .sushi
        case "taco": .taco
        case "tamale": .tamale
        case "tangerine": .tangerine
        case "teacup_without_handle": .teacupWithoutHandle
        case "tomato": .tomato
        case "tropical_drink": .tropicalDrink
        case "tumbler_glass": .tumblerGlass
        case "waffle": .waffle
        case "watermelon": .watermelon
        case "wine_glass": .wineGlass
        default: nil
        }
    }

    static func FlagsTwemote(name: String) -> ImageResource? {
        switch name {
        case "anarchocapitalism_flag": .anarchocapitalismFlag
        case "antifa_flag": .antifaFlag
        case "black_flag": .blackFlag
        case "communism_flag": .communismFlag
        case "flag_afghanistan": .flagAfghanistan
        case "flag_aland_islands": .flagAlandIslands
        case "flag_albania": .flagAlbania
        case "flag_algeria": .flagAlgeria
        case "flag_american_samoa": .flagAmericanSamoa
        case "flag_andorra": .flagAndorra
        case "flag_angola": .flagAngola
        case "flag_anguilla": .flagAnguilla
        case "flag_antarctica": .flagAntarctica
        case "flag_antigua_barbuda": .flagAntiguaBarbuda
        case "flag_argentina": .flagArgentina
        case "flag_armenia": .flagArmenia
        case "flag_aruba": .flagAruba
        case "flag_ascension_island": .flagAscensionIsland
        case "flag_australia": .flagAustralia
        case "flag_austria": .flagAustria
        case "flag_azerbaijan": .flagAzerbaijan
        case "flag_bahamas": .flagBahamas
        case "flag_bahrain": .flagBahrain
        case "flag_bangladesh": .flagBangladesh
        case "flag_barbados": .flagBarbados
        case "flag_belarus": .flagBelarus
        case "flag_belgium": .flagBelgium
        case "flag_belize": .flagBelize
        case "flag_benin": .flagBenin
        case "flag_bermuda": .flagBermuda
        case "flag_bhutan": .flagBhutan
        case "flag_bolivia": .flagBolivia
        case "flag_bosnia_herzegovina": .flagBosniaHerzegovina
        case "flag_botswana": .flagBotswana
        case "flag_bouvet_island": .flagBouvetIsland
        case "flag_brazil": .flagBrazil
        case "flag_british_indian_ocean_territory": .flagBritishIndianOceanTerritory
        case "flag_british_virgin_islands": .flagBritishVirginIslands
        case "flag_brunei": .flagBrunei
        case "flag_bulgaria": .flagBulgaria
        case "flag_burkina_faso": .flagBurkinaFaso
        case "flag_burundi": .flagBurundi
        case "flag_cambodia": .flagCambodia
        case "flag_cameroon": .flagCameroon
        case "flag_canada": .flagCanada
        case "flag_canary_islands": .flagCanaryIslands
        case "flag_cape_verde": .flagCapeVerde
        case "flag_caribbean_netherlands": .flagCaribbeanNetherlands
        case "flag_cayman_islands": .flagCaymanIslands
        case "flag_central_african_republic": .flagCentralAfricanRepublic
        case "flag_ceuta_melilla": .flagCeutaMelilla
        case "flag_chad": .flagChad
        case "flag_chile": .flagChile
        case "flag_china": .flagChina
        case "flag_christmas_island": .flagChristmasIsland
        case "flag_clipperton_island": .flagClippertonIsland
        case "flag_cocos_keeling_islands": .flagCocosKeelingIslands
        case "flag_colombia": .flagColombia
        case "flag_comoros": .flagComoros
        case "flag_congo_brazzaville": .flagCongoBrazzaville
        case "flag_congo_kinshasa": .flagCongoKinshasa
        case "flag_cook_islands": .flagCookIslands
        case "flag_costa_rica": .flagCostaRica
        case "flag_cote_divoire": .flagCoteDivoire
        case "flag_croatia": .flagCroatia
        case "flag_cuba": .flagCuba
        case "flag_curacao": .flagCuracao
        case "flag_cyprus": .flagCyprus
        case "flag_czechia": .flagCzechia
        case "flag_denmark": .flagDenmark
        case "flag_diego_garcia": .flagDiegoGarcia
        case "flag_djibouti": .flagDjibouti
        case "flag_dominica": .flagDominica
        case "flag_dominican_republic": .flagDominicanRepublic
        case "flag_ecuador": .flagEcuador
        case "flag_egypt": .flagEgypt
        case "flag_el_salvador": .flagElSalvador
        case "flag_england": .flagEngland
        case "flag_equatorial_guinea": .flagEquatorialGuinea
        case "flag_eritrea": .flagEritrea
        case "flag_estonia": .flagEstonia
        case "flag_eswatini": .flagEswatini
        case "flag_ethiopia": .flagEthiopia
        case "flag_european_union": .flagEuropeanUnion
        case "flag_falkland_islands": .flagFalklandIslands
        case "flag_faroe_islands": .flagFaroeIslands
        case "flag_fiji": .flagFiji
        case "flag_finland": .flagFinland
        case "flag_france": .flagFrance
        case "flag_french_guiana": .flagFrenchGuiana
        case "flag_french_polynesia": .flagFrenchPolynesia
        case "flag_french_southern_territories": .flagFrenchSouthernTerritories
        case "flag_gabon": .flagGabon
        case "flag_gambia": .flagGambia
        case "flag_georgia": .flagGeorgia
        case "flag_germany": .flagGermany
        case "flag_ghana": .flagGhana
        case "flag_gibraltar": .flagGibraltar
        case "flag_greece": .flagGreece
        case "flag_greenland": .flagGreenland
        case "flag_grenada": .flagGrenada
        case "flag_guadeloupe": .flagGuadeloupe
        case "flag_guam": .flagGuam
        case "flag_guatemala": .flagGuatemala
        case "flag_guernsey": .flagGuernsey
        case "flag_guinea": .flagGuinea
        case "flag_guinea_bissau": .flagGuineaBissau
        case "flag_guyana": .flagGuyana
        case "flag_haiti": .flagHaiti
        case "flag_heard_mcdonald_islands": .flagHeardMcdonaldIslands
        case "flag_honduras": .flagHonduras
        case "flag_hong_kong_sar_china": .flagHongKongSarChina
        case "flag_hungary": .flagHungary
        case "flag_iceland": .flagIceland
        case "flag_india": .flagIndia
        case "flag_indonesia": .flagIndonesia
        case "flag_iran": .flagIran
        case "flag_iraq": .flagIraq
        case "flag_ireland": .flagIreland
        case "flag_isle_of_man": .flagIsleOfMan
        case "flag_israel": .flagIsrael
        case "flag_italy": .flagItaly
        case "flag_jamaica": .flagJamaica
        case "flag_japan": .flagJapan
        case "flag_jersey": .flagJersey
        case "flag_jordan": .flagJordan
        case "flag_kazakhstan": .flagKazakhstan
        case "flag_kenya": .flagKenya
        case "flag_kiribati": .flagKiribati
        case "flag_kosovo": .flagKosovo
        case "flag_kuwait": .flagKuwait
        case "flag_kyrgyzstan": .flagKyrgyzstan
        case "flag_laos": .flagLaos
        case "flag_latvia": .flagLatvia
        case "flag_lebanon": .flagLebanon
        case "flag_lesotho": .flagLesotho
        case "flag_liberia": .flagLiberia
        case "flag_libya": .flagLibya
        case "flag_liechtenstein": .flagLiechtenstein
        case "flag_lithuania": .flagLithuania
        case "flag_luxembourg": .flagLuxembourg
        case "flag_macao_sar_china": .flagMacaoSarChina
        case "flag_madagascar": .flagMadagascar
        case "flag_malawi": .flagMalawi
        case "flag_malaysia": .flagMalaysia
        case "flag_maldives": .flagMaldives
        case "flag_mali": .flagMali
        case "flag_malta": .flagMalta
        case "flag_marshall_islands": .flagMarshallIslands
        case "flag_martinique": .flagMartinique
        case "flag_mauritania": .flagMauritania
        case "flag_mauritius": .flagMauritius
        case "flag_mayotte": .flagMayotte
        case "flag_mexico": .flagMexico
        case "flag_micronesia": .flagMicronesia
        case "flag_moldova": .flagMoldova
        case "flag_monaco": .flagMonaco
        case "flag_mongolia": .flagMongolia
        case "flag_montenegro": .flagMontenegro
        case "flag_montserrat": .flagMontserrat
        case "flag_morocco": .flagMorocco
        case "flag_mozambique": .flagMozambique
        case "flag_myanmar_burma": .flagMyanmarBurma
        case "flag_namibia": .flagNamibia
        case "flag_nauru": .flagNauru
        case "flag_nepal": .flagNepal
        case "flag_netherlands": .flagNetherlands
        case "flag_new_caledonia": .flagNewCaledonia
        case "flag_new_zealand": .flagNewZealand
        case "flag_nicaragua": .flagNicaragua
        case "flag_niger": .flagNiger
        case "flag_nigeria": .flagNigeria
        case "flag_niue": .flagNiue
        case "flag_norfolk_island": .flagNorfolkIsland
        case "flag_north_korea": .flagNorthKorea
        case "flag_north_macedonia": .flagNorthMacedonia
        case "flag_northern_mariana_islands": .flagNorthernMarianaIslands
        case "flag_norway": .flagNorway
        case "flag_oman": .flagOman
        case "flag_pakistan": .flagPakistan
        case "flag_palau": .flagPalau
        case "flag_palestinian_territories": .flagPalestinianTerritories
        case "flag_panama": .flagPanama
        case "flag_papua_new_guinea": .flagPapuaNewGuinea
        case "flag_paraguay": .flagParaguay
        case "flag_peru": .flagPeru
        case "flag_philippines": .flagPhilippines
        case "flag_pitcairn_islands": .flagPitcairnIslands
        case "flag_poland": .flagPoland
        case "flag_portugal": .flagPortugal
        case "flag_puerto_rico": .flagPuertoRico
        case "flag_qatar": .flagQatar
        case "flag_reunion": .flagReunion
        case "flag_romania": .flagRomania
        case "flag_russia": .flagRussia
        case "flag_rwanda": .flagRwanda
        case "flag_samoa": .flagSamoa
        case "flag_san_marino": .flagSanMarino
        case "flag_sao_tome_principe": .flagSaoTomePrincipe
        case "flag_saudi_arabia": .flagSaudiArabia
        case "flag_scotland": .flagScotland
        case "flag_senegal": .flagSenegal
        case "flag_serbia": .flagSerbia
        case "flag_seychelles": .flagSeychelles
        case "flag_sierra_leone": .flagSierraLeone
        case "flag_singapore": .flagSingapore
        case "flag_sint_maarten": .flagSintMaarten
        case "flag_slovakia": .flagSlovakia
        case "flag_slovenia": .flagSlovenia
        case "flag_solomon_islands": .flagSolomonIslands
        case "flag_somalia": .flagSomalia
        case "flag_south_africa": .flagSouthAfrica
        case "flag_south_georgia_south_sandwich_islands": .flagSouthGeorgiaSouthSandwichIslands
        case "flag_south_korea": .flagSouthKorea
        case "flag_south_sudan": .flagSouthSudan
        case "flag_spain": .flagSpain
        case "flag_sri_lanka": .flagSriLanka
        case "flag_st_barthelemy": .flagStBarthelemy
        case "flag_st_helena": .flagStHelena
        case "flag_st_kitts_nevis": .flagStKittsNevis
        case "flag_st_lucia": .flagStLucia
        case "flag_st_martin": .flagStMartin
        case "flag_st_pierre_miquelon": .flagStPierreMiquelon
        case "flag_st_vincent_grenadines": .flagStVincentGrenadines
        case "flag_sudan": .flagSudan
        case "flag_suriname": .flagSuriname
        case "flag_svalbard_jan_mayen": .flagSvalbardJanMayen
        case "flag_sweden": .flagSweden
        case "flag_switzerland": .flagSwitzerland
        case "flag_syria": .flagSyria
        case "flag_taiwan": .flagTaiwan
        case "flag_tajikistan": .flagTajikistan
        case "flag_tanzania": .flagTanzania
        case "flag_thailand": .flagThailand
        case "flag_tibet": .flagTibet
        case "flag_timor_leste": .flagTimorLeste
        case "flag_togo": .flagTogo
        case "flag_tokelau": .flagTokelau
        case "flag_tonga": .flagTonga
        case "flag_trinidad_tobago": .flagTrinidadTobago
        case "flag_tristan_da_cunha": .flagTristanDaCunha
        case "flag_tunisia": .flagTunisia
        case "flag_turkey": .flagTurkey
        case "flag_turkmenistan": .flagTurkmenistan
        case "flag_turks_caicos_islands": .flagTurksCaicosIslands
        case "flag_tuvalu": .flagTuvalu
        case "flag_uganda": .flagUganda
        case "flag_ukraine": .flagUkraine
        case "flag_united_arab_emirates": .flagUnitedArabEmirates
        case "flag_united_kingdom": .flagUnitedKingdom
        case "flag_united_nations": .flagUnitedNations
        case "flag_united_states": .flagUnitedStates
        case "flag_uruguay": .flagUruguay
        case "flag_us_virgin_islands": .flagUsVirginIslands
        case "flag_uzbekistan": .flagUzbekistan
        case "flag_vanuatu": .flagVanuatu
        case "flag_vatican_city": .flagVaticanCity
        case "flag_venezuela": .flagVenezuela
        case "flag_vietnam": .flagVietnam
        case "flag_wales": .flagWales
        case "flag_wallis_futuna": .flagWallisFutuna
        case "flag_western_sahara": .flagWesternSahara
        case "flag_yemen": .flagYemen
        case "flag_zambia": .flagZambia
        case "flag_zimbabwe": .flagZimbabwe
        case "gadsden_flag": .gadsdenFlag
        case "kek_flag": .kekFlag
        case "pirate_flag": .pirateFlag
        case "rainbow_flag": .rainbowFlag
        case "transgender_flag": .transgenderFlag
        case "white_flag": .whiteFlag
        default: nil
        }
    }
}
