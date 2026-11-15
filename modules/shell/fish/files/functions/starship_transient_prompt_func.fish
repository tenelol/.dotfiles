# Starship calls this to redraw earlier prompts once a command has run:
# past lines shrink to the prompt character alone.
function starship_transient_prompt_func
    starship module character
end
