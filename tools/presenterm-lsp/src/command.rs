//! The presenterm comment-command grammar.
//!
//! This is a deliberate *mirror* of `src/presentation/builder/comment.rs` in
//! presenterm 0.16.1 (upstream rev 5f8add1). The enum, its `serde` attributes
//! and the `singleton_map` deserialization are copied verbatim so that the set
//! of comments this server accepts is exactly the set presenterm accepts. Any
//! hand-rolled parser would drift the moment upstream adds a variant or an
//! alias; copying the type means a drift shows up as a diff against a known
//! file rather than as a false diagnostic in someone's deck.
//!
//! When bumping the pinned presenterm version, diff this module against
//! upstream's `CommentCommand` and `should_ignore_comment`.

use serde::Deserialize;
use std::{fmt, num::NonZeroU8, path::PathBuf, str::FromStr};

/// Upstream presenterm version this grammar was mirrored from.
pub const MIRRORED_PRESENTERM_VERSION: &str = "0.16.1";

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommentCommand {
    Alignment(CommentCommandAlignment),
    Column(usize),
    EndSlide,
    FontSize(u8),
    Include(PathBuf),
    IncrementalLists(bool),
    IncrementalTables(bool),
    #[serde(rename = "column_layout")]
    InitColumnLayout(Vec<u8>),
    JumpToMiddle,
    ListItemNewlines(NonZeroU8),
    #[serde(alias = "newline")]
    NewLine,
    #[serde(alias = "newlines")]
    NewLines(u32),
    NoFooter,
    Pause,
    ResetLayout,
    SkipSlide,
    SpeakerNote(String),
    SnippetOutput(String),
    Comment(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CommentCommandAlignment {
    Left,
    Center,
    Right,
}

impl FromStr for CommentCommand {
    type Err = CommandParseError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        #[derive(Deserialize)]
        struct CommandWrapper(#[serde(with = "serde_yaml::with::singleton_map")] CommentCommand);

        let wrapper = serde_yaml::from_str::<CommandWrapper>(s)?;
        Ok(wrapper.0)
    }
}

#[derive(Debug)]
pub struct CommandParseError(serde_yaml::Error);

impl From<serde_yaml::Error> for CommandParseError {
    fn from(e: serde_yaml::Error) -> Self {
        Self(e)
    }
}

impl fmt::Display for CommandParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // presenterm strips serde_yaml's trailing "at line X, column Y" because
        // the YAML is parsed in isolation out of the HTML comment and so always
        // claims line 1. We report a real position via the LSP range instead.
        let inner = self.0.to_string();
        let inner = inner.split(" at line").next().unwrap_or(&inner);
        write!(f, "{inner}")
    }
}

/// Mirror of `PresentationBuilder::should_ignore_comment`.
///
/// A comment that fails to parse is only an error if presenterm would *not*
/// have ignored it. With the default (empty) `command_prefix` every comment
/// starts with the prefix, so the escape hatches are: multi-line comments,
/// `vim:` modelines, `{{{` / `}}}` fold markers and `//` prefixed comments.
// Upstream's branches are kept separate even though two of them return the
// same value: this function exists to be diffable against
// `PresentationBuilder::should_ignore_comment`, and collapsing it would hide
// the next upstream change to any one branch.
#[allow(clippy::if_same_then_else)]
pub fn should_ignore_comment(comment: &str, command_prefix: &str) -> bool {
    if comment.contains('\n') || !comment.starts_with(command_prefix) {
        true
    } else if comment.trim().starts_with("vim:") {
        true
    } else {
        let comment = comment.trim();
        comment == "{{{" || comment == "}}}" || comment.starts_with("//")
    }
}

/// One completion/hover entry. `insert` is the comment *body* (no delimiters);
/// callers wrap it depending on whether the user already typed `<!--`.
pub struct CommandDoc {
    pub label: &'static str,
    pub insert: &'static str,
    pub detail: &'static str,
    pub documentation: &'static str,
}

