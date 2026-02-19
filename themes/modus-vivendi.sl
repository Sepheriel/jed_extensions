% =============================================================================
%  modus-vivendi.sl  –  JED-Portierung des Emacs Modus Vivendi Themes
% =============================================================================
%
%  Originaltheme von Protesilaos Stavrou (https://protesilaos.com/modus-themes)
%  WCAG AAA konform – hoher Kontrast für maximale Lesbarkeit.
%
%  INSTALLATION:
%  1. Datei kopieren nach:  ~/.jed/colors/modus-vivendi.sl
%  2. In der ~/.jedrc eintragen:
%
%       Color_Scheme_Path = expand_filename("~/.jed/colors") + "," + Jed_Lib_Dir + "/colors";
%       set_color_scheme("modus-vivendi");
%
% =============================================================================
%
%  FARBPALETTE (direkt aus modus-vivendi):
%
%  bg-main      #000000   reines Schwarz
%  bg-dim       #1e1e1e   gedimmter Hintergrund (Menüs)
%  bg-alt       #2a2a2a   alternative Oberfläche
%  fg-main      #ffffff   normaler Text
%  fg-dim       #989898   gedimmter Text
%
%  red          #ff8059   warmes Rot
%  red-warmer   #ff4f4f   kräftiges Rot (Fehler)
%  green        #44bc44   sattes Grün
%  green-alt    #80d200   helles Grün
%  yellow       #eecc00   kräftiges Gelb
%  yellow-alt   #cfdf30   helles Gelb
%  blue         #2fafff   mittleres Blau
%  blue-warmer  #79a8ff   warmes Blau (Keywords)
%  magenta      #feacd0   zartes Rosa
%  magenta-alt  #f78fe7   kräftiges Magenta
%  cyan         #00d3d0   leuchtendes Cyan
%  cyan-alt     #4ae8fc   helles Cyan
%
% =============================================================================

static variable bg      = "#000000";   % bg-main
static variable bg_dim  = "#1e1e1e";   % bg-dim  – Menühintergrund
static variable bg_alt  = "#2a2a2a";   % bg-alt  – Selektion, Cursor
static variable bg_sel  = "#2f3f5f";   % bg-blue-subtle – Selektion
static variable fg      = "#ffffff";   % fg-main
static variable fg_dim  = "#989898";   % fg-dim  – Kommentare, gedimmt

static variable red     = "#ff8059";   % red
static variable red_str = "#ff4f4f";   % red-warmer – Fehler
static variable green   = "#44bc44";   % green – Strings
static variable green2  = "#80d200";   % green-alt – Messages
static variable yellow  = "#eecc00";   % yellow – Zahlen, Präprozessor
static variable yellow2 = "#cfdf30";   % yellow-alt
static variable blue    = "#2fafff";   % blue – Funktionen
static variable blue2   = "#79a8ff";   % blue-warmer – Keywords
static variable magenta = "#feacd0";   % magenta – Typen
static variable magenta2= "#f78fe7";   % magenta-alt
static variable cyan    = "#00d3d0";   % cyan – Operatoren
static variable cyan2   = "#4ae8fc";   % cyan-alt

% ── Grundfarben ──────────────────────────────────────────────────────────────
set_color("normal",              fg,       bg);
set_color("cursor",              bg,       cyan2);
set_color("cursorovr",           bg,       yellow);
set_color("region",              fg,       bg_sel);

% ── Statusleiste ─────────────────────────────────────────────────────────────
set_color("status",              bg,       fg_dim);

% ── Menü ─────────────────────────────────────────────────────────────────────
set_color("menu_char",           yellow,   bg_dim);
set_color("menu",                fg,       bg_dim);
set_color("menu_popup",          fg,       bg_dim);
set_color("menu_shadow",         fg_dim,   bg);
set_color("menu_selection",      bg,       cyan);
set_color("menu_selection_char", yellow,   cyan);

% ── Meldungen ────────────────────────────────────────────────────────────────
set_color("message",             green2,   bg);
set_color("error",               red_str,  bg);

% ── Syntax-Highlighting ──────────────────────────────────────────────────────
set_color("keyword",             blue2,    bg);   % if, else, while – blue-warmer
set_color("keyword1",            magenta,  bg);   % Typen – magenta
set_color("keyword2",            blue,     bg);   % Funktionen – blue
set_color("keyword3",            cyan,     bg);   % Makros – cyan
set_color("keyword4",            yellow2,  bg);   % Konstanten – yellow-alt
set_color("keyword5",            green,    bg);
set_color("keyword6",            red,      bg);
set_color("keyword7",            blue2,    bg);
set_color("keyword8",            magenta2, bg);
set_color("keyword9",            cyan2,    bg);

set_color("string",              green,    bg);   % Strings – green
set_color("number",              yellow,   bg);   % Zahlen – yellow
set_color("comment",             fg_dim,   bg);   % Kommentare – fg-dim
set_color("operator",            cyan,     bg);   % Operatoren – cyan
set_color("delimiter",           fg,       bg);   % {}[](),.;
set_color("preprocess",          red,      bg);   % #include – red
set_color("dollar",              blue,     bg);   % $-Zeichen
set_color("...",                 fg_dim,   bg);   % Fold-Indikator

% ── Markup / Dokumentformate ─────────────────────────────────────────────────
set_color("html",                magenta,  bg);
set_color("italic",              blue2,    bg);
set_color("underline",           yellow,   bg);
set_color("bold",                fg,       bg);
set_color("url",                 blue,     bg);

% ── Whitespace-Visualisierung ────────────────────────────────────────────────
set_color("trailing_whitespace", red_str,  bg);
set_color("tab",                 bg_alt,   bg);

% ── Zeilennummern ────────────────────────────────────────────────────────────
set_color("linenum",             fg_dim,   bg);

% =============================================================================
%  Ende von modus-vivendi.sl
% =============================================================================
