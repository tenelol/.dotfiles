function fish_prompt
        set -l prompt_white b3bbc7
        set -l prompt_blue 7f9bc4

        if test -n "$SSH_TTY"
                echo -n (set_color $prompt_white)"$USER"'@'(prompt_hostname)' '
        end

        echo -n (set_color $prompt_white)(prompt_pwd)' '

        if fish_is_root_user
                echo -n (set_color --bold $prompt_blue)'# '
        end

        echo -n (set_color --bold $prompt_blue)'❯ '
        set_color normal
end