/// Documentation for every command, keyed by the identifier that appears
/// before the `:` (or the whole body for unit variants).
pub const COMMANDS: &[CommandDoc] = &[
    CommandDoc {
        label: "pause",
        insert: "pause",
        detail: "Pause the slide here",
        documentation: "Splits the slide into chunks. Everything after this point is revealed on the next key press.",
    },
    CommandDoc {
        label: "end_slide",
        insert: "end_slide",
        detail: "End the current slide",
        documentation: "Terminates the slide. The canonical slide separator; `---` only works when `options.end_slide_shorthand` is enabled.",
    },
    CommandDoc {
        label: "column_layout",
        insert: "column_layout: [1, 1]",
        detail: "Start a column layout",
        documentation: "Declares column widths as relative weights, e.g. `[1, 2]` gives a one-third / two-thirds split.\n\nMust have at least one column and no zero-sized columns. Enter a column with `column: <index>` before emitting any content.",
    },
    CommandDoc {
        label: "column",
        insert: "column: 0",
        detail: "Enter a layout column",
        documentation: "Switches to the zero-based column index. Requires an active `column_layout`; the index must be in range and must differ from the current column.",
    },
    CommandDoc {
        label: "reset_layout",
        insert: "reset_layout",
        detail: "Exit the column layout",
        documentation: "Leaves the current column layout and returns to full-width rendering.",
    },
    CommandDoc {
        label: "jump_to_middle",
        insert: "jump_to_middle",
        detail: "Vertically center what follows",
        documentation: "Jumps to the vertical center of the slide. Useful for title slides.",
    },
    CommandDoc {
        label: "no_footer",
        insert: "no_footer",
        detail: "Hide the footer on this slide",
        documentation: "Suppresses the theme's footer for the current slide only.",
    },
    CommandDoc {
        label: "skip_slide",
        insert: "skip_slide",
        detail: "Drop this slide from the deck",
        documentation: "The slide is built but not shown. Handy for parking work-in-progress content without deleting it.",
    },
    CommandDoc {
        label: "alignment",
        insert: "alignment: center",
        detail: "Set text alignment",
        documentation: "One of `left`, `center` or `right`. Applies to the remainder of the slide.",
    },
    CommandDoc {
        label: "font_size",
        insert: "font_size: 2",
        detail: "Set the font size (1-7)",
        documentation: "Requires a terminal with font-size support (kitty, WezTerm, Ghostty). Values outside 1-7 are rejected by presenterm.",
    },
    CommandDoc {
        label: "new_line",
        insert: "new_line",
        detail: "Insert one blank line",
        documentation: "Pushes a single line break, scaled by the slide's font size. Alias: `newline`.",
    },
    CommandDoc {
        label: "new_lines",
        insert: "new_lines: 2",
        detail: "Insert N blank lines",
        documentation: "Pushes N line breaks, scaled by the slide's font size. Alias: `newlines`.",
    },
    CommandDoc {
        label: "incremental_lists",
        insert: "incremental_lists: true",
        detail: "Reveal list items one at a time",
        documentation: "Implicitly inserts a pause between list items for the rest of the slide.",
    },
    CommandDoc {
        label: "incremental_tables",
        insert: "incremental_tables: true",
        detail: "Reveal table rows one at a time",
        documentation: "Implicitly inserts a pause between table rows for the rest of the slide.",
    },
    CommandDoc {
        label: "list_item_newlines",
        insert: "list_item_newlines: 2",
        detail: "Blank lines between list items",
        documentation: "Number of newlines between list items. Must be >= 1.",
    },
    CommandDoc {
        label: "speaker_note",
        insert: "speaker_note: ",
        detail: "Add a speaker note",
        documentation: "Rendered only in speaker-notes mode (`--publish-speaker-notes` / `--listen-speaker-notes`), never in the deck itself.",
    },
    CommandDoc {
        label: "include",
        insert: "include: ",
        detail: "Include another markdown file",
        documentation: "Splices another markdown file in at this point. The path is relative to the *including* file. Included files must not carry a front matter, and cycles are rejected.",
    },
    CommandDoc {
        label: "snippet_output",
        insert: "snippet_output: ",
        detail: "Show the output of a snippet",
        documentation: "Renders the output of an earlier `+exec +id:<name>` snippet. Only takes effect when snippet execution is enabled (`-x`).",
    },
    CommandDoc {
        label: "comment",
        insert: "comment: ",
        detail: "A no-op author comment",
        documentation: "Explicitly marks the comment as prose for the author. Parsed and discarded - the safe way to leave a note that can never be mistaken for a typo'd command.",
    },
];

/// Built-in theme names shipped with presenterm 0.16.1 (`themes/*.yaml`).
pub const BUILTIN_THEMES: &[&str] = &[
    "catppuccin-frappe",
    "catppuccin-latte",
    "catppuccin-macchiato",
    "catppuccin-mocha",
    "dark",
    "gruvbox-dark",
    "light",
    "terminal-dark",
    "terminal-light",
    "tokyonight-day",
    "tokyonight-moon",
    "tokyonight-night",
    "tokyonight-storm",
];

