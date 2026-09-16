//! The LSP surface: diagnostics, completion, hover, outline and go-to-file.

use crate::analysis::{analyze, looks_like_deck, Analysis, Severity};
use crate::command::{BUILTIN_THEMES, COMMANDS, FRONT_MATTER_KEYS, MIRRORED_PRESENTERM_VERSION, OPTIONS_KEYS};
use crate::document::LineIndex;
use lsp_server::{Connection, ExtractError, Message, Request, RequestId, Response};
use lsp_types::{
    notification::{
        DidChangeTextDocument, DidCloseTextDocument, DidOpenTextDocument, DidSaveTextDocument, Notification,
        PublishDiagnostics,
    },
    request::{Completion, DocumentSymbolRequest, GotoDefinition, HoverRequest, Request as RequestTrait},
    CompletionItem, CompletionItemKind, CompletionOptions, CompletionParams, CompletionResponse, Diagnostic,
    DiagnosticSeverity, DocumentSymbol, DocumentSymbolParams, DocumentSymbolResponse, GotoDefinitionParams,
    GotoDefinitionResponse, Hover, HoverContents, HoverParams, HoverProviderCapability, InitializeParams, Location,
    MarkupContent, MarkupKind, OneOf, Position, PublishDiagnosticsParams, Range, ServerCapabilities, SymbolKind,
    TextDocumentSyncCapability, TextDocumentSyncKind, Url,
};
use std::{collections::HashMap, error::Error, path::PathBuf};

type Fallible<T> = Result<T, Box<dyn Error + Sync + Send>>;

/// Settings read from `initializationOptions`.
#[derive(Debug, Default, Clone, Copy)]
struct Settings {
    /// Analyse every markdown buffer, not just ones that look like decks.
    always_activate: bool,
}

#[derive(Default)]
struct Documents {
    texts: HashMap<Url, String>,
}

impl Documents {
    fn set(&mut self, uri: Url, text: String) {
        self.texts.insert(uri, text);
    }

    fn remove(&mut self, uri: &Url) {
        self.texts.remove(uri);
    }

    fn get(&self, uri: &Url) -> Option<&String> {
        self.texts.get(uri)
    }
}

pub fn run() -> Fallible<()> {
    let (connection, io_threads) = Connection::stdio();

    let capabilities = serde_json::to_value(ServerCapabilities {
        text_document_sync: Some(TextDocumentSyncCapability::Kind(TextDocumentSyncKind::FULL)),
        completion_provider: Some(CompletionOptions {
            // `<` and `!` start a comment; `:` and ` ` land on a value slot.
            trigger_characters: Some(vec!["<".into(), "!".into(), "-".into(), ":".into(), " ".into()]),
            ..Default::default()
        }),
        hover_provider: Some(HoverProviderCapability::Simple(true)),
        document_symbol_provider: Some(OneOf::Left(true)),
        definition_provider: Some(OneOf::Left(true)),
        ..Default::default()
    })?;

    let initialize = connection.initialize(capabilities)?;
    let settings = read_settings(&initialize);
    main_loop(connection, settings)?;
    io_threads.join()?;
    Ok(())
}

fn read_settings(initialize: &serde_json::Value) -> Settings {
    let params: InitializeParams = match serde_json::from_value(initialize.clone()) {
        Ok(params) => params,
        Err(_) => return Settings::default(),
    };
    let always_activate = params
        .initialization_options
        .as_ref()
        .and_then(|options| options.get("alwaysActivate"))
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false);
    Settings { always_activate }
}

