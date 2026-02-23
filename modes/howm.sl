% howm.sl - Howm note-taking mode for Jed
%
% Copyright (c) 2024-2026
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% A note-taking mode compatible with howm-for-emacs syntax, featuring:
% - Denote-style file naming (TIMESTAMP--title__tags.howm)
% - Bidirectional links (>>>link and <<<link)
% - Full howm reminder syntax (see below)
% - Full-text search across all notes
% - Interactive list navigation
% - DFA syntax highlighting (when available)
% - Integrated commenting support (# for titles/comments)
%
% Reminder / Todo Syntax (identical to howm-for-emacs):
%   [YYYY-MM-DD]@N  Schedule  - shown in schedule list, N = days duration
%   [YYYY-MM-DD]+N  Todo      - floats up slowly from date, N = weight
%   [YYYY-MM-DD]!N  Deadline  - floats up fast until date, N = days warning
%   [YYYY-MM-DD]-N  Reminder  - sinks slowly after date, N = days per unit
%   [YYYY-MM-DD]~N  Defer     - sinks/floats periodically, N = period in days
%   [YYYY-MM-DD].   Done      - sinks forever (completed)
%   N is optional; defaults: @1  +7  !7  -7  ~30
%
% Toggle cycle (C-c C-t):  + → ! → - → ~ → . → +
%
% Keybindings (C-c prefix):
%   C-c c    Create note       C-c g    Follow link
%   C-c s    Search            C-c C-s  Incremental search
%   C-c C-a  Search by tag     C-c C-f  Incremental search by tag
%   C-c a    List all tags     C-c y    List schedule
%   C-c t    List todo         C-c r    List recent
%   C-c C-t  Toggle todo state
%   C-c d    Insert date       C-c Y    Insert schedule
%   C-c +    Insert todo       C-c !    Insert deadline
%   C-c -    Insert reminder   C-c ~    Insert defer
%   C-c .    Insert done
%   C-c l    Insert >>>link    C-c L    Insert <<<link
%   C-c ?    Help
%
% Version: 1.6 - Tag filtering + incremental search + fixed priorities + Modus Vivendi

provide("howm");

%!%+
%\variable{Howm_Directory}
%\synopsis{Directory where howm notes are stored}
%\usage{String_Type Howm_Directory = "~/howm"}
%\description
%  The directory where all howm notes will be created and searched.
%  The directory will be created automatically if it doesn't exist.
%\seealso{howm_create_note, howm_search}
%!%-
custom_variable("Howm_Directory", dircat(getenv("HOME"), "howm"));

variable Howm_File_Extension = ".howm";
variable Howm_Menu_Buffer = "*howm-menu*";
variable Howm_List_Buffer = "*howm-list*";
variable Howm_Mode = "howm";
variable Howm_List_Mode = "howm-list";

% Create syntax table immediately - must be done before any mode function uses it
create_syntax_table(Howm_Mode);

% Separate (plain) syntax table for list/menu buffers.
% MUST NOT share Howm_Mode's table: jed's DFA system keys the init-callback
% on the mode-name string. If *howm-list* uses use_syntax_table(Howm_Mode)
% but set_mode("howm-list"), jed calls setup_dfa_callback("howm-list"),
% rebuilding the DFA table under the wrong key and corrupting highlighting
% in subsequently visited howm file buffers.
create_syntax_table(Howm_List_Mode);

#ifndef HAS_DFA_SYNTAX
% Fallback to non-DFA syntax if DFA not available
define_syntax("=", "", '%', Howm_Mode);      % Header marker
define_syntax("[", "]", '(', Howm_Mode);     % Brackets for dates/todos
define_syntax("#", "", '%', Howm_Mode);      % Comment/title marker
define_syntax(">>>", "", '%', Howm_Mode);    % Goto links
define_syntax("<<<", "", '%', Howm_Mode);    % Come-from links
set_syntax_flags(Howm_Mode, 0x01);
#endif

% Set up comment info for howm mode
% Using # as comment character (for title lines)
set_comment_info(Howm_Mode, "# ", "", 0x01);

% DFA syntax highlighting setup (if available)
% Color semantics aligned with Modus Vivendi:
%   Schedule @  → keyword2 (#2fafff blue)        neutral, informational
%   Todo +      → keyword4 (#cfdf30 yellow-alt)  attention needed
%   Deadline !  → error    (#ff4f4f red-warmer)  urgency, warning
%   Reminder -  → keyword3 (#00d3d0 cyan)        gentle reminder
%   Defer ~     → keyword8 (#f78fe7 magenta-alt) deferred/waiting
%   Done .      → comment  (#989898 fg-dim)      completed, dimmed
%   Links >>>   → keyword  (#79a8ff blue-warmer) navigation
%   Headers =   → keyword  (#79a8ff blue-warmer) structure
%   Comments #  → comment  (#989898 fg-dim)      metadata
#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
private define setup_dfa_callback(mode)
{
    dfa_enable_highlight_cache("howm.dfa", mode);
    
    % Date pattern fragment (used in every reminder rule):
    %   \[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\]
    % Each marker character that is a regex metachar must be escaped:
    %   +  →  \\+      (quantifier otherwise)
    %   .  →  \\.      (any-char otherwise)
    %   -  →  \\-      (range in [] otherwise; safe here but escaped for clarity)
    %   ~  →  literal, no escaping needed
    %   !  →  literal, no escaping needed
    %   @  →  literal, no escaping needed
    
    variable D;
    D = "\\[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\]";
    
    % Note headers: lines starting with =  → keyword (blue-warmer)
    dfa_define_highlight_rule("^=.*$", "keyword", mode);
    
    % Titles/comments: lines starting with #  → comment (fg-dim, grey)
    dfa_define_highlight_rule("^#.*$", "comment", mode);
    
    % Schedule:  [YYYY-MM-DD]@N  → keyword2 (blue, neutral/informative)
    dfa_define_highlight_rule(D + "@[0-9]*", "keyword2", mode);
    
    % Todo:      [YYYY-MM-DD]+N  → keyword4 (yellow-alt, attention)
    dfa_define_highlight_rule(D + "\\+[0-9]*", "keyword4", mode);
    
    % Deadline:  [YYYY-MM-DD]!N  → error (red-warmer, urgent)
    dfa_define_highlight_rule(D + "![0-9]*", "error", mode);
    
    % Reminder:  [YYYY-MM-DD]-N  → keyword3 (cyan, gentle reminder)
    dfa_define_highlight_rule(D + "\\-[0-9]*", "keyword3", mode);
    
    % Defer:     [YYYY-MM-DD]~N  → keyword8 (magenta-alt, waiting)
    dfa_define_highlight_rule(D + "~[0-9]*", "keyword8", mode);
    
    % Done:      [YYYY-MM-DD].   → comment (fg-dim, completed/dimmed)
    dfa_define_highlight_rule(D + "\\.", "comment", mode);
    
    % Goto links:      >>>word  → keyword (blue-warmer, navigation)
    dfa_define_highlight_rule(">>>[ \t]*[^ \t\n]+", "keyword", mode);
    
    % Come-from links: <<<word  → keyword (blue-warmer, navigation)
    dfa_define_highlight_rule("<<<[ \t]*[^ \t\n]+", "keyword", mode);
    
    % Plain dates: [YYYY-MM-DD] without reminder marker → number
    dfa_define_highlight_rule(D, "number", mode);
    
    % Denote-style timestamps: 20241219T143052
    dfa_define_highlight_rule("[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]", "number", mode);
    
    dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, "howm");
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(Howm_Mode);
#endif
define howm_list_jump_to_file()
{
    variable linenum_str;
    variable line, file, linenum, filepath;
    variable parts, fname_part;
    
    % Get current line
    push_spot();
    bol();
    push_mark();
    eol();
    line = bufsubstr();
    pop_spot();
    
    % Skip header lines
    if (is_substr(line, "====") or 
        is_substr(line, "Search:") or
        is_substr(line, "Todo Items") or
        is_substr(line, "Schedule Items") or
        is_substr(line, "Destinations") or
        is_substr(line, "Sources") or
        strlen(strtrim(line)) == 0)
    {
        return;
    }
    
    % Parse format: filename:linenum: content
    % Example: 2024-12-19_14-30.howm:5: = 2024-12-19 14:30
    
    variable colon_pos = is_substr(line, ":");
    if (colon_pos == 0)
    {
        message("No file reference on this line");
        return;
    }
    
    % Extract filename
    fname_part = substr(line, 1, colon_pos - 1);
    file = strtrim(fname_part);
    
    % Extract line number
    variable rest = substr(line, colon_pos + 1, strlen(line));
    colon_pos = is_substr(rest, ":");
    
    if (colon_pos)
    {
        linenum_str = strtrim(substr(rest, 1, colon_pos - 1));
        linenum = integer(linenum_str);
    }
    else
    {
        linenum = 1;
    }
    
    % Build full path
    filepath = dircat(Howm_Directory, file);
    
    % Check if file exists
    if (file_status(filepath) != 1)
    {
        message(sprintf("File not found: %s", file));
        return;
    }
    
    % Jump to file
    () = find_file(filepath);
    goto_line(linenum);
    recenter(window_line());
    message(sprintf("Jumped to %s:%d", file, linenum));
}

define howm_list_mode()
{
    set_mode(Howm_List_Mode, 0);
    use_keymap(Howm_List_Mode);
    use_syntax_table(Howm_List_Mode);
    set_buffer_modified_flag(0);
    set_readonly(1);
}

define howm_menu_mode()
{
    set_mode("howm-menu", 0);
    use_keymap("howm-menu");
    use_syntax_table(Howm_List_Mode);
    set_buffer_modified_flag(0);
    set_readonly(1);
}

%!%+
%\function{howm_mode}
%\synopsis{Activate Howm note-taking mode}
%\usage{Void howm_mode()}
%\description
%  Activates Howm mode for the current buffer. This mode provides:
%  - Bidirectional linking with >>>link and <<<link syntax
%  - Todo management with multiple states (., +, ~, -)
%  - Full-text search across all notes
%  - Denote-style file naming
%
%  Howm mode is automatically activated for .howm files.
%\notes
%  Use C-c ? to show the help menu with all available commands.
%\seealso{howm_create_note, howm_menu, howm_search}
%!%-

% Mode menu definition
private define howm_mode_menu(menu)
{
    menu_append_item(menu, "&Create Note",        "howm_create_note");
    menu_append_item(menu, "&Search",             "howm_search_prompt");
    menu_append_item(menu, "&Follow Link",        "howm_goto_link");
    menu_append_separator(menu);
    menu_append_item(menu, "List &Schedule (@)",  "howm_list_schedule");
    menu_append_item(menu, "List &Todo (+)",      "howm_list_todo");
    menu_append_item(menu, "List &Recent",        "howm_list_recent");
    menu_append_separator(menu);
    menu_append_item(menu, "Insert &Schedule (@)","howm_insert_schedule");
    menu_append_item(menu, "Insert &Todo (+)",    "howm_insert_todo");
    menu_append_item(menu, "Insert &Deadline (!)", "howm_insert_deadline");
    menu_append_item(menu, "Insert &Reminder (-)", "howm_insert_reminder");
    menu_append_item(menu, "Insert D&efer (~)",   "howm_insert_defer");
    menu_append_item(menu, "Insert Done (.)",     "howm_insert_done");
    menu_append_item(menu, "Toggle Todo C&ycle",  "howm_toggle_todo");
    menu_append_separator(menu);
    menu_append_item(menu, "Insert &>>> Link",    "howm_insert_goto_link");
    menu_append_item(menu, "Insert &<<< Link",    "howm_insert_come_from_link");
    menu_append_separator(menu);
    menu_append_item(menu, "&Help/Menu",          "howm_menu");
}

define howm_mode()
{
    set_mode(Howm_Mode, 0);
    use_syntax_table(Howm_Mode);
    mode_set_mode_info(Howm_Mode, "init_mode_menu", &howm_mode_menu);
    % Disable backup files (bit 8 = 0x100) for .howm files
    setbuf_info(getbuf_info() | 0x100);
    run_mode_hooks("howm_mode_hook");
}

define howm_get_timestamp()
{
    variable t = localtime(_time());
    return sprintf("%04d-%02d-%02d %02d:%02d", 
                   t.tm_year + 1900, t.tm_mon + 1, t.tm_mday,
                   t.tm_hour, t.tm_min);
}

define howm_get_date()
{
    variable t = localtime(_time());
    return sprintf("%04d-%02d-%02d", 
                   t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);
}

% Denote-style timestamp: 20241219T143052
define howm_get_denote_timestamp()
{
    variable t = localtime(_time());
    return sprintf("%04d%02d%02dT%02d%02d%02d",
                   t.tm_year + 1900, t.tm_mon + 1, t.tm_mday,
                   t.tm_hour, t.tm_min, t.tm_sec);
}

% Convert string to slug (lowercase, spaces to hyphens, remove special chars)
define howm_slugify(str)
{
    variable slug = strtrim(str);
    
    % Convert to lowercase
    slug = strlow(slug);
    
    % Replace spaces and underscores with hyphens
    slug = str_replace_all(slug, " ", "-");
    slug = str_replace_all(slug, "_", "-");
    
    % Remove any character that's not alphanumeric or hyphen
    variable result = "";
    variable i, ch;
    _for i (0, strlen(slug)-1, 1)
    {
        ch = slug[i];
        if ((ch >= 'a' and ch <= 'z') or 
            (ch >= '0' and ch <= '9') or 
            ch == '-')
        {
            result = result + char(ch);
        }
    }
    
    % Remove multiple consecutive hyphens
    while (is_substr(result, "--"))
    {
        result = str_replace_all(result, "--", "-");
    }
    
    % Remove leading/trailing hyphens
    while (strlen(result) > 0 and result[0] == '-')
    {
        result = substr(result, 2, strlen(result));
    }
    while (strlen(result) > 0 and result[strlen(result)-1] == '-')
    {
        result = substr(result, 1, strlen(result)-1);
    }
    
    return result;
}

define howm_ensure_directory()
{
    variable st = file_status(Howm_Directory);
    if (st == 2)
        return;
    if (st == 1)
        error(sprintf("%s exists but is a file", Howm_Directory));
    variable result = system(sprintf("mkdir -p '%s' 2>/dev/null", Howm_Directory));
    if (result != 0)
        vmessage("Warning: Could not create %s", Howm_Directory);
}

define howm_list_files()
{
    variable files, howm_files, i, file;
    
    files = listdir(Howm_Directory);
    if (files == NULL)
        return String_Type[0];
    
    howm_files = String_Type[0];
    
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        if (is_substr(file, Howm_File_Extension))
        {
            howm_files = [howm_files, file];
        }
    }
    
    return howm_files;
}

%!%+
%\function{howm_create_note}
%\synopsis{Create a new howm note with Denote-style naming}
%\usage{Void howm_create_note()}
%\description
%  Creates a new howm note. Prompts for:
%  - Title: Used in the filename (converted to slug)
%  - Tags: Optional space-separated tags
%
%  The filename format is: TIMESTAMP--title__tag1_tag2.howm
%  Example: 20241219T143052--meeting-notes__work_planning.howm
%
%  The note starts with a timestamp header and optional title.
%\notes
%  Bound to C-c c in howm files.
%  Title and tags are converted to URL-friendly slugs (lowercase, hyphens).
%\seealso{howm_mode, Howm_Directory}
%!%-
define howm_create_note()
{
    variable timestamp, title, tags, filename, filepath;
    variable title_slug, tags_slug;
    variable tag_list, tag, tag_slugs, i;
    
    howm_ensure_directory();
    
    % Get Denote-style timestamp
    timestamp = howm_get_denote_timestamp();
    
    % Ask for title
    title = read_mini("Title:", "", "");
    if (strlen(title) == 0)
    {
        title = "untitled";
    }
    title_slug = howm_slugify(title);
    
    % Ask for tags (optional, space-separated)
    tags = read_mini("Tags (space-separated, optional):", "", "");
    
    % Build filename: TIMESTAMP--title__tag1_tag2.howm
    filename = timestamp + "--" + title_slug;
    
    if (strlen(strtrim(tags)) > 0)
    {
        % Convert tags to slug format
        tag_list = strchop(tags, ' ', 0);
        tag_slugs = "";
        
        _for i (0, length(tag_list)-1, 1)
        {
            tag = strtrim(tag_list[i]);
            if (strlen(tag) > 0)
            {
                if (strlen(tag_slugs) > 0)
                    tag_slugs = tag_slugs + "_";
                tag_slugs = tag_slugs + howm_slugify(tag);
            }
        }
        
        if (strlen(tag_slugs) > 0)
            filename = filename + "__" + tag_slugs;
    }
    
    filename = filename + Howm_File_Extension;
    filepath = dircat(Howm_Directory, filename);
    
    % Check if file already exists
    if (file_status(filepath) == 1)
    {
        message(sprintf("File already exists: %s", filename));
        return;
    }
    
    % Create and open file
    () = find_file(filepath);
    
    % Insert header with timestamp
    timestamp = howm_get_timestamp();
    insert(sprintf("= %s\n", timestamp));
    
    % Insert title
    if (strlen(title) > 0 and title != "untitled")
    {
        insert(sprintf("# %s\n\n", title));
    }
    else
    {
        insert("\n");
    }
    
    howm_mode();
    message(sprintf("Created: %s", filename));
}

define howm_insert_dtime()
{
    insert(sprintf("[%s]", howm_get_timestamp()));
}

define howm_insert_date()
{
    insert(sprintf("[%s]", howm_get_date()));
}

% Insert functions using exact howm-for-emacs syntax:
% [YYYY-MM-DD]@N  schedule  (shown in schedule list, N = days duration)
% [YYYY-MM-DD]+N  todo      (floats up slowly from date, N = weight)
% [YYYY-MM-DD]!N  deadline  (floats up fast until date, N = days warning)
% [YYYY-MM-DD]-N  reminder  (sinks slowly after date, N = days per unit)
% [YYYY-MM-DD]~N  defer     (sinks and floats periodically, N = period in days)
% [YYYY-MM-DD].   done      (sinks forever)

define howm_insert_schedule()
{
    insert(sprintf("[%s]@1 ", howm_get_date()));
}

define howm_insert_todo()
{
    insert(sprintf("[%s]+0 ", howm_get_date()));
}

define howm_insert_deadline()
{
    insert(sprintf("[%s]!7 ", howm_get_date()));
}

define howm_insert_reminder()
{
    insert(sprintf("[%s]-1 ", howm_get_date()));
}

define howm_insert_defer()
{
    insert(sprintf("[%s]~30 ", howm_get_date()));
}

define howm_insert_done()
{
    insert(sprintf("[%s]. ", howm_get_date()));
}

define howm_toggle_todo()
{
    % Cycle through todo states: +  →  !  →  -  →  ~  →  .  →  +
    % This mirrors the howm-for-emacs action-lock cycle
    variable current_marker, line, idx;

    push_spot();
    bol();
    push_mark();
    eol();
    line = bufsubstr();
    pop_spot();

    % Find the closing ] of a date bracket [YYYY-MM-DD]
    push_spot();
    bol();
    if (fsearch("]"))
    {
        go_right(1);
        current_marker = what_char();

        % Only toggle known howm markers
        if (current_marker == '+' or current_marker == '!' or
            current_marker == '-' or current_marker == '~' or
            current_marker == '.')
        {
            del();
            if (current_marker == '+')
                insert("!");
            else if (current_marker == '!')
                insert("-");
            else if (current_marker == '-')
                insert("~");
            else if (current_marker == '~')
                insert(".");
            else if (current_marker == '.')
                insert("+");
        }
        else if (current_marker == '@')
        {
            message("Schedules cannot be toggled");
        }
        else
        {
            message("No howm marker found on this line");
        }
    }
    else
    {
        message("No date bracket found on this line");
    }
    pop_spot();
}

define howm_insert_goto_link()
{
    variable link_text = read_mini("Link to:", "", "");
    if (strlen(link_text) > 0)
    {
        % Remove spaces from link text for consistency
        link_text = str_replace_all(link_text, " ", "-");
        insert(sprintf(">>>%s", link_text));
    }
}

define howm_insert_come_from_link()
{
    variable link_text = read_mini("Come from:", "", "");
    if (strlen(link_text) > 0)
    {
        % Remove spaces from link text for consistency
        link_text = str_replace_all(link_text, " ", "-");
        insert(sprintf("<<<%s", link_text));
    }
}

define howm_extract_goto_link()
{
    variable line, idx, link_text, i, ch, start_pos, end_pos;
    
    push_spot();
    bol();
    push_mark();
    eol();
    line = bufsubstr();
    pop_spot();
    
    idx = is_substr(line, ">>>");
    if (idx)
    {
        % Extract text after >>> until space, newline, or end
        start_pos = idx + 3;
        end_pos = start_pos;
        
        % Find end of link (first space or end of line)
        while (end_pos <= strlen(line))
        {
            if (end_pos > strlen(line))
                break;
            ch = line[end_pos - 1];  % S-Lang uses 1-based indexing for substr
            if (ch == ' ' or ch == '\t' or ch == '\n')
                break;
            end_pos++;
        }
        
        % Extract the link text
        if (end_pos > start_pos)
        {
            link_text = substr(line, start_pos, end_pos - start_pos);
            link_text = strtrim(link_text);
            if (strlen(link_text) > 0)
                return link_text;
        }
    }
    
    return NULL;
}

define howm_extract_come_from_link()
{
    variable line, idx, link_text, i, ch, start_pos, end_pos;
    
    push_spot();
    bol();
    push_mark();
    eol();
    line = bufsubstr();
    pop_spot();
    
    idx = is_substr(line, "<<<");
    if (idx)
    {
        % Extract text after <<< until space, newline, or end
        start_pos = idx + 3;
        end_pos = start_pos;
        
        % Find end of link (first space or end of line)
        while (end_pos <= strlen(line))
        {
            if (end_pos > strlen(line))
                break;
            ch = line[end_pos - 1];
            if (ch == ' ' or ch == '\t' or ch == '\n')
                break;
            end_pos++;
        }
        
        % Extract the link text
        if (end_pos > start_pos)
        {
            link_text = substr(line, start_pos, end_pos - start_pos);
            link_text = strtrim(link_text);
            if (strlen(link_text) > 0)
                return link_text;
        }
    }
    
    return NULL;
}

define howm_search(pattern)
{
    variable result;
    variable files, results, i, file, filepath, fp, line, line_num;
    
    files = howm_list_files();
    results = String_Type[0];
    
    if (length(files) == 0)
    {
        message("No howm files found");
        return;
    }
    
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        filepath = dircat(Howm_Directory, file);
        
        fp = fopen(filepath, "r");
        if (fp == NULL)
            continue;
        
        line_num = 0;
        while (-1 != fgets(&line, fp))
        {
            line_num++;
            if (is_substr(line, pattern))
            {
                result = sprintf("%s:%d: %s", file, line_num, strtrim(line));
                results = [results, result];
            }
        }
        
        () = fclose(fp);
    }
    
    if (length(results) == 0)
    {
        message("No matches found for: " + pattern);
        return;
    }
    
    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert(sprintf("Search: %s (%d matches)\n", pattern, length(results)));
    insert("================================================================\n\n");
    
    _for i (0, length(results)-1, 1)
    {
        insert(results[i] + "\n");
    }
    
    bob();
    howm_list_mode();
}

define howm_goto_link()
{
    variable fname;
    variable link_text, search_pattern;
    variable is_goto_link = 0;
    
    link_text = howm_extract_goto_link();
    
    if (link_text != NULL)
    {
        is_goto_link = 1;
        search_pattern = sprintf("<<<%s", link_text);
        message(sprintf("Going to: %s", link_text));
    }
    else
    {
        link_text = howm_extract_come_from_link();
        if (link_text != NULL)
        {
            is_goto_link = 0;
            search_pattern = sprintf(">>>%s", link_text);
            message(sprintf("Finding sources of: %s", link_text));
        }
        else
        {
            message("No link on this line");
            return;
        }
    }
    
    variable files, i, file, filepath, fp, line, line_num;
    variable matches = String_Type[0];
    variable match_files = String_Type[0];
    variable match_lines = Integer_Type[0];
    
    files = howm_list_files();
    
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        filepath = dircat(Howm_Directory, file);
        
        fp = fopen(filepath, "r");
        if (fp == NULL)
            continue;
        
        line_num = 0;
        while (-1 != fgets(&line, fp))
        {

            line_num++;
            if (is_substr(line, search_pattern))
            {
                matches = [matches, strtrim(line)];
                match_files = [match_files, filepath];
                match_lines = [match_lines, line_num];
            }
        }
        
        () = fclose(fp);
    }
    
    if (length(matches) == 0)
    {
        message(sprintf("Not found: %s", link_text));
        return;
    }
    
    if (is_goto_link and length(matches) == 1)
    {
        find_file(match_files[0]);
        goto_line(match_lines[0]);
        recenter(window_line());
        message(sprintf("Found: <<< %s", link_text));
        return;
    }
    
    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();
    
    if (is_goto_link)
    {
        insert(sprintf("Destinations for >>> %s (%d found)\n", link_text, length(matches)));
    }
    else
    {
        insert(sprintf("Sources for <<< %s (%d found)\n", link_text, length(matches)));
    }
    insert("================================================================\n\n");
    
    _for i (0, length(matches)-1, 1)
    {
        fname = path_basename(match_files[i]);
        insert(sprintf("%s:%d: %s\n", fname, match_lines[i], matches[i]));
    }
    
    bob();
    howm_list_mode();
    % Single-match direct jump is handled above with early return.
    % Multiple matches are displayed in the list buffer for user selection.
}

define howm_occur()
{
    variable link_text = howm_extract_goto_link();
    
    if (link_text == NULL)
        link_text = howm_extract_come_from_link();
    
    if (link_text != NULL)
    {
        howm_search(link_text);
    }
    else
    {
        message("No link on this line");
    }
}

define howm_search_prompt()
{
    variable pattern = read_mini("Search:", "", "");
    if (strlen(pattern) > 0)
    {
        howm_search(pattern);
    }
}

% -----------------------------------------------------------------------
% Howm reminder scoring algorithm
%
% Score determines sort order: higher score = floats to top.
% Today = day 0.  days_elapsed = today - item_date (positive = past).
%
% +N  todo:     score =  days_elapsed / max(N, 1)
%               Rises slowly. After N days it has risen 1 unit.
%
% !N  deadline: score =  (N - days_until) / max(N, 1)
%               where days_until = -days_elapsed (negative = future)
%               Rises fast before the date; stays maxed after.
%
% -N  reminder: score =  1.0 - days_elapsed / max(N, 1)
%               Appears on the date (score=1), then sinks at rate 1/N.
%
% ~N  defer:    score = -cos(2 * PI * days_elapsed / max(N, 1))
%               Oscillates with period N days. Starts at -1 (sunk),
%               floats up to +1 at N/2, sinks again at N.
%
% .   done:     score = -1e9  (always at bottom)
%
% Items before their start date have score -1e9 (hidden / at bottom).
% -----------------------------------------------------------------------

% Parse a date string "YYYY-MM-DD" into a day-count (days since epoch).
% Uses a simple Zeller-style formula for day difference.
private define howm_date_to_days(datestr)
{
    variable y, m, d;
    if (sscanf(datestr, "%d-%d-%d", &y, &m, &d) != 3)
        return -1;
    % Convert to Julian Day Number (simple formula)
    if (m <= 2) { y--; m += 12; }
    variable a = y / 400;
    variable b = y / 100;
    variable c = y / 4;
    return 365 * y + a - b + c + (153 * m + 8) / 5 + d;
}

% Return today's day-count
private define howm_today_days()
{
    variable t = localtime(_time());
    variable y = t.tm_year + 1900;
    variable m = t.tm_mon + 1;
    variable d = t.tm_mday;
    if (m <= 2) { y--; m += 12; }
    variable a = y / 400;
    variable b = y / 100;
    variable c = y / 4;
    return 365 * y + a - b + c + (153 * m + 8) / 5 + d;
}

% Parse "[YYYY-MM-DD]MARKER[N]" from a line.
% Returns struct with fields: date_str, marker, n_val, text
% or NULL if not a valid reminder line.
private define howm_parse_reminder(line)
{
    % Finds [YYYY-MM-DD]MARKER[digits] anywhere in a line.
    %
    % string_match returns 1-based position of the first char of the match.
    % line[i] uses 0-based indexing.
    % substr(s, pos, len) uses 1-based pos.
    %
    % If match starts at 1-based mpos, then:
    %   '[' is at 0-based (mpos-1)
    %   date chars are 0-based mpos..(mpos+9)  => substr(line, mpos+1, 10)
    %   ']' is at 0-based (mpos+10)
    %   marker is at 0-based (mpos+11)
    %   digits start at 0-based (mpos+12)
    variable pat, mpos, date_str, marker, n_val, n_str, text;
    variable di, ch, llen, result;

    pat = "\\[[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\][@+!\\-~.][0-9]*";
    mpos = string_match(line, pat, 1);
    if (mpos == 0) return NULL;

    % date: skip '[' at (mpos-1), take 10 chars; substr is 1-based so pos = mpos+1
    date_str = substr(line, mpos + 1, 10);

    % marker: 0-based index = mpos + 11
    marker = line[mpos + 11];

    % digits: 0-based start = mpos + 12
    n_str = "";
    di   = mpos + 12;
    llen = strlen(line);
    while (di < llen)
    {
        ch = line[di];
        if (ch >= '0' and ch <= '9')
        {
            n_str = n_str + char(ch);
            di++;
        }
        else
            break;
    }

    if (strlen(n_str) > 0)
        n_val = atoi(n_str);
    else
        n_val = 0;

    if (n_val == 0)
    {
        if      (marker == '@') n_val = 1;
        else if (marker == '+') n_val = 7;   % Todo: floats moderately over a week
        else if (marker == '!') n_val = 7;
        else if (marker == '-') n_val = 7;   % Reminder: sinks moderately over a week
        else if (marker == '~') n_val = 30;
    }

    % text: di is 0-based end of digits; substr is 1-based so pos = di+1
    text = strtrim(substr(line, di + 1, llen));

    result = struct { date_str, marker, n_val, text };
    result.date_str = date_str;
    result.marker   = marker;
    result.n_val    = n_val;
    result.text     = text;
    return result;
}



% Compute float/sink score for a reminder item.
% Higher score = floats higher in list.
private define howm_reminder_score(item, today_days)
{
    variable item_days, days_elapsed, n, marker, score, pi;
    
    item_days = howm_date_to_days(item.date_str);
    if (item_days < 0) return -1e9;
    
    days_elapsed = today_days - item_days;
    n = item.n_val;
    if (n <= 0) n = 1;
    marker = item.marker;
    
    if (marker == '.') return -1e9;
    if (marker == '@') return double(-item_days);
    
    if (days_elapsed < 0)
    {
        if (marker == '!')
        {
            if (days_elapsed < -n) return -1e9;
        }
        else
            return -1e9;
    }
    
    if (marker == '+')
        return double(days_elapsed) / double(n);
    
    if (marker == '!')
    {
        score = double(n - (-days_elapsed)) / double(n);
        if (score > 2.0) return 2.0;
        return score;
    }
    
    if (marker == '-')
        return 1.0 - double(days_elapsed) / double(n);
    
    if (marker == '~')
    {
        pi = 3.14159265358979;
        return -cos(2.0 * pi * double(days_elapsed) / double(n));
    }
    
    return -1e9;
}

% Simple insertion sort on parallel arrays by score descending
private define howm_sort_by_score(lines_arr, files_arr, lnums_arr, scores_arr)
{
    variable key_score, key_line, key_file, key_lnum;
    variable n = length(scores_arr);
    if (n < 2) return;
    variable i, j;
    _for i (1, n-1, 1)
    {
        key_score = scores_arr[i];
        key_line  = lines_arr[i];
        key_file  = files_arr[i];
        key_lnum  = lnums_arr[i];
        j = i - 1;
        while (j >= 0 and scores_arr[j] < key_score)
        {
            scores_arr[j+1] = scores_arr[j];
            lines_arr[j+1]  = lines_arr[j];
            files_arr[j+1]  = files_arr[j];
            lnums_arr[j+1]  = lnums_arr[j];
            j--;
        }
        scores_arr[j+1] = key_score;
        lines_arr[j+1]  = key_line;
        files_arr[j+1]  = key_file;
        lnums_arr[j+1]  = key_lnum;
    }
}

% Format a score as a visual bar for display (like the howm priority graphic)
private define howm_score_bar(score, marker)
{
    if (marker == '.')  return "[done    ]";
    if (score <= -1e8)  return "[hidden  ]";
    
    % Map score -1..2 to bar width 0..8
    variable clamped = score;
    if (clamped < -1.0) clamped = -1.0;
    if (clamped >  2.0) clamped =  2.0;
    variable width = int((clamped + 1.0) / 3.0 * 8.0 + 0.5);
    if (width < 0) width = 0;
    if (width > 8) width = 8;
    
    variable bar = "[";
    variable k;
    _for k (0, 7, 1)
    {
        if (k < width) bar = bar + "#";
        else           bar = bar + " ";
    }
    return bar + "]";
}

% Return all lines of a howm file as a String_Type array.
% If the file is already open in a Jed buffer (even unsaved), reads from
% that buffer so deletions and edits are immediately reflected.
% Falls back to reading from disk if not open.
private define howm_read_file_lines(filepath)
{
    variable bname, bfile, bdir, found_buf;
    variable saved_buf, lines, line, n, bfull, fp;
    lines = String_Type[0];
    found_buf = NULL;

    % Walk all open buffers looking for one whose file matches filepath
    loop (buffer_list())
    {
        bname = ();          % buffer_list pushes names onto stack
        setbuf(bname);
        (bfile, bdir, , ) = getbuf_info();
        if (strlen(bfile) > 0)
        {
            bfull = dircat(bdir, bfile);
            if (bfull == filepath)
            {
                found_buf = bname;
                break;
            }
        }
    }

    if (found_buf != NULL)
    {
        % File is open - read from buffer to pick up unsaved changes
        saved_buf = whatbuf();
        setbuf(found_buf);
        push_spot();
        bob();
        do
        {
            push_mark();
            eol();
            line = bufsubstr();
            pop_mark(0);
            lines = [lines, line];
        }
        while (down(1));
        pop_spot();
        setbuf(saved_buf);
    }
    else
    {
        % Not open - read from disk
        fp = fopen(filepath, "r");
        if (fp == NULL) return lines;
        while (-1 != fgets(&line, fp))
        {
            % strip trailing newline
            n = strlen(line);
            if (n > 0 and line[n-1] == '\n')
                line = substr(line, 1, n - 1);
            lines = [lines, line];
        }
        () = fclose(fp);
    }
    return lines;
}


define howm_list_todo()
{
    variable files, i, file, filepath, line, line_num;
    variable file_lines, j;
    variable item, score, sorted_markers, pi2, mchar, bar, type_label, today_str;
    variable today = howm_today_days();
    variable all_lines   = String_Type[0];
    variable all_files   = String_Type[0];
    variable all_lnums   = Integer_Type[0];
    variable all_scores  = Double_Type[0];

    files = howm_list_files();
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        filepath = dircat(Howm_Directory, file);
        file_lines = howm_read_file_lines(filepath);
        _for j (0, length(file_lines)-1, 1)
        {
            line = file_lines[j];
            if (not (is_substr(line, "]+") or is_substr(line, "]!") or
                     is_substr(line, "]-") or is_substr(line, "]~") or
                     is_substr(line, "].")))
                continue;
            item = howm_parse_reminder(line);
            if (item == NULL) continue;
            if (item.marker == '@') continue;
            score = howm_reminder_score(item, today);
            all_lines  = [all_lines,  strtrim(line)];
            all_files  = [all_files,  file];
            all_lnums  = [all_lnums,  j + 1];
            all_scores = [all_scores, score];
        }
    }

    if (length(all_lines) == 0) { message("No todo/reminder items found"); return; }

    howm_sort_by_score(all_lines, all_files, all_lnums, all_scores);

    sorted_markers = Integer_Type[length(all_lines)];
    _for i (0, length(all_lines)-1, 1)
    {
        pi2 = howm_parse_reminder(all_lines[i]);
        if (pi2 != NULL) sorted_markers[i] = pi2.marker;
        else             sorted_markers[i] = '?';
    }

    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();

    today_str = howm_get_date();
    insert(sprintf("Todo/Reminder  [today: %s]  (%d items)\n", today_str, length(all_lines)));
    insert("  [########]=high priority (floats)   [        ]=low (sinks)\n");
    insert("================================================================\n\n");

    _for i (0, length(all_lines)-1, 1)
    {
        score = all_scores[i];
        mchar = sorted_markers[i];
        bar   = howm_score_bar(score, mchar);
        if      (mchar == '+') type_label = "todo    ";
        else if (mchar == '!') type_label = "deadline";
        else if (mchar == '-') type_label = "reminder";
        else if (mchar == '~') type_label = "defer   ";
        else if (mchar == '.') type_label = "done    ";
        else                   type_label = "        ";
        insert(sprintf("%s:%d: %s %s  %s\n",
                       all_files[i], all_lnums[i], bar, type_label, all_lines[i]));
    }
    bob();
    howm_list_mode();
}


define howm_list_done()
{
    variable files, i, file, filepath, line, line_num;
    variable file_lines, j;
    variable results = String_Type[0];
    variable res_files = String_Type[0];
    variable res_lnums = Integer_Type[0];
    
    files = howm_list_files();
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        filepath = dircat(Howm_Directory, file);
        file_lines = howm_read_file_lines(filepath);
        _for j (0, length(file_lines)-1, 1)
        {
            line = file_lines[j];
            if (is_substr(line, "].") and howm_parse_reminder(line) != NULL)
            {
                results   = [results,   strtrim(line)];
                res_files = [res_files, file];
                res_lnums = [res_lnums, j + 1];
            }
        }
    }
    
    if (length(results) == 0) { message("No done items found"); return; }
    
    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();
    insert(sprintf("Done Items (%d found)\n", length(results)));
    insert("================================================================\n\n");
    _for i (0, length(results)-1, 1)
        insert(sprintf("%s:%d: %s\n", res_files[i], res_lnums[i], results[i]));
    bob();
    howm_list_mode();
}

define howm_list_schedule()
{
    variable files, i, file, filepath, line, line_num;
    variable file_lines;
    variable item, idays, status, diff, today_str;
    variable n, j, kd, kl, kf, kn;
    variable today = howm_today_days();
    variable all_lines = String_Type[0];
    variable all_files = String_Type[0];
    variable all_lnums = Integer_Type[0];
    variable all_days  = Integer_Type[0];

    files = howm_list_files();
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        filepath = dircat(Howm_Directory, file);
        file_lines = howm_read_file_lines(filepath);
        _for j (0, length(file_lines)-1, 1)
        {
            line = file_lines[j];
            if (not is_substr(line, "]@")) continue;
            item = howm_parse_reminder(line);
            if (item == NULL) continue;
            idays = howm_date_to_days(item.date_str);
            if (idays < today - 7)  continue;
            if (idays > today + 90) continue;
            all_lines = [all_lines, strtrim(line)];
            all_files = [all_files, file];
            all_lnums = [all_lnums, j + 1];
            all_days  = [all_days,  idays];
        }
    }

    % Sort by date ascending
    n = length(all_days);
    _for i (1, n-1, 1)
    {
        kd = all_days[i];
        kl = all_lines[i];
        kf = all_files[i];
        kn = all_lnums[i];
        j = i - 1;
        while (j >= 0 and all_days[j] > kd)
        {
            all_days[j+1]  = all_days[j];
            all_lines[j+1] = all_lines[j];
            all_files[j+1] = all_files[j];
            all_lnums[j+1] = all_lnums[j];
            j--;
        }
        all_days[j+1]  = kd;
        all_lines[j+1] = kl;
        all_files[j+1] = kf;
        all_lnums[j+1] = kn;
    }

    if (length(all_lines) == 0) { message("No schedule items found"); return; }

    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();

    today_str = howm_get_date();
    insert(sprintf("Schedule  [today: %s]  (%d items, window: -7..+90 days)\n",
                   today_str, length(all_lines)));
    insert("  status    item\n");
    insert("================================================================\n\n");

    _for i (0, length(all_lines)-1, 1)
    {
        diff = all_days[i] - today;
        if      (diff < 0)  status = sprintf("%-8s", "past");
        else if (diff == 0) status = "TODAY   ";
        else if (diff == 1) status = "tomorrow";
        else                status = sprintf("in %2dd  ", diff);
        insert(sprintf("%s:%d: [%s] %s\n",
                       all_files[i], all_lnums[i], status, all_lines[i]));
    }
    bob();
    howm_list_mode();
}


define howm_list_recent()
{
    variable files, i, file, max_show;
    
    files = howm_list_files();
    
    if (length(files) == 0)
    {
        message("No howm files found");
        return;
    }
    
    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert(sprintf("Recent Notes (%d total)\n", length(files)));
    insert("================================================================\n\n");
    
    max_show = length(files);
    if (max_show > 20)
        max_show = 20;
    
    _for i (length(files)-1, length(files)-max_show, -1)
    {
        file = files[i];
        insert(sprintf("%s:1: (recent file)\n", file));
    }
    
    bob();
    howm_list_mode();
}

define howm_menu()
{
    variable files = howm_list_files();
    
    pop2buf(Howm_Menu_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert("================================================================\n");
    insert("                 Howm Mode for Jed\n");
    insert("================================================================\n\n");
    
    insert("Reminder / Todo Syntax:\n");
    insert("  [YYYY-MM-DD]@N  Schedule  - appointment, N days duration\n");
    insert("  [YYYY-MM-DD]+N  Todo      - floats up slowly from date\n");
    insert("  [YYYY-MM-DD]!N  Deadline  - floats up fast until date, N days warning\n");
    insert("  [YYYY-MM-DD]-N  Reminder  - sinks slowly after date\n");
    insert("  [YYYY-MM-DD]~N  Defer     - sinks/floats periodically (N day period)\n");
    insert("  [YYYY-MM-DD].   Done      - sinks forever\n");
    insert("  (N is optional, defaults: @1 +7 !7 -7 ~30)\n\n");
    
    insert("Toggle cycle (C-c C-t):  + → ! → - → ~ → . → +\n\n");
    
    insert("Link Semantics:\n");
    insert("  >>>Name  - Goto link  (finds <<<Name in other files)\n");
    insert("  <<<Name  - Come-from  (found by >>>Name in other files)\n");
    insert("  No spaces in link names - use hyphens: >>>project-alpha\n\n");
    
    insert("File naming (Denote-style):\n");
    insert("  TIMESTAMP--title__tag1_tag2.howm\n");
    insert("  Example: 20241219T143052--meeting-notes__work_planning.howm\n\n");
    
    insert("Howm Keys (C-c prefix):\n");
    insert("  C-c c     Create note\n");
    insert("  C-c g     Follow link (>>> or <<<)\n");
    insert("  C-c s     Search notes\n");
    insert("  C-c C-s   Incremental search (type-as-you-search)\n");
    insert("  C-c C-a   Search by tag (all lines in tagged files)\n");
    insert("  C-c C-f   Incremental search by tag (filter + search)\n");
    insert("  C-c a     List all tags (with counts)\n");
    insert("  C-c y     List schedule (@)\n");
    insert("  C-c t     List todo/reminder (+!-~)\n");
    insert("  C-c r     List recent files\n");
    insert("  C-c C-t   Toggle todo state cycle\n");
    insert("  C-c d     Insert date\n\n");
    insert("  C-c d     Insert [date]\n");
    insert("  C-c y     Insert schedule  [date]@1\n");
    insert("  C-c +     Insert todo       [date]+0\n");
    insert("  C-c !     Insert deadline   [date]!7\n");
    insert("  C-c -     Insert reminder   [date]-1\n");
    insert("  C-c ~     Insert defer      [date]~30\n");
    insert("  C-c .     Insert done       [date].\n\n");
    insert("  C-c l     Insert >>>link\n");
    insert("  C-c L     Insert <<<link\n");
    insert("  C-c ?     This help\n\n");
    
    insert("List navigation:\n");
    insert("  Enter     Jump to file at cursor\n");
    insert("  q         Close window\n\n");
    
    insert(sprintf("Directory: %s\n", Howm_Directory));
    insert(sprintf("Total notes: %d\n", length(files)));
    
    bob();
    howm_menu_mode();
}

% Setup keymap
if (keymap_p(Howm_Mode) == 0)
{
    copy_keymap(Howm_Mode, "global");
    
    definekey("howm_create_note",          "^Cc",  Howm_Mode);
    definekey("howm_goto_link",            "^Cg",  Howm_Mode);
    definekey("howm_search_prompt",        "^Cs",  Howm_Mode);
    definekey("howm_isearch",              "^C^S", Howm_Mode);  % Incremental search
    definekey("howm_search_by_tag",        "^C^A", Howm_Mode);  % Search by tag (A=all in tag)
    definekey("howm_isearch_by_tag",       "^C^F", Howm_Mode);  % Incremental by tag (F=filter)
    definekey("howm_list_schedule",        "^Cy",  Howm_Mode);  % y = schedule (Termin)
    definekey("howm_list_todo",            "^Ct",  Howm_Mode);  % t = todo
    definekey("howm_list_tags",            "^Ca",  Howm_Mode);  % a = all tags
    definekey("howm_toggle_todo_state",    "^C^T", Howm_Mode);  % Toggle todo state
    definekey("howm_list_recent",          "^Cr",  Howm_Mode);
    definekey("howm_toggle_todo",          "^C^T", Howm_Mode);
    definekey("howm_insert_date",          "^Cd",  Howm_Mode);
    definekey("howm_insert_schedule",      "^CY",  Howm_Mode);
    definekey("howm_insert_todo",          "^C+",  Howm_Mode);
    definekey("howm_insert_deadline",      "^C!",  Howm_Mode);
    definekey("howm_insert_reminder",      "^C-",  Howm_Mode);
    definekey("howm_insert_defer",         "^C~",  Howm_Mode);
    definekey("howm_insert_done",          "^C.",  Howm_Mode);
    definekey("howm_insert_goto_link",     "^Cl",  Howm_Mode);
    definekey("howm_insert_come_from_link","^CL",  Howm_Mode);
    definekey("howm_menu",                 "^C?",  Howm_Mode);
}

% Close the list/menu buffer cleanly: delete the buffer entirely.
% This prevents the stale *howm-list* buffer from interfering with syntax
% highlighting in subsequently opened .howm files.
define howm_close_list()
{
    variable buf = whatbuf();
    % Switch away from this buffer before deleting it
    if (nwindows() > 1)
    {
        % Split view: move to the other window, then collapse
        otherwindow();
        onewindow();
    }
    else
    {
        % Single window: bury so delbuf has something to show
        bury_buffer(buf);
    }
    if (bufferp(buf))
        delbuf(buf);
}

% Setup keymaps for list and menu modes
!if (keymap_p(Howm_List_Mode))
{
    copy_keymap(Howm_List_Mode, "global");
    definekey("howm_list_jump_to_file", "^M", Howm_List_Mode);  % Enter
    definekey("howm_list_jump_to_file", "^J", Howm_List_Mode);  % Ctrl-J
    definekey("howm_close_list",        "q",  Howm_List_Mode);  % q to close
}

!if (keymap_p("howm-menu"))
{
    copy_keymap("howm-menu", "global");
    definekey("howm_close_list", "q", "howm-menu");             % q to close
}

define howm_mode_hook_function()
{
    variable ext = path_extname(buffer_filename());
    if (ext == Howm_File_Extension)
    {
        howm_mode();
        
        % Set up howm-specific keys using local_setkey
        % This preserves all standard Emacs bindings
        local_setkey("howm_create_note",           "^Cc");
        local_setkey("howm_goto_link",             "^Cg");
        local_setkey("howm_search_prompt",         "^Cs");
        local_setkey("howm_isearch",               "^C^S");  % Incremental search
        local_setkey("howm_search_by_tag",         "^C^A");  % Search by tag (A=all in tag)
        local_setkey("howm_isearch_by_tag",        "^C^F");  % Incremental by tag (F=filter)
        local_setkey("howm_list_schedule",         "^Cy");   % y = Termin/schedule
        local_setkey("howm_list_todo",             "^Ct");   % t = todo
        local_setkey("howm_list_tags",             "^Ca");   % a = all tags
        local_setkey("howm_toggle_todo_state",     "^C^T");  % Toggle todo state
        local_setkey("howm_list_recent",           "^Cr");
        local_setkey("howm_toggle_todo",           "^C^T");
        local_setkey("howm_insert_date",           "^Cd");
        local_setkey("howm_insert_schedule",       "^CY");
        local_setkey("howm_insert_todo",           "^C+");
        local_setkey("howm_insert_deadline",       "^C!");
        local_setkey("howm_insert_reminder",       "^C-");
        local_setkey("howm_insert_defer",          "^C~");
        local_setkey("howm_insert_done",           "^C.");
        local_setkey("howm_insert_goto_link",      "^Cl");
        local_setkey("howm_insert_come_from_link", "^CL");
        local_setkey("howm_menu",                  "^C?");
    }
}

append_to_hook("_jed_find_file_after_hooks", &howm_mode_hook_function);

%% =============================================================================
%% Real Incremental Search - Updates as you type
%% =============================================================================

variable Howm_Isearch_Buffer = "*howm-isearch*";

% Update search results display
private define howm_isearch_do_search(pattern)
{
    variable files, results, i, file, filepath, fp, line, line_num;
    variable saved_buf = whatbuf();
    
    pop2buf(Howm_Isearch_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert(sprintf("Incremental Search: [%s]\n", pattern));
    insert("================================================================\n");
    insert("Type to search | RET=jump | ESC=cancel | BS=delete\n\n");
    
    if (strlen(pattern) < 2)
    {
        if (strlen(pattern) == 0)
            insert("Start typing...\n");
        else
            insert("Need 2+ characters...\n");
        bob();
        update(1);  % Force screen update
        setbuf(saved_buf);
        return 0;
    }
    
    % Search
    files = howm_list_files();
    results = String_Type[0];
    
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        filepath = dircat(Howm_Directory, file);
        
        fp = fopen(filepath, "r");
        if (fp == NULL) continue;
        
        line_num = 0;
        while (-1 != fgets(&line, fp))
        {
            line_num++;
            if (is_substr(strlow(line), strlow(pattern)))
            {
                results = [results, sprintf("%s:%d: %s", file, line_num, strtrim(line))];
                if (length(results) >= 100) break;
            }
        }
        () = fclose(fp);
        if (length(results) >= 100) break;
    }
    
    % Display
    if (length(results) == 0)
    {
        insert("No matches.\n");
    }
    else
    {
        insert(sprintf("%d matches", length(results)));
        if (length(results) >= 100) insert(" (first 100)");
        insert(":\n\n");
        
        variable max = length(results);
        if (max > 100) max = 100;
        _for i (0, max-1, 1)
            insert(results[i] + "\n");
    }
    
    bob();
    goto_line(4);  % Position on first result
    update(1);     % Force screen update
    setbuf(saved_buf);
    update(1);     % Update original buffer too
    
    return length(results);
}

% Jump to file from current line in isearch buffer
% Just use the existing howm_list_jump_to_file function
private define howm_isearch_jump_to_result()
{
    % The buffer is already in the right format (filename:linenum: content)
    % Just call the existing function
    howm_list_jump_to_file();
    return 1;  % Assume success
}

% Main incremental search
define howm_isearch()
{
    variable pattern = "";
    variable key, ch;
    variable orig_buf = whatbuf();
    variable created_split = 0;
    variable result_count = 0;
    
    % Create split
    if (nwindows() == 1)
    {
        splitwindow();
        created_split = 1;
    }
    
    % Setup results buffer
    pop2buf(Howm_Isearch_Buffer);
    set_readonly(0);
    erase_buffer();
    insert("Incremental Search: []\n");
    insert("================================================================\n");
    insert("Start typing... (RET=jump to first, ESC=cancel, Ctrl-G=finish)\n");
    bob();
    update(1);
    
    % Make it a list buffer so navigation works
    howm_list_mode();
    
    % Go back to original window
    otherwindow();
    setbuf(orig_buf);
    
    % Show message
    message("Incremental search (type to search, RET=jump, Ctrl-G=browse results, ESC=cancel)");
    update(1);
    
    % Input loop
    forever
    {
        % Wait for input without blocking
        !if (input_pending(10))  % Wait 1 second
            continue;
        
        key = getkey();
        
        % ESC - cancel completely
        if (key == 27)
        {
            if (created_split)
            {
                setbuf(Howm_Isearch_Buffer);
                delbuf(Howm_Isearch_Buffer);
                setbuf(orig_buf);
                onewindow();
            }
            message("Search cancelled");
            return;
        }
        
        % Ctrl-G (7) - finish search and switch to results for browsing
        if (key == 7)
        {
            if (result_count == 0)
            {
                if (created_split)
                {
                    setbuf(Howm_Isearch_Buffer);
                    delbuf(Howm_Isearch_Buffer);
                    setbuf(orig_buf);
                    onewindow();
                }
                message("No results to browse");
                return;
            }
            
            % Switch to results buffer and let user navigate normally
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            message("Browse results (RET=jump, q=close)");
            return;  % Exit loop, user now has control in results buffer
        }
        
        % RET - jump to current line in results
        if (key == 13)
        {
            if (result_count == 0)
            {
                message("No results yet");
                continue;
            }
            
            % Switch to results buffer and jump
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            
            howm_list_jump_to_file();
            
            % Clean up
            if (created_split)
            {
                setbuf(Howm_Isearch_Buffer);
                delbuf(Howm_Isearch_Buffer);
                onewindow();
            }
            return;
        }
        
        % Backspace - delete character
        if (key == 127 or key == 8)
        {
            if (strlen(pattern) > 0)
            {
                pattern = substr(pattern, 1, strlen(pattern)-1);
                result_count = howm_isearch_do_search(pattern);
            }
            continue;
        }
        
        % Ctrl-N (14) - next result
        if (key == 14)
        {
            variable saved_buf = whatbuf();
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            call("next_line_cmd");
            update(1);
            otherwindow();
            setbuf(saved_buf);
            continue;
        }
        
        % Ctrl-P (16) - previous result
        if (key == 16)
        {
            saved_buf = whatbuf();
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            call("previous_line_cmd");
            update(1);
            otherwindow();
            setbuf(saved_buf);
            continue;
        }
        
        % Regular character - add and search
        if (key >= 32 and key < 127)
        {
            pattern = pattern + char(key);
            result_count = howm_isearch_do_search(pattern);
        }
    }
}

%% =============================================================================

define howm_initialize()
{
    howm_ensure_directory();
    message("Howm mode loaded. C-c ? for help in .howm files");
}


%% =============================================================================
%% Denote Tag/Keyword Filtering
%% =============================================================================

% Extract tags from Denote filename format: TIMESTAMP--title__tag1_tag2.howm
private define howm_extract_tags_from_filename(filename)
{
    variable tag_part, tags;
    variable underscore_pos = is_substr(filename, "__");
    
    if (underscore_pos == 0)
        return String_Type[0];  % No tags
    
    % Extract everything after __
    tag_part = substr(filename, underscore_pos + 2, strlen(filename));
    
    % Remove .howm extension
    variable dot_pos = is_substr(tag_part, ".");
    if (dot_pos > 0)
        tag_part = substr(tag_part, 1, dot_pos - 1);
    
    % Split by underscore
    tags = strchop(tag_part, '_', 0);
    return tags;
}

% Check if file has specific tag
private define howm_file_has_tag(filename, tag)
{
    variable tags = howm_extract_tags_from_filename(filename);
    variable i;
    
    _for i (0, length(tags)-1, 1)
    {
        if (tags[i] == tag)
            return 1;
    }
    return 0;
}

% Search filtered by tag
define howm_search_by_tag()
{
    variable tag = read_mini("Filter by tag: ", "", "");
    
    if (strlen(tag) == 0)
    {
        message("Search cancelled");
        return;
    }
    
    variable files, i, file, filepath, fp, line, line_num;
    variable results = String_Type[0];
    
    files = howm_list_files();
    
    % Filter files by tag first
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        
        if (not howm_file_has_tag(file, tag))
            continue;
        
        filepath = dircat(Howm_Directory, file);
        fp = fopen(filepath, "r");
        if (fp == NULL)
            continue;
        
        line_num = 0;
        while (-1 != fgets(&line, fp))
        {
            line_num++;
            % Add all lines from tagged files
            results = [results, sprintf("%s:%d: %s", file, line_num, strtrim(line))];
        }
        
        () = fclose(fp);
    }
    
    if (length(results) == 0)
    {
        message(sprintf("No files found with tag: %s", tag));
        return;
    }
    
    % Display results
    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert(sprintf("Files tagged with: %s (%d lines)\n", tag, length(results)));
    insert("================================================================\n\n");
    
    _for i (0, length(results)-1, 1)
        insert(results[i] + "\n");
    
    bob();
    howm_list_mode();
    message(sprintf("Found %d files with tag: %s", length(results), tag));
}

% Helper function for filtered search (must be defined before howm_isearch_by_tag)
private define howm_isearch_filtered_search(pattern, tag)
{
    variable files, results, i, file, filepath, fp, line, line_num;
    variable saved_buf = whatbuf();
    
    pop2buf(Howm_Isearch_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert(sprintf("Incremental Search (tag: %s): [%s]\n", tag, pattern));
    insert("================================================================\n");
    insert("Ctrl-N/P=navigate | RET=jump | ESC=cancel\n\n");
    
    if (strlen(pattern) < 2)
    {
        if (strlen(pattern) == 0)
            insert("Start typing...\n");
        else
            insert("Need 2+ characters...\n");
        bob();
        update(1);
        setbuf(saved_buf);
        return 0;
    }
    
    % Search only in tagged files
    files = howm_list_files();
    results = String_Type[0];
    
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        
        % Skip files without the tag
        if (not howm_file_has_tag(file, tag))
            continue;
        
        filepath = dircat(Howm_Directory, file);
        fp = fopen(filepath, "r");
        if (fp == NULL) continue;
        
        line_num = 0;
        while (-1 != fgets(&line, fp))
        {
            line_num++;
            if (is_substr(strlow(line), strlow(pattern)))
            {
                results = [results, sprintf("%s:%d: %s", file, line_num, strtrim(line))];
                if (length(results) >= 100) break;
            }
        }
        () = fclose(fp);
        if (length(results) >= 100) break;
    }
    
    % Display
    if (length(results) == 0)
    {
        insert("No matches.\n");
    }
    else
    {
        insert(sprintf("%d matches", length(results)));
        if (length(results) >= 100) insert(" (first 100)");
        insert(":\n\n");
        
        variable max = length(results);
        if (max > 100) max = 100;
        _for i (0, max-1, 1)
            insert(results[i] + "\n");
    }
    
    bob();
    goto_line(4);
    update(1);
    setbuf(saved_buf);
    update(1);
    
    return length(results);
}

% Incremental search filtered by tag
define howm_isearch_by_tag()
{
    variable tag = read_mini("Filter by tag: ", "", "");
    
    if (strlen(tag) == 0)
    {
        message("Search cancelled");
        return;
    }
    
    variable pattern = "";
    variable key, ch;
    variable orig_buf = whatbuf();
    variable created_split = 0;
    variable result_count = 0;
    
    % Create split
    if (nwindows() == 1)
    {
        splitwindow();
        created_split = 1;
    }
    
    % Setup results buffer
    pop2buf(Howm_Isearch_Buffer);
    set_readonly(0);
    erase_buffer();
    insert(sprintf("Incremental Search (tag: %s): []\n", tag));
    insert("================================================================\n");
    insert("Start typing... (RET=jump, Ctrl-G=browse, ESC=cancel)\n");
    bob();
    update(1);
    howm_list_mode();
    
    % Go back to original window
    otherwindow();
    setbuf(orig_buf);
    
    message(sprintf("Incremental search in tag '%s' (type to search)", tag));
    update(1);
    
    % Input loop - same as regular isearch but with tag filter
    forever
    {
        !if (input_pending(10))
            continue;
        
        key = getkey();
        
        % ESC - cancel
        if (key == 27)
        {
            if (created_split)
            {
                setbuf(Howm_Isearch_Buffer);
                delbuf(Howm_Isearch_Buffer);
                setbuf(orig_buf);
                onewindow();
            }
            message("Search cancelled");
            return;
        }
        
        % Ctrl-G - finish and browse
        if (key == 7)
        {
            if (result_count == 0)
            {
                if (created_split)
                {
                    setbuf(Howm_Isearch_Buffer);
                    delbuf(Howm_Isearch_Buffer);
                    setbuf(orig_buf);
                    onewindow();
                }
                message("No results to browse");
                return;
            }
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            message("Browse results (RET=jump, q=close)");
            return;
        }
        
        % RET - jump
        if (key == 13)
        {
            if (result_count == 0)
            {
                message("No results yet");
                continue;
            }
            
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            howm_list_jump_to_file();
            
            if (created_split)
            {
                setbuf(Howm_Isearch_Buffer);
                delbuf(Howm_Isearch_Buffer);
                onewindow();
            }
            return;
        }
        
        % Backspace
        if (key == 127 or key == 8)
        {
            if (strlen(pattern) > 0)
            {
                pattern = substr(pattern, 1, strlen(pattern)-1);
                result_count = howm_isearch_filtered_search(pattern, tag);
            }
            continue;
        }
        
        % Ctrl-N/P navigation
        if (key == 14)
        {
            variable saved_buf = whatbuf();
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            call("next_line_cmd");
            update(1);
            otherwindow();
            setbuf(saved_buf);
            continue;
        }
        
        if (key == 16)
        {
            saved_buf = whatbuf();
            otherwindow();
            setbuf(Howm_Isearch_Buffer);
            call("previous_line_cmd");
            update(1);
            otherwindow();
            setbuf(saved_buf);
            continue;
        }
        
        % Regular character - search
        if (key >= 32 and key < 127)
        {
            pattern = pattern + char(key);
            result_count = howm_isearch_filtered_search(pattern, tag);
        }
    }
}

% List all available tags
define howm_list_tags()
{
    variable files, i, file, tags, j;
    variable tag_counts = Assoc_Type[Int_Type];  % tag -> count
    variable tag, count;
    
    files = howm_list_files();
    
    % Collect all tags
    _for i (0, length(files)-1, 1)
    {
        file = files[i];
        tags = howm_extract_tags_from_filename(file);
        
        _for j (0, length(tags)-1, 1)
        {
            tag = tags[j];
            if (assoc_key_exists(tag_counts, tag))
                tag_counts[tag]++;
            else
                tag_counts[tag] = 1;
        }
    }
    
    % Get all tags and sort by count
    variable all_tags = assoc_get_keys(tag_counts);
    variable counts = Integer_Type[length(all_tags)];
    
    _for i (0, length(all_tags)-1, 1)
        counts[i] = tag_counts[all_tags[i]];
    
    % Simple bubble sort by count (descending)
    variable n = length(all_tags);
    variable swapped = 1;
    while (swapped)
    {
        swapped = 0;
        _for i (0, n-2, 1)
        {
            if (counts[i] < counts[i+1])
            {
                % Swap counts
                variable temp = counts[i];
                counts[i] = counts[i+1];
                counts[i+1] = temp;
                
                % Swap tags
                temp = all_tags[i];
                all_tags[i] = all_tags[i+1];
                all_tags[i+1] = temp;
                
                swapped = 1;
            }
        }
    }
    
    % Display
    pop2buf(Howm_List_Buffer);
    set_readonly(0);
    erase_buffer();
    
    insert(sprintf("Tags (%d unique)\n", length(all_tags)));
    insert("================================================================\n\n");
    
    if (length(all_tags) == 0)
    {
        insert("No tags found.\n");
    }
    else
    {
        _for i (0, length(all_tags)-1, 1)
        {
            insert(sprintf("  %-20s (%d files)\n", all_tags[i], counts[i]));
        }
    }
    
    bob();
    howm_list_mode();  % Enable list mode so 'q' works
    message(sprintf("Found %d unique tags", length(all_tags)));
}


