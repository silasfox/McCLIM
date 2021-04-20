(in-package #:mcclim-harfbuzz)

(pkg-config-cflags "harfbuzz")
(pkg-config-cflags "freetype2")

(include "hb.h")
(include "hb-ft.h")

(ctype uint32-t "uint32_t")
(ctype hb-codepoint-t "hb_codepoint_t")
(ctype hb-mask-t "hb_mask_t")
(ctype hb-position-t "hb_position_t")
(ctype hb-tag-t "hb_tag_t")

(cenum (hb-direction-t)
       ((:hb-direction-invalid "HB_DIRECTION_INVALID"))
       ((:hb-direction-ltr "HB_DIRECTION_LTR"))
       ((:hb-direction-rtl "HB_DIRECTION_RTL"))
       ((:hb-direction-ttb "HB_DIRECTION_TTB"))
       ((:hb-direction-btt "HB_DIRECTION_BTT")))

(cenum (hb-script-t)
       ((:hb-script-common "HB_SCRIPT_COMMON"))
       ((:hb-script-inherited "HB_SCRIPT_INHERITED"))
       ((:hb-script-unknown "HB_SCRIPT_UNKNOWN"))
       ((:hb-script-arabic "HB_SCRIPT_ARABIC"))
       ((:hb-script-armenian "HB_SCRIPT_ARMENIAN"))
       ((:hb-script-bengali "HB_SCRIPT_BENGALI"))
       ((:hb-script-cyrillic "HB_SCRIPT_CYRILLIC"))
       ((:hb-script-devanagari "HB_SCRIPT_DEVANAGARI"))
       ((:hb-script-georgian "HB_SCRIPT_GEORGIAN"))
       ((:hb-script-greek "HB_SCRIPT_GREEK"))
       ((:hb-script-gujarati "HB_SCRIPT_GUJARATI"))
       ((:hb-script-gurmukhi "HB_SCRIPT_GURMUKHI"))
       ((:hb-script-hangul "HB_SCRIPT_HANGUL"))
       ((:hb-script-han "HB_SCRIPT_HAN"))
       ((:hb-script-hebrew "HB_SCRIPT_HEBREW"))
       ((:hb-script-hiragana "HB_SCRIPT_HIRAGANA"))
       ((:hb-script-kannada "HB_SCRIPT_KANNADA"))
       ((:hb-script-katakana "HB_SCRIPT_KATAKANA"))
       ((:hb-script-lao "HB_SCRIPT_LAO"))
       ((:hb-script-latin "HB_SCRIPT_LATIN"))
       ((:hb-script-malayalam "HB_SCRIPT_MALAYALAM"))
       ((:hb-script-oriya "HB_SCRIPT_ORIYA"))
       ((:hb-script-tamil "HB_SCRIPT_TAMIL"))
       ((:hb-script-telugu "HB_SCRIPT_TELUGU"))
       ((:hb-script-thai "HB_SCRIPT_THAI"))
       ((:hb-script-tibetan "HB_SCRIPT_TIBETAN"))
       ((:hb-script-bopomofo "HB_SCRIPT_BOPOMOFO"))
       ((:hb-script-braille "HB_SCRIPT_BRAILLE"))
       ((:hb-script-canadian-syllabics "HB_SCRIPT_CANADIAN_SYLLABICS"))
       ((:hb-script-cherokee "HB_SCRIPT_CHEROKEE"))
       ((:hb-script-ethiopic "HB_SCRIPT_ETHIOPIC"))
       ((:hb-script-khmer "HB_SCRIPT_KHMER"))
       ((:hb-script-mongolian "HB_SCRIPT_MONGOLIAN"))
       ((:hb-script-myanmar "HB_SCRIPT_MYANMAR"))
       ((:hb-script-ogham "HB_SCRIPT_OGHAM"))
       ((:hb-script-runic "HB_SCRIPT_RUNIC"))
       ((:hb-script-sinhala "HB_SCRIPT_SINHALA"))
       ((:hb-script-syriac "HB_SCRIPT_SYRIAC"))
       ((:hb-script-thaana "HB_SCRIPT_THAANA"))
       ((:hb-script-yi "HB_SCRIPT_YI"))
       ((:hb-script-deseret "HB_SCRIPT_DESERET"))
       ((:hb-script-gothic "HB_SCRIPT_GOTHIC"))
       ((:hb-script-old-italic "HB_SCRIPT_OLD_ITALIC"))
       ((:hb-script-buhid "HB_SCRIPT_BUHID"))
       ((:hb-script-hanunoo "HB_SCRIPT_HANUNOO"))
       ((:hb-script-tagalog "HB_SCRIPT_TAGALOG"))
       ((:hb-script-tagbanwa "HB_SCRIPT_TAGBANWA"))
       ((:hb-script-cypriot "HB_SCRIPT_CYPRIOT"))
       ((:hb-script-limbu "HB_SCRIPT_LIMBU"))
       ((:hb-script-linear-b "HB_SCRIPT_LINEAR_B"))
       ((:hb-script-osmanya "HB_SCRIPT_OSMANYA"))
       ((:hb-script-shavian "HB_SCRIPT_SHAVIAN"))
       ((:hb-script-tai-le "HB_SCRIPT_TAI_LE"))
       ((:hb-script-ugaritic "HB_SCRIPT_UGARITIC"))
       ((:hb-script-buginese "HB_SCRIPT_BUGINESE"))
       ((:hb-script-coptic "HB_SCRIPT_COPTIC"))
       ((:hb-script-glagolitic "HB_SCRIPT_GLAGOLITIC"))
       ((:hb-script-kharoshthi "HB_SCRIPT_KHAROSHTHI"))
       ((:hb-script-new-tai-lue "HB_SCRIPT_NEW_TAI_LUE"))
       ((:hb-script-old-persian "HB_SCRIPT_OLD_PERSIAN"))
       ((:hb-script-syloti-nagri "HB_SCRIPT_SYLOTI_NAGRI"))
       ((:hb-script-tifinagh "HB_SCRIPT_TIFINAGH"))
       ((:hb-script-balinese "HB_SCRIPT_BALINESE"))
       ((:hb-script-cuneiform "HB_SCRIPT_CUNEIFORM"))
       ((:hb-script-nko "HB_SCRIPT_NKO"))
       ((:hb-script-phags-pa "HB_SCRIPT_PHAGS_PA"))
       ((:hb-script-phoenician "HB_SCRIPT_PHOENICIAN"))
       ((:hb-script-carian "HB_SCRIPT_CARIAN"))
       ((:hb-script-cham "HB_SCRIPT_CHAM"))
       ((:hb-script-kayah-li "HB_SCRIPT_KAYAH_LI"))
       ((:hb-script-lepcha "HB_SCRIPT_LEPCHA"))
       ((:hb-script-lycian "HB_SCRIPT_LYCIAN"))
       ((:hb-script-lydian "HB_SCRIPT_LYDIAN"))
       ((:hb-script-ol-chiki "HB_SCRIPT_OL_CHIKI"))
       ((:hb-script-rejang "HB_SCRIPT_REJANG"))
       ((:hb-script-saurashtra "HB_SCRIPT_SAURASHTRA"))
       ((:hb-script-sundanese "HB_SCRIPT_SUNDANESE"))
       ((:hb-script-vai "HB_SCRIPT_VAI"))
       ((:hb-script-avestan "HB_SCRIPT_AVESTAN"))
       ((:hb-script-bamum "HB_SCRIPT_BAMUM"))
       ((:hb-script-egyptian-hieroglyphs "HB_SCRIPT_EGYPTIAN_HIEROGLYPHS"))
       ((:hb-script-imperial-aramaic "HB_SCRIPT_IMPERIAL_ARAMAIC"))
       ((:hb-script-inscriptional-pahlavi "HB_SCRIPT_INSCRIPTIONAL_PAHLAVI"))
       ((:hb-script-inscriptional-parthian "HB_SCRIPT_INSCRIPTIONAL_PARTHIAN"))
       ((:hb-script-javanese "HB_SCRIPT_JAVANESE"))
       ((:hb-script-kaithi "HB_SCRIPT_KAITHI"))
       ((:hb-script-lisu "HB_SCRIPT_LISU"))
       ((:hb-script-meetei-mayek "HB_SCRIPT_MEETEI_MAYEK"))
       ((:hb-script-old-south-arabian "HB_SCRIPT_OLD_SOUTH_ARABIAN"))
       ((:hb-script-old-turkic "HB_SCRIPT_OLD_TURKIC"))
       ((:hb-script-samaritan "HB_SCRIPT_SAMARITAN"))
       ((:hb-script-tai-tham "HB_SCRIPT_TAI_THAM"))
       ((:hb-script-tai-viet "HB_SCRIPT_TAI_VIET"))
       ((:hb-script-batak "HB_SCRIPT_BATAK"))
       ((:hb-script-brahmi "HB_SCRIPT_BRAHMI"))
       ((:hb-script-mandaic "HB_SCRIPT_MANDAIC"))
       ((:hb-script-chakma "HB_SCRIPT_CHAKMA"))
       ((:hb-script-meroitic-cursive "HB_SCRIPT_MEROITIC_CURSIVE"))
       ((:hb-script-meroitic-hieroglyphs "HB_SCRIPT_MEROITIC_HIEROGLYPHS"))
       ((:hb-script-miao "HB_SCRIPT_MIAO"))
       ((:hb-script-sharada "HB_SCRIPT_SHARADA"))
       ((:hb-script-sora-sompeng "HB_SCRIPT_SORA_SOMPENG"))
       ((:hb-script-takri "HB_SCRIPT_TAKRI"))
       ((:hb-script-bassa-vah "HB_SCRIPT_BASSA_VAH"))
       ((:hb-script-caucasian-albanian "HB_SCRIPT_CAUCASIAN_ALBANIAN"))
       ((:hb-script-duployan "HB_SCRIPT_DUPLOYAN"))
       ((:hb-script-elbasan "HB_SCRIPT_ELBASAN"))
       ((:hb-script-grantha "HB_SCRIPT_GRANTHA"))
       ((:hb-script-khojki "HB_SCRIPT_KHOJKI"))
       ((:hb-script-khudawadi "HB_SCRIPT_KHUDAWADI"))
       ((:hb-script-linear-a "HB_SCRIPT_LINEAR_A"))
       ((:hb-script-mahajani "HB_SCRIPT_MAHAJANI"))
       ((:hb-script-manichaean "HB_SCRIPT_MANICHAEAN"))
       ((:hb-script-mende-kikakui "HB_SCRIPT_MENDE_KIKAKUI"))
       ((:hb-script-modi "HB_SCRIPT_MODI"))
       ((:hb-script-mro "HB_SCRIPT_MRO"))
       ((:hb-script-nabataean "HB_SCRIPT_NABATAEAN"))
       ((:hb-script-old-north-arabian "HB_SCRIPT_OLD_NORTH_ARABIAN"))
       ((:hb-script-old-permic "HB_SCRIPT_OLD_PERMIC"))
       ((:hb-script-pahawh-hmong "HB_SCRIPT_PAHAWH_HMONG"))
       ((:hb-script-palmyrene "HB_SCRIPT_PALMYRENE"))
       ((:hb-script-pau-cin-hau "HB_SCRIPT_PAU_CIN_HAU"))
       ((:hb-script-psalter-pahlavi "HB_SCRIPT_PSALTER_PAHLAVI"))
       ((:hb-script-siddham "HB_SCRIPT_SIDDHAM"))
       ((:hb-script-tirhuta "HB_SCRIPT_TIRHUTA"))
       ((:hb-script-warang-citi "HB_SCRIPT_WARANG_CITI"))
       ((:hb-script-ahom "HB_SCRIPT_AHOM"))
       ((:hb-script-anatolian-hieroglyphs "HB_SCRIPT_ANATOLIAN_HIEROGLYPHS"))
       ((:hb-script-hatran "HB_SCRIPT_HATRAN"))
       ((:hb-script-multani "HB_SCRIPT_MULTANI"))
       ((:hb-script-old-hungarian "HB_SCRIPT_OLD_HUNGARIAN"))
       ((:hb-script-signwriting "HB_SCRIPT_SIGNWRITING"))
       ((:hb-script-adlam "HB_SCRIPT_ADLAM"))
       ((:hb-script-bhaiksuki "HB_SCRIPT_BHAIKSUKI"))
       ((:hb-script-marchen "HB_SCRIPT_MARCHEN"))
       ((:hb-script-osage "HB_SCRIPT_OSAGE"))
       ((:hb-script-tangut "HB_SCRIPT_TANGUT"))
       ((:hb-script-newa "HB_SCRIPT_NEWA"))
       ((:hb-script-invalid "HB_SCRIPT_INVALID")))

(cenum (hb-buffer-cluster-level-t)
       ((:hb-buffer-cluster-level-monotone-graphemes "HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES"))
       ((:hb-buffer-cluster-level-monotone-characters "HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS"))
       ((:hb-buffer-cluster-level-characters "HB_BUFFER_CLUSTER_LEVEL_CHARACTERS"))
       ((:hb-buffer-cluster-level-default "HB_BUFFER_CLUSTER_LEVEL_DEFAULT")))

(cstruct hb-glyph-info-t "hb_glyph_info_t"
         (codepoint "codepoint" :type hb-codepoint-t)
         (mask "mask" :type hb-mask-t)
         (cluster "cluster" :type uint32-t))

(cstruct hb-glyph-position-t "hb_glyph_position_t"
         (x-advance "x_advance" :type hb-position-t)
         (y-advance "y_advance" :type hb-position-t)
         (x-offset "x_offset" :type hb-position-t)
         (y-offset "y_offset" :type hb-position-t))

(cstruct hb-feature-t "hb_feature_t"
         (tag "tag" :type hb-tag-t)
         (value "value" :type uint32-t)
         (start "start" :type :unsigned-int)
         (end "end" :type :unsigned-int))
