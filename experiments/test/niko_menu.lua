local shiori = require('shiori')
local F = require('F')

function display_menu(script)
    n = script.chars[0]
    local start = choose { "Yeah?", F"What, {username}?", "Mm?" }
    n "{start}\n\n* (You ask Niko...)\n\n"
    local choice = n [[
        
    ]]
    
    
end

MENU_SCRIPT = [[
n = chars[0]

event OnMouseDoubleClick(x, y, character, hit, clicktype)
    local start = choose("Yeah?", "What, $(username)?", "Mm?")
    n "$(start)\n\n* (You ask Niko...)\n\n"
    local choice = n "/
        $c(to repeat himself, repeat)\n/
        $c(to say something, talk)\n/
        $c(some questions, $(AskQuestions))\n/
    "
    goto choice
end

QUESTION_TOPICS = $()

script AskQuestions()
    n "* (You ask Niko about...)"
    local topics = {
        "himself" = "Himself",
        "mama" = "His mama",
        "village" = "His village",
        "self" = "Yourself",
        "others" = "Someone else",
    }

    local topic = n "/
        $()*,$c(Himself, himself) $c(His mama, mama) $c(His village, village) $c(Yourself, self) $c(Someone else)/
    "
end
]]