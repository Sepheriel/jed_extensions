% =============================================================================
%  nordic-dusk.sl  –  Ein modernes Dark-Mode-Farbschema für den JED Editor
% =============================================================================
%
%  Inspiriert von Nord, Tokyo Night und Catppuccin Mocha.
%  Benötigt einen Terminal mit True-Color- oder 256-Farben-Unterstützung.
%
%  INSTALLATION:
%  1. Datei kopieren nach:  ~/.jed/colors/nordic-dusk.sl
%  2. In der ~/.jedrc eintragen:
%
%       Color_Scheme_Path = expand_filename("~/.jed/colors") + "," + Jed_Lib_Dir + "/colors";
%       set_color_scheme("nordic-dusk");
%
% =============================================================================

static variable bg      = "#1e2030";   % Hintergrund – tiefes Mitternachtsblau
static variable surface = "#2d3149";   % Menü-Hintergrund
static variable subtle  = "#444b6a";   % gedimmte Elemente (Tabs etc.)
static variable fg      = "#c8d3f5";   % normaler Text
static variable fg2     = "#e2e8ff";   % heller Text / Cursor

static variable kw      = "#86e1fc";   % keywords – türkis
static variable ty      = "#fca7ea";   % Typen – rosa
static variable fn      = "#82aaff";   % Funktionen – blau
static variable str     = "#c3e88d";   % Strings – grün
static variable num     = "#ff966c";   % Zahlen – orange
static variable op      = "#89ddff";   % Operatoren – eisblau
static variable pre     = "#ffc777";   % Präprozessor – amber
static variable cmt     = "#636da6";   % Kommentare – gedimmtes blauviolett
static variable err     = "#ff5370";   % Fehler – rot
static variable sel     = "#2d4070";   % Selektion Hintergrund

% ── Grundfarben ──────────────────────────────────────────────────────────────
set_color("normal",              fg,      bg);
set_color("cursor",              bg,      fg2);
set_color("cursorovr",           bg,      pre);
set_color("region",              fg2,     sel);

% ── Statusleiste ─────────────────────────────────────────────────────────────
set_color("status",              fn,      bg);

% ── Menü ─────────────────────────────────────────────────────────────────────
set_color("menu_char",           pre,     surface);
set_color("menu",                fg,      surface);
set_color("menu_popup",          fg,      surface);
set_color("menu_shadow",         cmt,     bg);
set_color("menu_selection",      bg,      op);
set_color("menu_selection_char", err,     op);

% ── Meldungen ────────────────────────────────────────────────────────────────
set_color("message",             str,     bg);
set_color("error",               err,     bg);

% ── Syntax-Highlighting ──────────────────────────────────────────────────────
set_color("keyword",             kw,      bg);   % if, else, while, for ...
set_color("keyword1",            ty,      bg);   % Typen: int, char, class ...
set_color("keyword2",            fn,      bg);   % Funktionen, Builtins
set_color("keyword3",            op,      bg);   % Makros, Annotationen
set_color("keyword4",            pre,     bg);   % Konstanten: true, false, null ...
set_color("keyword5",            str,     bg);
set_color("keyword6",            num,     bg);
set_color("keyword7",            kw,      bg);
set_color("keyword8",            ty,      bg);
set_color("keyword9",            fn,      bg);

set_color("string",              str,     bg);   % "Strings"
set_color("number",              num,     bg);   % 42, 3.14, 0xFF ...
set_color("comment",             cmt,     bg);   % /* ... */ und // ...
set_color("operator",            op,      bg);   % + - * / = < > ...
set_color("delimiter",           fg,      bg);   % {}[](),.;
set_color("preprocess",          pre,     bg);   % #include, #define ...
set_color("dollar",              fn,      bg);   % $-Zeichen
set_color("...",                 pre,     bg);   % Fold-Indikator

% ── Markup / Dokumentformate ─────────────────────────────────────────────────
set_color("html",                ty,      bg);
set_color("italic",              kw,      bg);
set_color("underline",           pre,     bg);
set_color("bold",                fg2,     bg);
set_color("url",                 fn,      bg);

% ── Whitespace-Visualisierung ────────────────────────────────────────────────
set_color("trailing_whitespace", err,     bg);
set_color("tab",                 subtle,  bg);

% ── Zeilennummern ────────────────────────────────────────────────────────────
set_color("linenum",             cmt,     bg);

% =============================================================================
%  Ende von nordic-dusk.sl
% =============================================================================

