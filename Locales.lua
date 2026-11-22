local _, ns = ...

-- UI strings. Build texts live in Data\*.lua as { en = ..., ru = ... } pairs.
local strings = {
	en = {
		TITLE = "Talent Compass",
		BUILDS_BUTTON = "Builds",
		BUILDS_BUTTON_TOOLTIP = "Show or hide the Talent Compass build guide.",
		CHOOSE_BUILD = "Builds",
		TAB_TALENTS = "Talents",
		TAB_ROTATION = "Rotation",
		TAB_GEAR = "Stats & Gear",
		TAB_TIPS = "Tips",
		NEXT_TALENT = "Next talent",
		BUILD_DONE = "Build complete! All 51 points follow the guide.",
		PROGRESS = "Build progress: %d / %d",
		UNSPENT = "Unspent points: %d",
		NO_UNSPENT = "No unspent points — the next talent unlocks at level %d.",
		ORDER = "Point order",
		LEVEL_SHORT = "Lv %d",
		OFF_BUILD = "Points outside this build",
		OFF_BUILD_HINT = "These ranks are not part of the guide. Reset talents if you want to follow it exactly.",
		MISSING = "Not found in this game version: %s",
		HIGHLIGHT = "Highlight on talent tree",
		CHAT_HINTS = "Chat hint when a point is available",
		LANGUAGE = "Language",
		LANG_AUTO = "Game language",
		ROTATION = "Rotation / priority",
		STATS = "Stat priority",
		GEAR = "Gear",
		TIPS = "Tips",
		ABOUT_CLASS = "What changed in Forever",
		ROLE_DPS = "Damage",
		ROLE_TANK = "Tank",
		ROLE_HEAL = "Healer",
		ROLE_LEVELING = "Leveling",
		NO_DATA = "No builds for your class yet.",
		NEXT_BADGE = "NEXT",
		AUTO_PICKED = "Picked the build closest to your current talents: |cffffd100%s|r (%d%% match). Change it in the talent window.",
		MATCH = "%d%% match",
		CHAT_NEXT = "Talent point available — next for |cffffd100%s|r: %s (%d/%d).",
		SLASH_HELP = "/tc — toggle panel, /tc dump — save this class's talent list to SavedVariables, /tc reset — reset panel position",
		DUMP_DONE = "Saved %d talents to TalentCompassDB.dump. /reload to write the file.",
		TREE_NOT_READY = "Talent data is not available yet. Open the talent window once.",
		DATA_NOTE = "Static guide data for WoW Forever 1.60.1. Verify against current patch notes.",
	},
	ru = {
		TITLE = "Talent Compass",
		BUILDS_BUTTON = "Билды",
		BUILDS_BUTTON_TOOLTIP = "Показать или скрыть гайд по билдам Talent Compass.",
		CHOOSE_BUILD = "Билды",
		TAB_TALENTS = "Таланты",
		TAB_ROTATION = "Ротация",
		TAB_GEAR = "Статы и экипировка",
		TAB_TIPS = "Советы",
		NEXT_TALENT = "Следующий талант",
		BUILD_DONE = "Билд собран! Все 51 очко распределены по гайду.",
		PROGRESS = "Прогресс билда: %d / %d",
		UNSPENT = "Свободных очков: %d",
		NO_UNSPENT = "Свободных очков нет — следующий талант откроется на %d уровне.",
		ORDER = "Порядок прокачки",
		LEVEL_SHORT = "%d ур.",
		OFF_BUILD = "Очки вне билда",
		OFF_BUILD_HINT = "Эти ранги не входят в гайд. Сбросьте таланты, если хотите следовать ему точно.",
		MISSING = "Не найдено в этой версии игры: %s",
		HIGHLIGHT = "Подсвечивать на дереве талантов",
		CHAT_HINTS = "Подсказка в чате, когда есть свободное очко",
		LANGUAGE = "Язык",
		LANG_AUTO = "Язык игры",
		ROTATION = "Ротация / приоритет",
		STATS = "Приоритет характеристик",
		GEAR = "Экипировка",
		TIPS = "Советы",
		ABOUT_CLASS = "Что изменилось в Forever",
		ROLE_DPS = "Урон",
		ROLE_TANK = "Танк",
		ROLE_HEAL = "Лекарь",
		ROLE_LEVELING = "Прокачка",
		NO_DATA = "Для вашего класса пока нет билдов.",
		NEXT_BADGE = "ДАЛЕЕ",
		AUTO_PICKED = "Выбран билд, ближе всего к вашим текущим талантам: |cffffd100%s|r (совпадение %d%%). Сменить можно в окне талантов.",
		MATCH = "совпадение %d%%",
		CHAT_NEXT = "Есть очко таланта — следующий по билду |cffffd100%s|r: %s (%d/%d).",
		SLASH_HELP = "/tc — показать панель, /tc dump — сохранить список талантов класса в SavedVariables, /tc reset — сбросить положение панели",
		DUMP_DONE = "Сохранено талантов: %d в TalentCompassDB.dump. Сделайте /reload, чтобы записать файл.",
		TREE_NOT_READY = "Данные талантов ещё недоступны. Откройте окно талантов хотя бы раз.",
		DATA_NOTE = "Статичные данные гайда для WoW Forever 1.60.1. Сверяйтесь с актуальными патчноутами.",
	},
}

ns.strings = strings

function ns.GetLanguage()
	local setting = TalentCompassDB and TalentCompassDB.lang or "auto"
	if setting == "en" or setting == "ru" then
		return setting
	end
	return GetLocale() == "ruRU" and "ru" or "en"
end

-- ns.L.KEY resolves against the active language with English fallback.
ns.L = setmetatable({}, {
	__index = function(_, key)
		local lang = ns.GetLanguage()
		return strings[lang][key] or strings.en[key] or key
	end,
})

-- Picks the right language out of a { en = ..., ru = ... } table (or returns plain values as-is).
function ns.T(value)
	if type(value) ~= "table" then
		return value
	end
	if value.en == nil and value.ru == nil then
		return value
	end
	local lang = ns.GetLanguage()
	return value[lang] or value.en
end