/// Keys accepted at the top level of a deck's front matter
/// (`PresentationMetadata` in upstream `src/presentation/mod.rs`).
pub const FRONT_MATTER_KEYS: &[(&str, &str)] = &[
    ("title", "The presentation title"),
    ("sub_title", "The presentation sub-title"),
    ("event", "The event this is presented at"),
    ("location", "Where the event takes place"),
    ("date", "The presentation date"),
    ("author", "A single author"),
    ("authors", "A list of authors (mutually exclusive with `author`)"),
    ("theme", "Theme selection: `name`, `path` and/or `override`"),
    ("options", "Per-deck overrides of presenterm's options"),
];

/// Keys accepted under `options` (`OptionsConfig` in upstream `src/config.rs`).
pub const OPTIONS_KEYS: &[(&str, &str)] = &[
    ("implicit_slide_ends", "Terminate a slide when a title is found"),
    ("command_prefix", "Required prefix for comment commands, e.g. `cmd:`"),
    ("image_attributes_prefix", "Prefix for image attributes (default `image:`)"),
    ("incremental_lists", "Reveal list items one at a time, deck-wide"),
    ("incremental_tables", "Reveal table rows one at a time, deck-wide"),
    ("list_item_newlines", "Newlines between list items"),
    ("end_slide_shorthand", "Treat a thematic break (`---`) as a slide end"),
    ("strict_front_matter_parsing", "Reject unknown front matter keys (default true)"),
    ("auto_render_languages", "Languages whose snippets are rendered without `+render`"),
    ("h1_slide_titles", "Treat the first h1 on a slide as its title"),
];

#[cfg(test)]
mod tests {
    use super::*;

    /// The cases upstream asserts in `comment::tests::command_formatting`.
    #[test]
    fn parses_upstream_cases() {
        assert_eq!("pause".parse::<CommentCommand>().unwrap(), CommentCommand::Pause);
        assert_eq!(" pause ".parse::<CommentCommand>().unwrap(), CommentCommand::Pause);
        assert_eq!("end_slide".parse::<CommentCommand>().unwrap(), CommentCommand::EndSlide);
        assert_eq!(
            "column_layout: [1, 2]".parse::<CommentCommand>().unwrap(),
            CommentCommand::InitColumnLayout(vec![1, 2])
        );
        assert_eq!("column: 1".parse::<CommentCommand>().unwrap(), CommentCommand::Column(1));
        assert_eq!("reset_layout".parse::<CommentCommand>().unwrap(), CommentCommand::ResetLayout);
        assert_eq!(
            "incremental_lists: true".parse::<CommentCommand>().unwrap(),
            CommentCommand::IncrementalLists(true)
        );
        assert_eq!("new_lines: 2".parse::<CommentCommand>().unwrap(), CommentCommand::NewLines(2));
        assert_eq!("newlines: 2".parse::<CommentCommand>().unwrap(), CommentCommand::NewLines(2));
        assert_eq!("new_line".parse::<CommentCommand>().unwrap(), CommentCommand::NewLine);
        assert_eq!("newline".parse::<CommentCommand>().unwrap(), CommentCommand::NewLine);
        assert_eq!(
            "comment: This is a user comment".parse::<CommentCommand>().unwrap(),
            CommentCommand::Comment("This is a user comment".into())
        );
    }

    #[test]
    fn rejects_typos() {
        assert!("pasue".parse::<CommentCommand>().is_err());
        assert!("end slide".parse::<CommentCommand>().is_err());
    }

    /// The cases upstream asserts in `comment::tests::ignore_comments`.
    #[test]
    fn ignore_rules_match_upstream() {
        for comment in ["hello\nworld", "{{{", "}}}", "vim: hi", "// a user comment", "  // padded  "] {
            assert!(should_ignore_comment(comment, ""), "{comment:?} should be ignored");
        }
        // `comment:` is not *ignored* - it parses into a real no-op variant.
        assert!(!should_ignore_comment("comment: hi", ""));
        assert!("comment: hi".parse::<CommentCommand>().is_ok());
    }

    #[test]
    fn command_prefix_gates_parsing() {
        assert!(should_ignore_comment("random", "cmd:"));
        assert!(!should_ignore_comment("cmd:bogus", "cmd:"));
    }

    #[test]
    fn every_command_sample_parses() {
        for doc in COMMANDS {
            let body = doc.insert.trim_end();
            // Samples that end in `: ` need a value to be valid YAML.
            let body = if doc.insert.ends_with(": ") { format!("{body} placeholder") } else { body.to_string() };
            assert!(body.parse::<CommentCommand>().is_ok(), "sample {body:?} does not parse");
        }
    }
}
