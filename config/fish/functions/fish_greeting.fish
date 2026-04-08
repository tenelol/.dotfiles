function fish_greeting
    set -l greetings "Hollow World!" "Welcome back!" "Ready to code?" "Let's be productive!" "Time is money!" "Stay Hungry!"
    set -l count (count $greetings)
    set -l idx (math "$(random) % $count + 1")

    if test "$TERM" != dumb
        fish_logo
        echo
    end

    echo $greetings[$idx]
end
