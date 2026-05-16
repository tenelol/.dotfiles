function fish_greeting
    set -l prompt_blue 7aa2f7
    set -l prompt_white ffffff
    set -l greetings "Hollow World!" "Welcome back!" "Ready to code?" "Let's be productive!" "Time is money!" "Stay Hungry!"
    set -l count (count $greetings)
    set -l idx (math "$(random) % $count + 1")

    if test "$TERM" != dumb
        fish_logo $prompt_blue $prompt_blue $prompt_blue
        echo
    end

    echo (set_color $prompt_white)$greetings[$idx](set_color normal)
end