fn main_loop(connection: Connection, settings: Settings) -> Fallible<()> {
    let mut documents = Documents::default();

    for message in &connection.receiver {
        match message {
            Message::Request(request) => {
                if connection.handle_shutdown(&request)? {
                    return Ok(());
                }
                let response = dispatch(request, &documents);
                connection.sender.send(Message::Response(response))?;
            }
            Message::Response(_) => {}
            Message::Notification(notification) => {
                let uri = match notification.method.as_str() {
                    DidOpenTextDocument::METHOD => {
                        let params = cast_notification::<DidOpenTextDocument>(notification)?;
                        let uri = params.text_document.uri.clone();
                        documents.set(uri.clone(), params.text_document.text);
                        Some(uri)
                    }
                    DidChangeTextDocument::METHOD => {
                        let params = cast_notification::<DidChangeTextDocument>(notification)?;
                        let uri = params.text_document.uri.clone();
                        // FULL sync: the last change carries the whole document.
                        if let Some(change) = params.content_changes.into_iter().next_back() {
                            documents.set(uri.clone(), change.text);
                        }
                        Some(uri)
                    }
                    DidSaveTextDocument::METHOD => {
                        // Re-run on save so that fixing a missing image or an
                        // included file refreshes the parent deck.
                        let params = cast_notification::<DidSaveTextDocument>(notification)?;
                        Some(params.text_document.uri)
                    }
                    DidCloseTextDocument::METHOD => {
                        let params = cast_notification::<DidCloseTextDocument>(notification)?;
                        let uri = params.text_document.uri;
                        documents.remove(&uri);
                        // Clear any squiggles we left behind.
                        connection.sender.send(Message::Notification(lsp_server::Notification::new(
                            PublishDiagnostics::METHOD.to_string(),
                            PublishDiagnosticsParams { uri, diagnostics: Vec::new(), version: None },
                        )))?;
                        None
                    }
                    _ => None,
                };

                if let Some(uri) = uri {
                    if let Some(text) = documents.get(&uri) {
                        let params = diagnostics_for(&uri, text, settings);
                        connection.sender.send(Message::Notification(lsp_server::Notification::new(
                            PublishDiagnostics::METHOD.to_string(),
                            params,
                        )))?;
                    }
                }
            }
        }
    }
    Ok(())
}

fn dispatch(request: Request, documents: &Documents) -> Response {
    let id = request.id.clone();
    let result = match request.method.as_str() {
        Completion::METHOD => cast::<Completion>(request).map(|(id, params)| (id, completion(params, documents))),
        HoverRequest::METHOD => cast::<HoverRequest>(request).map(|(id, params)| (id, hover(params, documents))),
        DocumentSymbolRequest::METHOD => {
            cast::<DocumentSymbolRequest>(request).map(|(id, params)| (id, symbols(params, documents)))
        }
        GotoDefinition::METHOD => {
            cast::<GotoDefinition>(request).map(|(id, params)| (id, definition(params, documents)))
        }
        _ => return Response::new_ok(id, serde_json::Value::Null),
    };
    match result {
        Ok((id, value)) => Response::new_ok(id, value),
        Err(error) => Response::new_err(id, lsp_server::ErrorCode::InvalidParams as i32, error.to_string()),
    }
}

fn cast<R>(request: Request) -> Result<(RequestId, R::Params), ExtractError<Request>>
where
    R: RequestTrait,
    R::Params: serde::de::DeserializeOwned,
{
    request.extract(R::METHOD)
}

fn cast_notification<N>(notification: lsp_server::Notification) -> Fallible<N::Params>
where
    N: Notification,
    N::Params: serde::de::DeserializeOwned,
{
    Ok(notification.extract(N::METHOD)?)
}

// ---------------------------------------------------------------- diagnostics

fn document_path(uri: &Url) -> Option<PathBuf> {
    uri.to_file_path().ok()
}

fn diagnostics_for(uri: &Url, text: &str, settings: Settings) -> PublishDiagnosticsParams {
    let path = document_path(uri);
    let active = settings.always_activate || looks_like_deck(text, path.as_deref());
    let diagnostics = if active {
        let analysis = analyze(text, path.as_deref());
        let index = LineIndex::new(text);
        analysis
            .diagnostics
            .iter()
            .map(|diagnostic| Diagnostic {
                range: to_range(&index, &diagnostic.span),
                severity: Some(match diagnostic.severity {
                    Severity::Error => DiagnosticSeverity::ERROR,
                    Severity::Warning => DiagnosticSeverity::WARNING,
                    Severity::Hint => DiagnosticSeverity::HINT,
                }),
                code: Some(lsp_types::NumberOrString::String(diagnostic.code.to_string())),
                source: Some("presenterm".to_string()),
                message: diagnostic.message.clone(),
                ..Default::default()
            })
            .collect()
    } else {
        Vec::new()
    };
    PublishDiagnosticsParams { uri: uri.clone(), diagnostics, version: None }
}

fn to_range(index: &LineIndex, span: &crate::document::Span) -> Range {
    let (start_line, start_column) = index.position(span.start);
    let (end_line, end_column) = index.position(span.end);
    Range {
        start: Position { line: start_line, character: start_column },
        end: Position { line: end_line, character: end_column },
    }
}

// ----------------------------------------------------------------- completion

fn completion(params: CompletionParams, documents: &Documents) -> serde_json::Value {
    let uri = params.text_document_position.text_document.uri;
    let position = params.text_document_position.position;
    let Some(text) = documents.get(&uri) else { return serde_json::Value::Null };
    let index = LineIndex::new(text);
    let line_span = index.line_span(position.line);
    let offset = index.offset(position.line, position.character);
    let before = &text[line_span.start..offset.max(line_span.start)];

    let items = if in_front_matter(text, offset) { front_matter_items(text, before) } else { comment_items(before) };

    serde_json::to_value(CompletionResponse::Array(items)).unwrap_or(serde_json::Value::Null)
}

