function fish_prompt
        set -l prompt_white ffffff
        set -l prompt_blue 7aa2f7

        if test -n "$SSH_TTY"
                echo -n (set_color $prompt_blue)"$USER"(set_color $prompt_white)'@'(set_color $prompt_blue)(prompt_hostname)' '
        end

        echo -n (set_color $prompt_blue)(prompt_pwd)' '

        if fish_is_root_user
                echo -n (set_color --bold $prompt_blue)'# '
        end

        echo -n (set_color --bold $prompt_blue)'❯ '
        set_color normal
end
