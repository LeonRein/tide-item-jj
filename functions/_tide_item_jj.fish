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

    # Prefer local bookmarks that are descendants of @.
    # If none exist, fall back to the head of ancestor bookmarks of @.
    # The extra trailing newline ensures names from multiple matched commits
    # can be split into one flat Fish list.
    set -l bookmark_names (command jj log --no-graph --ignore-working-copy \
        -r '@:: & bookmarks()' \
        -T 'local_bookmarks.map(|b| b.name()).join("\n") ++ "\n"' 2>/dev/null)

    if not test -n "$bookmark_names[1]"
        set bookmark_names (command jj log --no-graph --ignore-working-copy \
            -r 'heads(::@ & bookmarks())' \
            -T 'local_bookmarks.map(|b| b.name()).join("\n") ++ "\n"' 2>/dev/null)
    end

    # Normalize command output into a clean list so join(", ") is reliable.
    set bookmark_names (string split "\n" -- $bookmark_names)
    set bookmark_names (string trim -- $bookmark_names)
    set bookmark_names (string match -rv '^$' -- $bookmark_names)

    set -l bookmark_display
    set -l ahead_total 0
    set -l behind_total 0
    if test -n "$bookmark_names[1]"
        # Show only the first three bookmarks to keep prompt width bounded.
        set -l display_bookmarks $bookmark_names[1..3]
        set -l display_name (string join ", " $display_bookmarks)
        if test (count $bookmark_names) -gt 3
            set display_name "$display_name, ..."
        end
        set bookmark_display "($display_name)"

        # Query and sum ahead/behind counts for the first three displayed bookmarks.
        for bookmark_name in $display_bookmarks
            set -l tracking_info (command jj log --no-graph --ignore-working-copy \
                -r "latest(remote_bookmarks($bookmark_name), 1)" \
                -T 'remote_bookmarks.first().tracking_behind_count().lower() ++ "\n" ++ remote_bookmarks.first().tracking_ahead_count().lower()' 2>/dev/null)

            # Intentionally flipped to show prompt-relative direction.
            set -l ahead_count "$tracking_info[1]"
            set -l behind_count "$tracking_info[2]"

            if string match -qr '^[0-9]+$' -- "$ahead_count"
                set ahead_total (math "$ahead_total + $ahead_count")
            end

            if string match -qr '^[0-9]+$' -- "$behind_count"
                set behind_total (math "$behind_total + $behind_count")
            end
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
            set_color $tide_jj_color_upstream; echo -ns ' '$bookmark_display
        end
        if test $behind_total -gt 0
            set_color $tide_jj_color_upstream; echo -ns ' ⇣'$behind_total
        end
        if test $ahead_total -gt 0
            set_color $tide_jj_color_upstream; echo -ns ' ⇡'$ahead_total
        end
        set_color $tide_jj_color_added; echo -ns ' +'$added
        set_color $tide_jj_color_copied; echo -ns ' &'$copied
        set_color $tide_jj_color_modified; echo -ns ' •'$modified
        set_color $tide_jj_color_removed; echo -ns ' -'$removed
        set_color $tide_jj_color_renamed; echo -ns ' *'$renamed)
end