/// Is `offset` inside the leading `---` fenced front matter?
fn in_front_matter(text: &str, offset: usize) -> bool {
    if !text.starts_with("---") {
        return false;
    }
    let Some(close) = text[3..].find("\n---") else { return offset > 3 };
    offset > 3 && offset <= close + 3
}

fn front_matter_items(text: &str, before: &str) -> Vec<CompletionItem> {
    let trimmed = before.trim_start();
    // `name:` under a `theme:` block gets theme names.
    if trimmed.starts_with("name:") && text.contains("theme:") {
        return BUILTIN_THEMES
            .iter()
            .map(|theme| CompletionItem {
                label: theme.to_string(),
                kind: Some(CompletionItemKind::ENUM_MEMBER),
                detail: Some("built-in presenterm theme".to_string()),
                ..Default::default()
            })
            .collect();
    }
    // Indented keys belong to `options:`; top-level keys to the metadata.
    let indented = before.starts_with(' ') || before.starts_with('\t');
    let source: &[(&str, &str)] = if indented { OPTIONS_KEYS } else { FRONT_MATTER_KEYS };
    source
        .iter()
        .map(|(key, detail)| CompletionItem {
            label: (*key).to_string(),
            kind: Some(CompletionItemKind::FIELD),
            detail: Some((*detail).to_string()),
            insert_text: Some(format!("{key}: ")),
            ..Default::default()
        })
        .collect()
}

fn comment_items(before: &str) -> Vec<CompletionItem> {
    // Inside an open `<!--`? Then only the body is wanted.
    let open = before.rfind("<!--");
    let inside = match open {
        Some(open) => !before[open..].contains("-->"),
        None => false,
    };

    if inside {
        let typed = before[open.unwrap_or(0) + 4..].trim_start();
        if let Some(rest) = typed.strip_prefix("alignment:") {
            let _ = rest;
            return ["left", "center", "right"]
                .iter()
                .map(|value| CompletionItem {
                    label: (*value).to_string(),
                    kind: Some(CompletionItemKind::ENUM_MEMBER),
                    ..Default::default()
                })
                .collect();
        }
        return COMMANDS
            .iter()
            .map(|doc| CompletionItem {
                label: doc.label.to_string(),
                kind: Some(CompletionItemKind::KEYWORD),
                detail: Some(doc.detail.to_string()),
                documentation: Some(lsp_types::Documentation::MarkupContent(MarkupContent {
                    kind: MarkupKind::Markdown,
                    value: doc.documentation.to_string(),
                })),
                insert_text: Some(doc.insert.to_string()),
                ..Default::default()
            })
            .collect();
    }

    // Otherwise offer the whole comment, so `end<tab>` yields `<!-- end_slide -->`.
    COMMANDS
        .iter()
        .map(|doc| CompletionItem {
            label: doc.label.to_string(),
            kind: Some(CompletionItemKind::SNIPPET),
            detail: Some(doc.detail.to_string()),
            documentation: Some(lsp_types::Documentation::MarkupContent(MarkupContent {
                kind: MarkupKind::Markdown,
                value: doc.documentation.to_string(),
            })),
            insert_text: Some(format!("<!-- {} -->", doc.insert)),
            ..Default::default()
        })
        .collect()
}

// ---------------------------------------------------------------------- hover

fn hover(params: HoverParams, documents: &Documents) -> serde_json::Value {
    let uri = params.text_document_position_params.text_document.uri;
    let position = params.text_document_position_params.position;
    let Some(text) = documents.get(&uri) else { return serde_json::Value::Null };
    let index = LineIndex::new(text);
    let line_span = index.line_span(position.line);
    let line = &text[line_span.clone()];

    let Some(word) = word_at(line, index.offset(position.line, position.character) - line_span.start) else {
        return serde_json::Value::Null;
    };

    if let Some(doc) = COMMANDS.iter().find(|doc| doc.label == word) {
        let value = format!(
            "**`{}`** — {}\n\n{}\n\n*presenterm {MIRRORED_PRESENTERM_VERSION}*",
            doc.label, doc.detail, doc.documentation
        );
        return serde_json::to_value(Hover {
            contents: HoverContents::Markup(MarkupContent { kind: MarkupKind::Markdown, value }),
            range: None,
        })
        .unwrap_or(serde_json::Value::Null);
    }

    if BUILTIN_THEMES.contains(&word.as_str()) {
        let value = format!("**`{word}`** — built-in presenterm theme\n\nPreview with `presenterm --theme {word}`.");
        return serde_json::to_value(Hover {
            contents: HoverContents::Markup(MarkupContent { kind: MarkupKind::Markdown, value }),
            range: None,
        })
        .unwrap_or(serde_json::Value::Null);
    }

    let keys = FRONT_MATTER_KEYS.iter().chain(OPTIONS_KEYS.iter());
    if let Some((key, detail)) = keys.into_iter().find(|(key, _)| *key == word) {
        return serde_json::to_value(Hover {
            contents: HoverContents::Markup(MarkupContent {
                kind: MarkupKind::Markdown,
                value: format!("**`{key}`** — {detail}"),
            }),
            range: None,
        })
        .unwrap_or(serde_json::Value::Null);
    }

    serde_json::Value::Null
}

