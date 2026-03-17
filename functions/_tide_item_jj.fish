function _tide_item_jj
    # Get Change ID and boolean commit properties
    # Adapted from https://github.com/lukerandall/dotfiles/blob/main/starship.toml#L72
    set wc_info (jj root >/dev/null && jj log --revisions @ --no-graph --ignore-working-copy --color always --limit 1 --template '
        separate(" ",
            concat(
                if(conflict, label("working_copy conflict", "!")),
                if(divergent, label("working_copy divergent", "≠")),
                if(empty, label("working_copy empty", "ø")),
                if(hidden, label("elided", "◌")),
                if(immutable, label("node immutable", "◆")),
            ),
            change_id.shortest(4),
        raw_escape_sequence("\x1b[0m"),
        )'
    )

    # Find nearest local bookmarks from @ and display them in parentheses.
    set -l bookmark_names (command jj log --no-graph --ignore-working-copy \
        -r 'heads((::@ | @::) & bookmarks())' \
        -T 'local_bookmarks.map(|b| b.name()).join("\n")' 2>/dev/null)

    set -l bookmark_display
    set -l ahead
    set -l behind
    if test -n "$bookmark_names[1]"
        set -l display_name (string join ", " $bookmark_names)
        set bookmark_display "($display_name)"

        # Query ahead/behind counts from remote tracking bookmark.
        set -l bookmark_name $bookmark_names[1]
        set -l tracking_info (command jj log --no-graph --ignore-working-copy \
            -r "latest(remote_bookmarks($bookmark_name), 1)" \
            -T 'remote_bookmarks.first().tracking_behind_count().lower() ++ "\n" ++ remote_bookmarks.first().tracking_ahead_count().lower()' 2>/dev/null)

        # Intentionally flipped to show prompt-relative direction.
        set -l ahead_count "$tracking_info[1]"
        set -l behind_count "$tracking_info[2]"

        if test -n "$ahead_count" -a "$ahead_count" -gt 0 2>/dev/null
            set ahead $ahead_count
        end

        if test -n "$behind_count" -a "$behind_count" -gt 0 2>/dev/null
            set behind $behind_count
        end
    end

    # Get diffstats
    set -l diffstats (jj log --no-graph --color never -r @ --limit 1 -T 'diff.summary()' 2>/dev/null)
    string match -qr '(0|(?<added>.*))\n(0|(?<copied>.*))\n(0|(?<modified>.*))\n(0|(?<removed>.*))\n(0|(?<renamed>.*))' \
        "$(string match -r ^A $diffstats | count
        string match -r ^C $diffstats | count
        string match -r ^M $diffstats | count
        string match -r ^D $diffstats | count
        string match -r ^R $diffstats | count
        string match -r '^\?\?' $diffstats | count)"

    _tide_print_item jj $_tide_location_color$tide_git_icon' ' (echo -ns $wc_info
        if test -n "$bookmark_display"
            echo -ns ' '$bookmark_display
        end
        if test -n "$behind"
            set_color $tide_jj_color_upstream; echo -ns ' ⇣'$behind
        end
        if test -n "$ahead"
            set_color $tide_jj_color_upstream; echo -ns ' ⇡'$ahead
        end
        set_color $tide_jj_color_added; echo -ns ' +'$added
        set_color $tide_jj_color_copied; echo -ns ' &'$copied
        set_color $tide_jj_color_modified; echo -ns ' •'$modified
        set_color $tide_jj_color_removed; echo -ns ' -'$removed
        set_color $tide_jj_color_renamed; echo -ns ' *'$renamed)
end
