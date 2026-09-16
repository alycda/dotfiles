//! Deck semantics: slide segmentation and the diagnostics presenterm itself
//! would raise.
//!
//! presenterm builds a deck eagerly and returns on the *first* error, so a
//! typo on slide 2 hides everything after it. This walks the whole document
//! and collects every problem, which is the whole point of doing it in an
//! editor.

use crate::command::{should_ignore_comment, CommentCommand, BUILTIN_THEMES, FRONT_MATTER_KEYS, OPTIONS_KEYS};
use crate::document::{scan, Element, Span};
use std::{
    collections::{hash_map::Entry, HashMap, HashSet},
    path::{Path, PathBuf},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Severity {
    Error,
    Warning,
    Hint,
}

#[derive(Debug, Clone)]
pub struct Diagnostic {
    pub span: Span,
    pub severity: Severity,
    pub code: &'static str,
    pub message: String,
}

/// A resolved link out of the document, for go-to-definition.
#[derive(Debug, Clone)]
pub struct Link {
    pub span: Span,
    pub target: PathBuf,
}

#[derive(Debug, Clone)]
pub struct Slide {
    pub index: usize,
    pub title: Option<String>,
    pub span: Span,
}

#[derive(Debug, Clone, Default)]
pub struct DeckOptions {
    pub command_prefix: String,
    pub image_attributes_prefix: String,
    pub end_slide_shorthand: bool,
    pub implicit_slide_ends: bool,
    pub h1_slide_titles: bool,
    pub strict_front_matter_parsing: bool,
}

impl DeckOptions {
    /// Mirrors `PresentationBuilderOptions::default()` plus presenterm's
    /// config-level defaults (`main.rs::make_builder_options`).
    fn presenterm_defaults() -> Self {
        Self {
            command_prefix: String::new(),
            image_attributes_prefix: "image:".to_string(),
            end_slide_shorthand: false,
            implicit_slide_ends: false,
            h1_slide_titles: false,
            strict_front_matter_parsing: true,
        }
    }
}

#[derive(Debug, Default)]
pub struct Analysis {
    pub diagnostics: Vec<Diagnostic>,
    pub slides: Vec<Slide>,
    pub links: Vec<Link>,
    pub options: DeckOptions,
    /// False when the document shows no sign of being a presenterm deck, in
    /// which case callers should publish no diagnostics at all.
    pub is_deck: bool,
}

/// Analyse `text`. `path` is the document's own path, used to resolve
/// `include:` targets and image paths relative to it; pass `None` for
/// unsaved buffers, which disables the on-disk existence checks.
pub fn analyze(text: &str, path: Option<&Path>) -> Analysis {
    analyze_with(text, path, false)
}

/// As [`analyze`], but `force` keeps diagnostics even when the document shows
/// no sign of being a deck. `--check FILE` is an explicit assertion that the
/// file *is* one, so the heuristic must not silently swallow its errors.
pub fn analyze_with(text: &str, path: Option<&Path>, force: bool) -> Analysis {
    let mut visiting = HashSet::new();
    if let Some(path) = path {
        if let Ok(canonical) = path.canonicalize() {
            visiting.insert(canonical);
        }
    }
    let mut analysis = analyze_inner(text, path, &mut visiting, force);
    analysis.is_deck |= force;
    analysis
}

fn analyze_inner(text: &str, path: Option<&Path>, visiting: &mut HashSet<PathBuf>, force: bool) -> Analysis {
    let elements = scan(text);
    let mut analysis = Analysis { options: DeckOptions::presenterm_defaults(), ..Default::default() };
    let base = path.and_then(|path| path.parent()).map(Path::to_path_buf);

    // Front matter first: it can change how everything after it parses.
    if let Some(Element::FrontMatter { body, body_span, .. }) = elements.first() {
        analysis.is_deck = true;
        check_front_matter(body, body_span, &mut analysis);
    }

    let mut layout = LayoutState::Default;
    let mut needs_enter_column: Option<Span> = None;
    let mut slide_start = 0usize;
    let mut slide_title: Option<String> = None;
    let mut snippet_ids: HashMap<String, Span> = HashMap::new();
    let mut requested_outputs: Vec<(String, Span)> = Vec::new();

    for element in &elements {
        match element {
            Element::FrontMatter { .. } => {}

            Element::Comment { body, body_span, .. } => {
                let trimmed = body.trim();
                let stripped = trimmed.strip_prefix(&analysis.options.command_prefix).unwrap_or(trimmed);
                let command = match stripped.parse::<CommentCommand>() {
                    Ok(command) => command,
                    Err(error) => {
                        if !should_ignore_comment(trimmed, &analysis.options.command_prefix) {
                            // Deliberately does *not* set `is_deck`: a broken
                            // comment is not evidence of a deck, otherwise a
                            // stray `<!-- pasue -->` in a blog post would
                            // switch the whole server on. Positive evidence
                            // only - front matter or a command that parses.
                            analysis.diagnostics.push(Diagnostic {
                                span: body_span.clone(),
                                severity: Severity::Error,
                                code: "invalid-command",
                                message: format!("invalid command: {error}{}", suggest(stripped)),
                            });
                        }
                        continue;
                    }
                };
                if !matches!(command, CommentCommand::Comment(_)) {
                    analysis.is_deck = true;
                }
                apply_command(
                    &command,
                    body_span,
                    &mut layout,
                    &mut needs_enter_column,
                    &mut analysis,
                    base.as_deref(),
                    visiting,
                    &mut requested_outputs,
                );
                if matches!(command, CommentCommand::EndSlide) {
                    push_slide(&mut analysis, &mut slide_start, &mut slide_title, element.span().end);
                    layout = LayoutState::Default;
                    needs_enter_column = None;
                }
            }

            Element::ThematicBreak { span } => {
                if analysis.options.end_slide_shorthand {
                    push_slide(&mut analysis, &mut slide_start, &mut slide_title, span.end);
                    layout = LayoutState::Default;
                    needs_enter_column = None;
                }
            }

            Element::Heading { level, text, span } => {
                let is_title = *level == 1 && analysis.options.h1_slide_titles;
                if analysis.options.implicit_slide_ends && is_title && slide_title.is_some() {
                    push_slide(&mut analysis, &mut slide_start, &mut slide_title, span.start);
                }
                if slide_title.is_none() {
                    slide_title = Some(text.clone());
                }
                check_enter_column(element, &mut needs_enter_column, &mut analysis);
            }

            Element::Image { alt, alt_span, path: target, path_span, .. } => {
                check_enter_column(element, &mut needs_enter_column, &mut analysis);
                check_image_attributes(alt, alt_span, &analysis.options.image_attributes_prefix.clone(), &mut analysis);
                check_image_path(target, path_span, base.as_deref(), &mut analysis);
            }

            Element::Snippet { info, info_span, .. } => {
                check_enter_column(element, &mut needs_enter_column, &mut analysis);
                check_snippet(info, info_span, &mut snippet_ids, &mut analysis);
            }

            Element::Content { .. } => check_enter_column(element, &mut needs_enter_column, &mut analysis),
        }
    }

    push_slide(&mut analysis, &mut slide_start, &mut slide_title, text.len());

    for (id, span) in requested_outputs {
        if !snippet_ids.contains_key(&id) {
            analysis.diagnostics.push(Diagnostic {
                span,
                severity: Severity::Warning,
                code: "undefined-snippet-id",
                message: format!(
                    "snippet id '{id}' is not defined by any `+exec +id:{id}` block (presenterm errors on this when run with -x)"
                ),
            });
        }
    }

    if !analysis.is_deck && !force {
        analysis.diagnostics.clear();
    }
    analysis
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum LayoutState {
    Default,
    InLayout { columns: usize },
    InColumn { column: usize, columns: usize },
}

#[allow(clippy::too_many_arguments)]
fn apply_command(
    command: &CommentCommand,
    span: &Span,
    layout: &mut LayoutState,
    needs_enter_column: &mut Option<Span>,
    analysis: &mut Analysis,
    base: Option<&Path>,
    visiting: &mut HashSet<PathBuf>,
    requested_outputs: &mut Vec<(String, Span)>,
) {
    match command {
        CommentCommand::InitColumnLayout(columns) => {
            // `validate_column_layout` upstream.
            if columns.is_empty() {
                analysis.diagnostics.push(Diagnostic {
                    span: span.clone(),
                    severity: Severity::Error,
                    code: "invalid-layout",
                    message: "invalid layout: need at least one column".to_string(),
                });
                return;
            }
            if columns.contains(&0) {
                analysis.diagnostics.push(Diagnostic {
                    span: span.clone(),
                    severity: Severity::Error,
                    code: "invalid-layout",
                    message: "invalid layout: can't have zero sized columns".to_string(),
                });
                return;
            }
            *layout = LayoutState::InLayout { columns: columns.len() };
            *needs_enter_column = Some(span.clone());
        }

        CommentCommand::ResetLayout => {
            *layout = LayoutState::Default;
            *needs_enter_column = None;
        }

        CommentCommand::Column(column) => {
            let (current, columns) = match *layout {
                LayoutState::InColumn { column, columns } => (Some(column), columns),
                LayoutState::InLayout { columns } => (None, columns),
                LayoutState::Default => {
                    analysis.diagnostics.push(Diagnostic {
                        span: span.clone(),
                        severity: Severity::Error,
                        code: "no-layout",
                        message: "can't enter layout column: no layout defined (add a `column_layout` first)"
                            .to_string(),
                    });
                    return;
                }
            };
            if current == Some(*column) {
                analysis.diagnostics.push(Diagnostic {
                    span: span.clone(),
                    severity: Severity::Error,
                    code: "already-in-column",
                    message: "can't enter layout column: already in it".to_string(),
                });
                return;
            }
            if *column >= columns {
                analysis.diagnostics.push(Diagnostic {
                    span: span.clone(),
                    severity: Severity::Error,
                    code: "column-index-too-large",
                    message: format!(
                        "can't enter layout column: column index too large ({column} >= {columns} column{})",
                        if columns == 1 { "" } else { "s" }
                    ),
                });
                return;
            }
            *layout = LayoutState::InColumn { column: *column, columns };
            *needs_enter_column = None;
        }

        CommentCommand::FontSize(size) => {
            if *size == 0 || *size > 7 {
                analysis.diagnostics.push(Diagnostic {
                    span: span.clone(),
                    severity: Severity::Error,
                    code: "invalid-font-size",
                    message: "font sizes must be >= 1 and <= 7".to_string(),
                });
            }
        }

        CommentCommand::Include(target) => check_include(target, span, base, visiting, analysis),

        CommentCommand::SnippetOutput(id) => requested_outputs.push((id.clone(), span.clone())),

        CommentCommand::Alignment(_)
        | CommentCommand::EndSlide
        | CommentCommand::IncrementalLists(_)
        | CommentCommand::IncrementalTables(_)
        | CommentCommand::JumpToMiddle
        | CommentCommand::ListItemNewlines(_)
        | CommentCommand::NewLine
        | CommentCommand::NewLines(_)
        | CommentCommand::NoFooter
        | CommentCommand::Pause
        | CommentCommand::SkipSlide
        | CommentCommand::SpeakerNote(_)
        | CommentCommand::Comment(_) => {}
    }
}

/// Mirrors `validate_last_operation`: once a layout is declared, the next thing
/// that renders must be a `column:` (or a `reset_layout`).
fn check_enter_column(element: &Element, needs_enter_column: &mut Option<Span>, analysis: &mut Analysis) {
    if !element.is_renderable() {
        return;
    }
    let Some(layout_span) = needs_enter_column.take() else { return };
    analysis.diagnostics.push(Diagnostic {
        span: element.span(),
        severity: Severity::Error,
        code: "not-inside-column",
        message: "content must be inside a column: enter one with `<!-- column: 0 -->` after declaring the layout"
            .to_string(),
    });
    analysis.diagnostics.push(Diagnostic {
        span: layout_span,
        severity: Severity::Hint,
        code: "not-inside-column",
        message: "layout was created here".to_string(),
    });
}

fn push_slide(analysis: &mut Analysis, start: &mut usize, title: &mut Option<String>, end: usize) {
    if end <= *start && analysis.slides.is_empty() && title.is_none() {
        return;
    }
    let index = analysis.slides.len();
    analysis.slides.push(Slide { index, title: title.take(), span: *start..end.max(*start) });
    *start = end;
}

fn check_front_matter(body: &str, span: &Span, analysis: &mut Analysis) {
    let value: serde_yaml::Value = match serde_yaml::from_str(body) {
        Ok(value) => value,
        Err(error) => {
            analysis.diagnostics.push(Diagnostic {
                span: span.clone(),
                severity: Severity::Error,
                code: "front-matter-yaml",
                message: format!("invalid front matter: {error}"),
            });
            return;
        }
    };
    let Some(map) = value.as_mapping() else { return };

    for (key, value) in map {
        let Some(key) = key.as_str() else { continue };
        if key == "options" {
            if let Some(options) = value.as_mapping() {
                read_options(options, span, analysis);
            }
            continue;
        }
        if key == "theme" {
            check_theme(value, span, analysis);
            continue;
        }
        if !FRONT_MATTER_KEYS.iter().any(|(known, _)| *known == key) {
            // `strict_front_matter_parsing` defaults to true, and it is read
            // from this very block, so this check runs after `read_options`
            // only for keys that follow `options`. Report it as a warning
            // rather than an error to stay useful under either setting.
            analysis.diagnostics.push(Diagnostic {
                span: span.clone(),
                severity: Severity::Warning,
                code: "unknown-front-matter-key",
                message: format!(
                    "unknown front matter key `{key}`; presenterm rejects this unless `options.strict_front_matter_parsing` is false"
                ),
            });
        }
    }
}

fn read_options(options: &serde_yaml::Mapping, span: &Span, analysis: &mut Analysis) {
    for (key, value) in options {
        let Some(key) = key.as_str() else { continue };
        match key {
            "command_prefix" => {
                if let Some(prefix) = value.as_str() {
                    analysis.options.command_prefix = prefix.to_string();
                }
            }
            "image_attributes_prefix" => {
                if let Some(prefix) = value.as_str() {
                    analysis.options.image_attributes_prefix = prefix.to_string();
                }
            }
            "end_slide_shorthand" => analysis.options.end_slide_shorthand = value.as_bool().unwrap_or(false),
            "implicit_slide_ends" => analysis.options.implicit_slide_ends = value.as_bool().unwrap_or(false),
            "h1_slide_titles" => analysis.options.h1_slide_titles = value.as_bool().unwrap_or(false),
            "strict_front_matter_parsing" => {
                analysis.options.strict_front_matter_parsing = value.as_bool().unwrap_or(true)
            }
            _ if OPTIONS_KEYS.iter().any(|(known, _)| *known == key) => {}
            _ => analysis.diagnostics.push(Diagnostic {
                span: span.clone(),
                severity: Severity::Warning,
                code: "unknown-option",
                message: format!("unknown option `{key}`"),
            }),
        }
    }
}

fn check_theme(theme: &serde_yaml::Value, span: &Span, analysis: &mut Analysis) {
    let Some(map) = theme.as_mapping() else { return };
    let has_path = map.get(serde_yaml::Value::from("path")).is_some();
    let Some(name) = map.get(serde_yaml::Value::from("name")).and_then(|value| value.as_str()) else {
        return;
    };
    if BUILTIN_THEMES.contains(&name) || has_path {
        return;
    }
    let hint = closest(name, BUILTIN_THEMES).map(|best| format!(", did you mean `{best}`?")).unwrap_or_default();
    analysis.diagnostics.push(Diagnostic {
        span: span.clone(),
        severity: Severity::Error,
        code: "unknown-theme",
        message: format!("unknown theme `{name}`{hint} Built-in themes: {}", BUILTIN_THEMES.join(", ")),
    });
}

fn check_include(
    target: &Path,
    span: &Span,
    base: Option<&Path>,
    visiting: &mut HashSet<PathBuf>,
    analysis: &mut Analysis,
) {
    let Some(base) = base else { return };
    let resolved = base.join(target);
    let canonical = match resolved.canonicalize() {
        Ok(canonical) => canonical,
        Err(error) => {
            analysis.diagnostics.push(Diagnostic {
                span: span.clone(),
                severity: Severity::Error,
                code: "include-missing",
                message: format!("could not read included markdown file {}: {error}", resolved.display()),
            });
            return;
        }
    };

    analysis.links.push(Link { span: span.clone(), target: canonical.clone() });

    if !visiting.insert(canonical.clone()) {
        analysis.diagnostics.push(Diagnostic {
            span: span.clone(),
            severity: Severity::Error,
            code: "include-cycle",
            message: format!("cannot include {}: it was already imported", resolved.display()),
        });
        return;
    }

    let contents = match std::fs::read_to_string(&canonical) {
        Ok(contents) => contents,
        Err(error) => {
            analysis.diagnostics.push(Diagnostic {
                span: span.clone(),
                severity: Severity::Error,
                code: "include-missing",
                message: format!("could not read included markdown file {}: {error}", resolved.display()),
            });
            visiting.remove(&canonical);
            return;
        }
    };

    let nested = analyze_inner(&contents, Some(&canonical), visiting, true);
    visiting.remove(&canonical);

    if matches!(scan(&contents).first(), Some(Element::FrontMatter { .. })) {
        analysis.diagnostics.push(Diagnostic {
            span: span.clone(),
            severity: Severity::Error,
            code: "include-front-matter",
            message: "included markdown files cannot contain a front matter".to_string(),
        });
    }

    // Surface the *count* of problems in the included file rather than
    // re-positioning its diagnostics into this document, which would put
    // squiggles on the wrong text. Go-to-definition takes you there.
    let errors = nested.diagnostics.iter().filter(|d| d.severity == Severity::Error).count();
    if errors > 0 {
        analysis.diagnostics.push(Diagnostic {
            span: span.clone(),
            severity: Severity::Warning,
            code: "include-has-errors",
            message: format!(
                "included file {} has {errors} error{}",
                resolved.display(),
                if errors == 1 { "" } else { "s" }
            ),
        });
    }
}

fn check_image_path(target: &str, span: &Span, base: Option<&Path>, analysis: &mut Analysis) {
    let target = target.split_whitespace().next().unwrap_or(target);
    if target.is_empty() || target.contains("://") || target.starts_with("data:") {
        return;
    }
    let Some(base) = base else { return };
    let resolved = base.join(target);
    if resolved.is_file() {
        analysis.links.push(Link { span: span.clone(), target: resolved });
        return;
    }
    analysis.diagnostics.push(Diagnostic {
        span: span.clone(),
        severity: Severity::Error,
        code: "image-missing",
        message: format!("could not load image '{target}': no such file"),
    });
}

/// Mirrors `parse_image_attributes` / `parse_image_attribute`.
fn check_image_attributes(alt: &str, span: &Span, prefix: &str, analysis: &mut Analysis) {
    let mut offset = 0usize;
    for attribute in alt.split(',') {
        let attribute_start = span.start + offset;
        offset += attribute.len() + 1;
        let Some((before, after)) = attribute.split_once(prefix) else { continue };
        if !before.is_empty() || (prefix.is_empty() && after.is_empty()) {
            continue;
        }
        let attribute_span = attribute_start..attribute_start + attribute.len();
        let Some((key, value)) = after.split_once(':') else {
            analysis.diagnostics.push(Diagnostic {
                span: attribute_span,
                severity: Severity::Error,
                code: "image-attribute",
                message: "invalid image attribute: no attribute given (expected `width:<n>%`)".to_string(),
            });
            continue;
        };
        match key {
            "width" | "w" => {
                if let Err(error) = parse_percent(value) {
                    analysis.diagnostics.push(Diagnostic {
                        span: attribute_span,
                        severity: Severity::Error,
                        code: "image-attribute",
                        message: format!("invalid image attribute: invalid width: {error}"),
                    });
                }
            }
            other => analysis.diagnostics.push(Diagnostic {
                span: attribute_span,
                severity: Severity::Error,
                code: "image-attribute",
                message: format!("invalid image attribute: unknown attribute: '{other}' (only `width`/`w` exist)"),
            }),
        }
    }
}

/// Mirrors `impl FromStr for Percent`.
fn parse_percent(input: &str) -> Result<u8, String> {
    let (prefix, suffix) = input.split_once('%').ok_or_else(|| "no unit provided".to_string())?;
    let value: u8 = prefix.parse().map_err(|_| "value must be a number between 1-100".to_string())?;
    if !(1..=100).contains(&value) {
        return Err("value must be a number between 1-100".to_string());
    }
    if !suffix.is_empty() {
        return Err(format!("unexpected: '{suffix}'"));
    }
    Ok(value)
}

/// Mirrors the `+attribute` grammar in `src/code/snippet.rs::parse_attribute`.
fn check_snippet(info: &str, span: &Span, ids: &mut HashMap<String, Span>, analysis: &mut Analysis) {
    const UNIT_ATTRIBUTES: &[&str] = &[
        "line_numbers",
        "exec",
        "auto_exec",
        "exec_replace",
        "validate",
        "image",
        "render",
        "no_background",
        "acquire_terminal",
        "pty",
    ];
    const VALUED_ATTRIBUTES: &[&str] =
        &["exec", "auto_exec", "exec_replace", "id", "validate", "acquire_terminal", "width", "expect"];

    let mut is_exec = false;
    let mut id: Option<(String, Span)> = None;

    for token in info.split_whitespace() {
        let Some(attribute) = token.strip_prefix('+') else { continue };
        let Some(offset) = info.find(token) else { continue };
        let token_span = span.start + offset..span.start + offset + token.len();

        if UNIT_ATTRIBUTES.contains(&attribute) {
            if matches!(attribute, "exec" | "auto_exec" | "exec_replace" | "acquire_terminal" | "pty") {
                is_exec = true;
            }
            continue;
        }
        let Some((key, value)) = attribute.split_once(':') else {
            analysis.diagnostics.push(Diagnostic {
                span: token_span,
                severity: Severity::Error,
                code: "snippet-attribute",
                message: format!("invalid snippet attribute: '{attribute}'"),
            });
            continue;
        };
        if !VALUED_ATTRIBUTES.contains(&key) {
            analysis.diagnostics.push(Diagnostic {
                span: token_span,
                severity: Severity::Error,
                code: "snippet-attribute",
                message: format!("invalid snippet attribute: '{key}'"),
            });
            continue;
        }
        match key {
            "id" => id = Some((value.to_string(), token_span)),
            "exec" | "auto_exec" | "exec_replace" | "acquire_terminal" => is_exec = true,
            "width" => {
                if parse_percent(value).is_err() {
                    analysis.diagnostics.push(Diagnostic {
                        span: token_span,
                        severity: Severity::Error,
                        code: "snippet-attribute",
                        message: format!("invalid width: '{value}'"),
                    });
                }
            }
            "expect" => {
                if !matches!(value, "success" | "failure" | "fail") {
                    analysis.diagnostics.push(Diagnostic {
                        span: token_span,
                        severity: Severity::Error,
                        code: "snippet-attribute",
                        message: format!("invalid expectation: '{value}' (expected success or failure)"),
                    });
                }
            }
            _ => {}
        }
    }

    if let Some((id, id_span)) = id {
        if !is_exec {
            analysis.diagnostics.push(Diagnostic {
                span: id_span.clone(),
                severity: Severity::Error,
                code: "snippet-id-non-exec",
                message: "snippet identifiers can only be used in +exec blocks".to_string(),
            });
        }
        match ids.entry(id.clone()) {
            Entry::Occupied(_) => analysis.diagnostics.push(Diagnostic {
                span: id_span,
                severity: Severity::Error,
                code: "snippet-id-duplicate",
                message: format!("snippet id '{id}' already exists"),
            }),
            Entry::Vacant(slot) => {
                slot.insert(id_span);
            }
        }
    }
}

/// `did you mean` for a mistyped command, keyed off the identifier before `:`.
fn suggest(input: &str) -> String {
    let word = input.trim().split(|c: char| c == ':' || c.is_whitespace()).next().unwrap_or("");
    if word.is_empty() {
        return String::new();
    }
    let names: Vec<&str> = crate::command::COMMANDS.iter().map(|doc| doc.label).collect();
    match closest(word, &names) {
        Some(best) => format!(" (did you mean `{best}`?)"),
        None => String::new(),
    }
}

/// Levenshtein distance, accepting a match within a third of the word length.
fn closest<'a>(input: &str, candidates: &[&'a str]) -> Option<&'a str> {
    let budget = (input.chars().count() / 3).max(1) + 1;
    candidates
        .iter()
        .map(|candidate| (distance(input, candidate), *candidate))
        .filter(|(distance, _)| *distance <= budget)
        .min_by_key(|(distance, _)| *distance)
        .map(|(_, candidate)| candidate)
}

