# Starship calls this to redraw earlier prompts once a command has run.
# Printing nothing removes the prompt, so the scrollback keeps only the
# commands and their output.
function starship_transient_prompt_func
end
