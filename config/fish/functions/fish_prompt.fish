function fish_prompt
        set -l tn_fg c0caf5
        set -l tn_blue 7aa2f7
        set -l tn_cyan 7dcfff
        set -l tn_red f7768e
        set -l tn_yellow e0af68

        if test -n "$SSH_TTY"
                echo -n (set_color $tn_red)"$USER"(set_color $tn_fg)'@'(set_color $tn_yellow)(prompt_hostname)' '
        end

        echo -n (set_color $tn_blue)(prompt_pwd)' '

        if fish_is_root_user
                echo -n (set_color --bold $tn_red)'# '
        end

        echo -n (set_color --bold $tn_cyan)'❯ '
        set_color normal
end
