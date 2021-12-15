-- Word Buster Configuration --
wordBuster = {}

-- Censor: Which character should be used to replace bad words?
wordBuster.censor = "*"

-- Semi Censor: Show the first and last character of bad words?
wordBuster.semiCensor = false

-- Languages: Which languages should be loaded?
wordBuster.languages = {
	["cs"] = false,
	["da"] = false,
	["de"] = false,
	["en"] = true,
	["eo"] = false,
	["es"] = false,
	["fr"] = false,
	["hu"] = false,
	["it"] = false,
	["ja"] = false,
	["ko"] = false,
	["nl"] = false,
	["no"] = false,
	["pl"] = false,
	["pt"] = false,
	["ru"] = false,
	["sv"] = false,
	["th"] = false,
	["tlh"] = false,
	["tr"] = false,
	["zh"] = false
}

-- Notify: Notify the user that one of his words was censored.
wordBuster.notify = true

-- Notify Text: Text to notify the user with.
wordBuster.notifyText = "Please watch your language!"

-- Patterns: Advanced users only, patterns used to block variations of bad words.
wordBuster.patterns = {
	["a"] = "[aA@]",
	["b"] = "[bB]",
	["c"] = "[cCkK]",
	["d"] = "[dD]",
	["e"] = "[eE3]",
	["f"] = "[fF]",
	["g"] = "[gG6]",
	["h"] = "[hH]",
	["i"] = "[iIl!1]",
	["j"] = "[jJ]",
	["k"] = "[cCkK]",
	["l"] = "[lL1!i]",
	["m"] = "[mM]",
	["n"] = "[nN]",
	["o"] = "[oO0]",
	["p"] = "[pP]",
	["q"] = "[qQ9]",
	["r"] = "[rR]",
	["s"] = "[sS$5]",
	["t"] = "[tT7]",
	["u"] = "[uUvV]",
	["v"] = "[vVuU]",
	["w"] = "[wW]",
	["x"] = "[xX]",
	["y"] = "[yY]",
	["z"] = "[zZ2]"
}

-- Word Buster Base of Operations --
wordBuster.badWords = wordBuster.badWords or {}

function wordBuster.Load()
	print("[Word Buster] Loading languages...\n")
	wordBuster.badWords = {}
	for lang, load in pairs(wordBuster.languages) do
		if load then
			local f = io.open(".\\wordbuster\\data\\wordbuster\\"..lang..".txt", "r")
			if f~=nil then
				for word in f:lines() do
					local formatedWord = ""
					local tbl = {}
					word:gsub(".",function(c) table.insert(tbl,c) end)
					for chr=1,#tbl do
						if wordBuster.patterns[tbl[chr]] then
							formatedWord = formatedWord..wordBuster.patterns[tbl[chr]]
						else
							formatedWord = formatedWord.."." -- Wildcard if the character isn't a letter
						end
					end
					table.insert(wordBuster.badWords, formatedWord)
				end
				for k, v in pairs(wordBuster.badWords) do
					if v == "" or v == " " then
						table.remove(wordBuster.badWords, k) -- Removes empty filters
					end
				end
				io.close(f)
			else
				print("[Word Buster] Couldn't load language '"..lang.."', language not found!\n")
			end
		end
	end
	print("[Word Buster] "..#wordBuster.badWords.." words loaded!\n")
end

wordBuster.Load()

function wordBuster.Scan(text)
	local total = 0
	for _, word in pairs(wordBuster.badWords) do
		local message, count = string.gsub(text, word, function( s )
			local censored = ""
			local l = 0
			if wordBuster.semiCensor then
				censored = s[1]
				while l < string.len(s) - 2 do
					censored = censored..wordBuster.censor
					l = l + 1
				end
				censored = censored..s[string.len(s)]
			else
				while l < string.len(s) do
					censored = censored..wordBuster.censor
					l = l + 1
				end
			end
			return censored
		end)
		total = total + count
		text = message
	end
	-- Censored names return true
	if wordBuster.notify then
		if total > 0 then
			print(wordBuster.notifyText)
			return true
		end
	end
	if total > 0 then
		return true
	end
	-- false means your name wasn't caught in the filters
	return false
end

return wordBuster