fn word_at(line: &str, offset: usize) -> Option<String> {
    let is_word = |c: char| c.is_alphanumeric() || c == '_' || c == '-';
    let offset = offset.min(line.len());
    let start = line[..offset].rfind(|c: char| !is_word(c)).map(|index| index + 1).unwrap_or(0);
    let end = line[offset..].find(|c: char| !is_word(c)).map(|index| index + offset).unwrap_or(line.len());
    let word = line.get(start..end)?.trim();
    (!word.is_empty()).then(|| word.to_string())
}

// -------------------------------------------------------------------- symbols

fn symbols(params: DocumentSymbolParams, documents: &Documents) -> serde_json::Value {
    let uri = params.text_document.uri;
    let Some(text) = documents.get(&uri) else { return serde_json::Value::Null };
    let analysis = analyze(text, document_path(&uri).as_deref());
    let index = LineIndex::new(text);

    #[allow(deprecated)] // `DocumentSymbol::deprecated` is required by the struct.
    let symbols: Vec<DocumentSymbol> = analysis
        .slides
        .iter()
        .map(|slide| {
            let range = to_range(&index, &slide.span);
            DocumentSymbol {
                name: match &slide.title {
                    Some(title) => format!("{}. {title}", slide.index + 1),
                    None => format!("{}. (untitled)", slide.index + 1),
                },
                detail: None,
                kind: SymbolKind::NAMESPACE,
                tags: None,
                deprecated: None,
                range,
                selection_range: Range { start: range.start, end: range.start },
                children: None,
            }
        })
        .collect();

    serde_json::to_value(DocumentSymbolResponse::Nested(symbols)).unwrap_or(serde_json::Value::Null)
}

// ----------------------------------------------------------------- definition

fn definition(params: GotoDefinitionParams, documents: &Documents) -> serde_json::Value {
    let uri = params.text_document_position_params.text_document.uri;
    let position = params.text_document_position_params.position;
    let Some(text) = documents.get(&uri) else { return serde_json::Value::Null };
    let path = document_path(&uri);
    let analysis: Analysis = analyze(text, path.as_deref());
    let index = LineIndex::new(text);
    let offset = index.offset(position.line, position.character);

    let Some(link) = analysis.links.iter().find(|link| link.span.contains(&offset)) else {
        return serde_json::Value::Null;
    };
    let Ok(target) = Url::from_file_path(&link.target) else { return serde_json::Value::Null };
    let zero = Position { line: 0, character: 0 };
    serde_json::to_value(GotoDefinitionResponse::Scalar(Location {
        uri: target,
        range: Range { start: zero, end: zero },
    }))
    .unwrap_or(serde_json::Value::Null)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn word_at_finds_the_command() {
        assert_eq!(word_at("<!-- end_slide -->", 8).as_deref(), Some("end_slide"));
        assert_eq!(word_at("<!-- column: 0 -->", 7).as_deref(), Some("column"));
    }

    #[test]
    fn front_matter_detection() {
        let text = "---\ntheme:\n  name: dark\n---\n\n# hi\n";
        assert!(in_front_matter(text, text.find("name").unwrap()));
        assert!(!in_front_matter(text, text.find("# hi").unwrap()));
    }

    #[test]
    fn completion_inside_a_comment_offers_bare_commands() {
        let items = comment_items("<!-- ");
        assert!(items.iter().any(|item| item.insert_text.as_deref() == Some("end_slide")));
    }

    #[test]
    fn completion_outside_a_comment_offers_the_whole_comment() {
        let items = comment_items("");
        assert!(items.iter().any(|item| item.insert_text.as_deref() == Some("<!-- end_slide -->")));
    }
}