fn distance(a: &str, b: &str) -> usize {
    let a: Vec<char> = a.chars().collect();
    let b: Vec<char> = b.chars().collect();
    let mut previous: Vec<usize> = (0..=b.len()).collect();
    let mut current = vec![0usize; b.len() + 1];
    for (i, &ca) in a.iter().enumerate() {
        current[0] = i + 1;
        for (j, &cb) in b.iter().enumerate() {
            let cost = usize::from(ca != cb);
            current[j + 1] = (previous[j] + cost).min(previous[j + 1] + 1).min(current[j] + 1);
        }
        std::mem::swap(&mut previous, &mut current);
    }
    previous[b.len()]
}

/// Cheap check used to decide whether a `.md` buffer is a deck at all.
/// Editors attach this server to all markdown; staying silent on prose is the
/// difference between useful and infuriating.
pub fn looks_like_deck(text: &str, path: Option<&Path>) -> bool {
    if let Some(name) = path.and_then(|path| path.file_name()).and_then(|name| name.to_str()) {
        if name == "slides.md" || name == "deck.md" || name.ends_with(".presenterm.md") {
            return true;
        }
    }
    analyze(text, None).is_deck
}

#[cfg(test)]
mod tests {
    use super::*;

    fn codes(text: &str) -> Vec<&'static str> {
        analyze(text, None).diagnostics.iter().map(|d| d.code).collect()
    }

    const DECK: &str = "<!-- end_slide -->\n";

    #[test]
    fn clean_deck_has_no_diagnostics() {
        let text = "---\ntheme:\n  name: dark\n---\n\n# hi\n\n<!-- end_slide -->\n\n# bye\n";
        assert!(analyze(text, None).diagnostics.is_empty());
    }

    #[test]
    fn prose_markdown_is_left_alone() {
        // No front matter, no commands: not a deck, so no diagnostics even
        // though `<!-- pasue -->` would be invalid in one.
        let text = "# A blog post\n\n<!-- pasue -->\n";
        let analysis = analyze(text, None);
        assert!(!analysis.is_deck);
        assert!(analysis.diagnostics.is_empty());
    }

    #[test]
    fn typo_in_command_is_reported_with_a_suggestion() {
        let analysis = analyze(&format!("{DECK}<!-- pasue -->\n"), None);
        let diagnostic = &analysis.diagnostics[0];
        assert_eq!(diagnostic.code, "invalid-command");
        assert!(diagnostic.message.contains("did you mean `pause`"), "{}", diagnostic.message);
    }

    #[test]
    fn upstream_ignore_rules_are_honoured() {
        for comment in ["<!-- vim: set ft=markdown -->", "<!-- {{{ -->", "<!-- // a note -->", "<!-- comment: hi -->"] {
            assert!(codes(&format!("{DECK}{comment}\n")).is_empty(), "{comment} should be accepted");
        }
    }

    #[test]
    fn column_rules_match_upstream_tests() {
        assert_eq!(codes(&format!("{DECK}<!-- column: 0 -->\n")), ["no-layout"]);
        assert_eq!(
            codes(&format!("{DECK}<!-- column_layout: [1] -->\n<!-- column: 0 -->\n<!-- column: 0 -->\n")),
            ["already-in-column"]
        );
        assert_eq!(
            codes(&format!("{DECK}<!-- column_layout: [1] -->\n<!-- column: 1 -->\n")),
            ["column-index-too-large"]
        );
        assert_eq!(codes(&format!("{DECK}<!-- column_layout: [] -->\n")), ["invalid-layout"]);
        assert_eq!(codes(&format!("{DECK}<!-- column_layout: [1, 0] -->\n")), ["invalid-layout"]);
    }

    #[test]
    fn content_outside_a_column_is_an_error() {
        let codes = codes(&format!("{DECK}<!-- column_layout: [1] -->\n\n# hi\n"));
        assert_eq!(codes, ["not-inside-column", "not-inside-column"]);
    }

    #[test]
    fn pause_between_layout_and_column_is_allowed() {
        // Upstream `pause_layout` test: a pause does not count as content.
        let text = format!("{DECK}<!-- column_layout: [1, 1] -->\n<!-- pause -->\n<!-- column: 0 -->\nhi\n");
        assert!(codes(&text).is_empty());
    }

    #[test]
    fn reset_layout_clears_the_requirement() {
        let text = format!("{DECK}<!-- column_layout: [1] -->\n<!-- reset_layout -->\n\nhi\n");
        assert!(codes(&text).is_empty());
    }

    #[test]
    fn font_size_bounds() {
        assert_eq!(codes(&format!("{DECK}<!-- font_size: 0 -->\n")), ["invalid-font-size"]);
        assert_eq!(codes(&format!("{DECK}<!-- font_size: 8 -->\n")), ["invalid-font-size"]);
        assert!(codes(&format!("{DECK}<!-- font_size: 7 -->\n")).is_empty());
    }

    #[test]
    fn list_item_newlines_zero_fails_to_parse() {
        // NonZeroU8 rejects it at the serde layer, exactly as upstream does.
        assert_eq!(codes(&format!("{DECK}<!-- list_item_newlines: 0 -->\n")), ["invalid-command"]);
    }

    #[test]
    fn unknown_theme_is_reported() {
        let text = "---\ntheme:\n  name: catpuccin-mocha\n---\n";
        let analysis = analyze(text, None);
        assert_eq!(analysis.diagnostics[0].code, "unknown-theme");
        assert!(analysis.diagnostics[0].message.contains("catppuccin-mocha"));
    }

    #[test]
    fn custom_theme_path_suppresses_the_name_check() {
        let text = "---\ntheme:\n  name: mine\n  path: ./theme.yaml\n---\n";
        assert!(analyze(text, None).diagnostics.is_empty());
    }

    #[test]
    fn command_prefix_is_honoured() {
        let text = "---\noptions:\n  command_prefix: \"cmd:\"\n---\n\n<!-- cmd:end_slide -->\n<!-- bogus -->\n<!-- cmd:bogus -->\n";
        // `bogus` lacks the prefix so presenterm ignores it; `cmd:bogus` does not.
        assert_eq!(codes(text), ["invalid-command"]);
    }

    #[test]
    fn image_attributes_are_validated() {
        assert!(codes(&format!("{DECK}![image:w:30%](x.png)\n")).is_empty());
        assert_eq!(codes(&format!("{DECK}![image:w:0%](x.png)\n")), ["image-attribute"]);
        assert_eq!(codes(&format!("{DECK}![image:w:30](x.png)\n")), ["image-attribute"]);
        assert_eq!(codes(&format!("{DECK}![image:height:30%](x.png)\n")), ["image-attribute"]);
    }

    #[test]
    fn snippet_ids_require_exec() {
        assert_eq!(codes(&format!("{DECK}```rust +id:demo\nfn main() {{}}\n```\n")), ["snippet-id-non-exec"]);
        assert!(codes(&format!("{DECK}```rust +exec +id:demo\nfn main() {{}}\n```\n")).is_empty());
    }

    #[test]
    fn snippet_output_needs_a_matching_id() {
        assert_eq!(codes(&format!("{DECK}<!-- snippet_output: nope -->\n")), ["undefined-snippet-id"]);
    }

    #[test]
    fn slides_are_segmented_and_titled() {
        let text = "---\ntheme:\n  name: dark\n---\n\n# First\n\n<!-- end_slide -->\n\n# Second\n";
        let analysis = analyze(text, None);
        assert_eq!(analysis.slides.len(), 2);
        assert_eq!(analysis.slides[0].title.as_deref(), Some("First"));
        assert_eq!(analysis.slides[1].title.as_deref(), Some("Second"));
    }

    #[test]
    fn thematic_breaks_only_split_with_the_shorthand() {
        let plain = "---\ntheme:\n  name: dark\n---\n\n# a\n\n---\n\n# b\n";
        assert_eq!(analyze(plain, None).slides.len(), 1);
        let shorthand = "---\noptions:\n  end_slide_shorthand: true\n---\n\n# a\n\n---\n\n# b\n";
        assert_eq!(analyze(shorthand, None).slides.len(), 2);
    }
}
