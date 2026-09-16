//! Line-oriented scanner for presenterm decks.
//!
//! presenterm parses with comrak and then walks the AST. Pulling comrak in here
//! would double the build for little gain: every construct this server reasons
//! about (front matter, HTML comments, fenced snippets, images, headings,
//! thematic breaks) is recognisable from a line scan, and a hand-written
//! scanner gives byte-exact spans for free - comrak's `sourcepos` is
//! line-granular for inline nodes, which would put squiggles under whole lines.
//!
//! The scanner's only job is to produce a positioned element stream; all
//! presenterm semantics live in `analysis`.

use std::ops::Range;

/// A byte range into the document text.
pub type Span = Range<usize>;

#[derive(Debug, Clone)]
pub enum Element {
    /// YAML front matter, delimited by `---` lines. Only meaningful as the
    /// first element of a deck.
    FrontMatter { body: String, body_span: Span, span: Span },
    /// An HTML comment. `body` is the text between the delimiters, trimmed the
    /// way presenterm trims it.
    Comment { body: String, body_span: Span, span: Span },
    /// An ATX (`# x`) or setext (`x\n===`) heading.
    Heading { level: u8, text: String, span: Span },
    /// `---`, `***` or `___` on its own line.
    ThematicBreak { span: Span },
    /// A fenced code block. `info` is the full info string, e.g. `rust +exec +id:foo`.
    Snippet { info: String, info_span: Span, span: Span },
    /// `![alt](path)`. `alt` carries presenterm's image attributes.
    Image { alt: String, alt_span: Span, path: String, path_span: Span, span: Span },
    /// Anything else that renders: paragraphs, lists, tables, block quotes.
    Content { span: Span },
}

impl Element {
    pub fn span(&self) -> Span {
        match self {
            Element::FrontMatter { span, .. }
            | Element::Comment { span, .. }
            | Element::Heading { span, .. }
            | Element::ThematicBreak { span }
            | Element::Snippet { span, .. }
            | Element::Image { span, .. }
            | Element::Content { span } => span.clone(),
        }
    }

    /// Whether presenterm would push a render operation for this element.
    ///
    /// Used for the "layout created but no column entered" check: upstream
    /// looks at the last pushed operation, and comment commands either push
    /// nothing or push through a path that leaves `chunk_operations` empty.
    pub fn is_renderable(&self) -> bool {
        matches!(
            self,
            Element::Heading { .. } | Element::Snippet { .. } | Element::Image { .. } | Element::Content { .. }
        )
    }
}

/// Maps byte offsets to LSP (line, utf-16 column) positions.
pub struct LineIndex {
    /// Byte offset at which each line starts.
    line_starts: Vec<usize>,
    text: String,
}

impl LineIndex {
    pub fn new(text: &str) -> Self {
        let mut line_starts = vec![0];
        for (offset, byte) in text.bytes().enumerate() {
            if byte == b'\n' {
                line_starts.push(offset + 1);
            }
        }
        Self { line_starts, text: text.to_string() }
    }

    pub fn position(&self, offset: usize) -> (u32, u32) {
        let offset = offset.min(self.text.len());
        let line = match self.line_starts.binary_search(&offset) {
            Ok(line) => line,
            Err(next) => next - 1,
        };
        let line_start = self.line_starts[line];
        // LSP positions are UTF-16 code units unless negotiated otherwise.
        let column = self.text[line_start..offset].encode_utf16().count();
        (line as u32, column as u32)
    }

    /// Byte offset of an LSP position, saturating at the end of the line and
    /// of the document.
    pub fn offset(&self, line: u32, column: u32) -> usize {
        let Some(&line_start) = self.line_starts.get(line as usize) else {
            return self.text.len();
        };
        let line_end = self.line_starts.get(line as usize + 1).map(|next| next - 1).unwrap_or(self.text.len());
        let slice = &self.text[line_start..line_end];
        let mut utf16 = 0usize;
        for (byte_offset, ch) in slice.char_indices() {
            if utf16 >= column as usize {
                return line_start + byte_offset;
            }
            utf16 += ch.len_utf16();
        }
        line_end
    }

    pub fn line_span(&self, line: u32) -> Span {
        let start = *self.line_starts.get(line as usize).unwrap_or(&self.text.len());
        let end = self.line_starts.get(line as usize + 1).map(|next| next - 1).unwrap_or(self.text.len());
        start..end
    }
}

/// Scan a deck into a positioned element stream.
pub fn scan(text: &str) -> Vec<Element> {
    Scanner { text, elements: Vec::new() }.run()
}

struct Scanner<'a> {
    text: &'a str,
    elements: Vec<Element>,
}

impl<'a> Scanner<'a> {
    fn run(mut self) -> Vec<Element> {
        let lines = line_spans(self.text);
        let mut index = 0usize;

        if let Some(end) = self.scan_front_matter(&lines) {
            index = end;
        }

        // The text of the previous line, when it could be the body of a setext
        // heading (non-blank, not a comment, not inside a fence).
        let mut setext_candidate: Option<(String, Span)> = None;

        while index < lines.len() {
            let span = lines[index].clone();
            let line = &self.text[span.clone()];
            let trimmed = line.trim();

            if let Some(fence) = FenceStart::parse(line) {
                setext_candidate = None;
                index = self.scan_fence(&lines, index, fence);
                continue;
            }

            if trimmed.is_empty() {
                setext_candidate = None;
                index += 1;
                continue;
            }

            // A line may hold comments plus other content; peel the comments
            // off first so the remainder is classified on its own.
            let (comment_count, consumed_through, residue) = self.scan_comments(&lines, index);
            if comment_count > 0 {
                if residue.trim().is_empty() {
                    setext_candidate = None;
                    index = consumed_through + 1;
                    continue;
                }
                // Mixed line: record the leftover as content and move on.
                self.elements.push(Element::Content { span: span.clone() });
                self.scan_images(&residue, span.start);
                setext_candidate = None;
                index = consumed_through + 1;
                continue;
            }

            if let Some(level) = setext_underline(trimmed) {
                if let Some((text, body_span)) = setext_candidate.take() {
                    // Retract the Content element pushed for the body line.
                    if matches!(self.elements.last(), Some(Element::Content { span }) if *span == body_span) {
                        self.elements.pop();
                    }
                    self.elements.push(Element::Heading { level, text, span: body_span.start..span.end });
                    index += 1;
                    continue;
                }
            }

            if is_thematic_break(trimmed) {
                self.elements.push(Element::ThematicBreak { span: span.clone() });
                setext_candidate = None;
                index += 1;
                continue;
            }

            if let Some((level, text)) = atx_heading(trimmed) {
                self.elements.push(Element::Heading { level, text, span: span.clone() });
                setext_candidate = None;
                index += 1;
                continue;
            }

            let images_before = self.elements.len();
            self.scan_images(line, span.start);
            if self.elements.len() == images_before {
                self.elements.push(Element::Content { span: span.clone() });
                setext_candidate = Some((trimmed.to_string(), span.clone()));
            } else {
                setext_candidate = None;
            }
            index += 1;
        }

        self.elements
    }

    /// comrak only treats `---` as a front matter delimiter at offset 0.
    fn scan_front_matter(&mut self, lines: &[Span]) -> Option<usize> {
        let first = lines.first()?;
        if self.text[first.clone()].trim_end() != "---" {
            return None;
        }
        for (index, span) in lines.iter().enumerate().skip(1) {
            if self.text[span.clone()].trim_end() == "---" {
                let body_span = first.end + 1..span.start;
                let body = self.text.get(body_span.clone()).unwrap_or_default().to_string();
                self.elements.push(Element::FrontMatter { body, body_span, span: first.start..span.end });
                return Some(index + 1);
            }
        }
        None
    }

    fn scan_fence(&mut self, lines: &[Span], start: usize, fence: FenceStart) -> usize {
        let open = lines[start].clone();
        let info = fence.info.clone();
        let info_start = open.start + fence.info_offset;
        let info_span = info_start..info_start + info.len();
        let mut index = start + 1;
        while index < lines.len() {
            let line = &self.text[lines[index].clone()];
            if fence.closes(line) {
                index += 1;
                break;
            }
            index += 1;
        }
        let end = lines.get(index.saturating_sub(1)).map(|s| s.end).unwrap_or(open.end);
        self.elements.push(Element::Snippet { info, info_span, span: open.start..end });
        index
    }

    /// Peel every HTML comment starting on `start`. Returns how many were found,
    /// the last line index they spanned, and the non-comment residue of the
    /// lines consumed.
    fn scan_comments(&mut self, lines: &[Span], start: usize) -> (usize, usize, String) {
        let mut count = 0;
        let mut line = start;
        let mut residue = String::new();
        let mut cursor = lines[start].start;

        loop {
            let line_span = lines[line].clone();
            let rest = &self.text[cursor..line_span.end];
            let Some(open_rel) = rest.find("<!--") else {
                residue.push_str(rest);
                break;
            };
            residue.push_str(&rest[..open_rel]);
            let open = cursor + open_rel;
            let Some(close_rel) = self.text[open + 4..].find("-->") else {
                // Unterminated comment: presenterm's parser would fail, but
                // treating the remainder as a comment keeps diagnostics local.
                let body_span = open + 4..self.text.len();
                let body = self.text[body_span.clone()].trim().to_string();
                self.elements.push(Element::Comment { body, body_span, span: open..self.text.len() });
                return (count + 1, lines.len().saturating_sub(1), residue);
            };
            let body_span = open + 4..open + 4 + close_rel;
            let close = body_span.end + 3;
            let body = self.text[body_span.clone()].trim().to_string();
            self.elements.push(Element::Comment { body, body_span, span: open..close });
            count += 1;
            cursor = close;
            // The comment may have spanned lines; resync.
            while line < lines.len() && lines[line].end < cursor {
                line += 1;
            }
            if line >= lines.len() {
                break;
            }
        }

        (count, line.min(lines.len().saturating_sub(1)), residue)
    }

    /// Record every `![alt](path)` on a line.
    fn scan_images(&mut self, line: &str, base: usize) {
        let bytes = line.as_bytes();
        let mut index = 0usize;
        while index + 1 < bytes.len() {
            if bytes[index] != b'!' || bytes[index + 1] != b'[' {
                index += 1;
                continue;
            }
            let Some(alt_end) = find_unescaped(line, index + 2, b']') else {
                index += 1;
                continue;
            };
            if line.as_bytes().get(alt_end + 1) != Some(&b'(') {
                index = alt_end + 1;
                continue;
            }
            let Some(path_end) = find_unescaped(line, alt_end + 2, b')') else {
                index = alt_end + 1;
                continue;
            };
            let alt_span = base + index + 2..base + alt_end;
            let path_span = base + alt_end + 2..base + path_end;
            self.elements.push(Element::Image {
                alt: line[index + 2..alt_end].to_string(),
                alt_span,
                path: line[alt_end + 2..path_end].to_string(),
                path_span,
                span: base + index..base + path_end + 1,
            });
            index = path_end + 1;
        }
    }
}

struct FenceStart {
    marker: u8,
    length: usize,
    info: String,
    info_offset: usize,
}

impl FenceStart {
    fn parse(line: &str) -> Option<Self> {
        let indent = line.len() - line.trim_start().len();
        if indent > 3 {
            return None;
        }
        let rest = &line[indent..];
        let marker = match rest.as_bytes().first()? {
            b'`' => b'`',
            b'~' => b'~',
            _ => return None,
        };
        let length = rest.bytes().take_while(|b| *b == marker).count();
        if length < 3 {
            return None;
        }
        let info_raw = &rest[length..];
        let lead = info_raw.len() - info_raw.trim_start().len();
        let info = info_raw.trim().to_string();
        // A ``` line whose info string contains a backtick is not a fence.
        if marker == b'`' && info.contains('`') {
            return None;
        }
        Some(Self { marker, length, info, info_offset: indent + length + lead })
    }

    fn closes(&self, line: &str) -> bool {
        let trimmed = line.trim();
        trimmed.len() >= self.length && trimmed.bytes().all(|b| b == self.marker)
    }
}

fn line_spans(text: &str) -> Vec<Span> {
    let mut spans = Vec::new();
    let mut start = 0usize;
    for (offset, byte) in text.bytes().enumerate() {
        if byte == b'\n' {
            let mut end = offset;
            if end > start && text.as_bytes()[end - 1] == b'\r' {
                end -= 1;
            }
            spans.push(start..end);
            start = offset + 1;
        }
    }
    if start <= text.len() {
        spans.push(start..text.len());
    }
    spans
}

fn is_thematic_break(trimmed: &str) -> bool {
    let stripped: String = trimmed.chars().filter(|c| !c.is_whitespace()).collect();
    if stripped.len() < 3 {
        return false;
    }
    ['-', '*', '_'].iter().any(|marker| stripped.chars().all(|c| c == *marker))
}

fn setext_underline(trimmed: &str) -> Option<u8> {
    if !trimmed.is_empty() && trimmed.chars().all(|c| c == '=') {
        Some(1)
    } else if trimmed.len() >= 2 && trimmed.chars().all(|c| c == '-') {
        // A single `-` is a list bullet; `--` and longer underline an h2. Note
        // `---` is ambiguous with a thematic break - CommonMark resolves it in
        // favour of the setext heading when a paragraph precedes it, which is
        // what the caller does by only consulting this with a live candidate.
        Some(2)
    } else {
        None
    }
}

fn atx_heading(trimmed: &str) -> Option<(u8, String)> {
    let level = trimmed.bytes().take_while(|b| *b == b'#').count();
    if level == 0 || level > 6 {
        return None;
    }
    let rest = &trimmed[level..];
    if !rest.is_empty() && !rest.starts_with(' ') {
        return None;
    }
    Some((level as u8, rest.trim().trim_end_matches('#').trim().to_string()))
}

fn find_unescaped(text: &str, from: usize, needle: u8) -> Option<usize> {
    let bytes = text.as_bytes();
    let mut index = from;
    while index < bytes.len() {
        if bytes[index] == b'\\' {
            index += 2;
            continue;
        }
        if bytes[index] == needle {
            return Some(index);
        }
        index += 1;
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn kinds(text: &str) -> Vec<&'static str> {
        scan(text)
            .iter()
            .map(|element| match element {
                Element::FrontMatter { .. } => "front_matter",
                Element::Comment { .. } => "comment",
                Element::Heading { .. } => "heading",
                Element::ThematicBreak { .. } => "break",
                Element::Snippet { .. } => "snippet",
                Element::Image { .. } => "image",
                Element::Content { .. } => "content",
            })
            .collect()
    }

    #[test]
    fn front_matter_only_at_offset_zero() {
        assert_eq!(kinds("---\ntheme:\n  name: dark\n---\n\n# hi\n"), ["front_matter", "heading"]);
        // A thematic break mid-document is not front matter.
        assert_eq!(kinds("# hi\n\n---\n\n# bye\n"), ["heading", "break", "heading"]);
    }

    #[test]
    fn comments_are_extracted_with_spans() {
        let elements = scan("<!-- pause -->\n");
        match &elements[0] {
            Element::Comment { body, body_span, .. } => {
                assert_eq!(body, "pause");
                assert_eq!(&"<!-- pause -->\n"[body_span.clone()], " pause ");
            }
            other => panic!("expected comment, got {other:?}"),
        }
    }

    #[test]
    fn multiline_comments_stay_one_element() {
        let elements = scan("<!--\nhello\nworld\n-->\n");
        assert_eq!(elements.len(), 1);
        match &elements[0] {
            Element::Comment { body, .. } => assert_eq!(body, "hello\nworld"),
            other => panic!("expected comment, got {other:?}"),
        }
    }

    #[test]
    fn fenced_snippets_hide_their_contents() {
        // The `<!-- pause -->` and `# heading` inside the fence must not be
        // mistaken for a command or a slide title.
        let kinds = kinds("```rust\n<!-- pause -->\n# not a heading\n```\n");
        assert_eq!(kinds, ["snippet"]);
    }

    #[test]
    fn snippet_info_string_is_captured() {
        let elements = scan("```rust +exec +id:demo\nfn main() {}\n```\n");
        match &elements[0] {
            Element::Snippet { info, info_span, .. } => {
                assert_eq!(info, "rust +exec +id:demo");
                assert_eq!(info_span.len(), info.len());
            }
            other => panic!("expected snippet, got {other:?}"),
        }
    }

    #[test]
    fn images_carry_alt_and_path_spans() {
        let text = "![image:w:30%](./img/qr.png)\n";
        let elements = scan(text);
        match &elements[0] {
            Element::Image { alt, path, alt_span, path_span, .. } => {
                assert_eq!(alt, "image:w:30%");
                assert_eq!(path, "./img/qr.png");
                assert_eq!(&text[alt_span.clone()], "image:w:30%");
                assert_eq!(&text[path_span.clone()], "./img/qr.png");
            }
            other => panic!("expected image, got {other:?}"),
        }
    }

    #[test]
    fn setext_heading_beats_thematic_break() {
        assert_eq!(kinds("first\n===\n"), ["heading"]);
        assert_eq!(kinds("first\n---\n"), ["heading"]);
        assert_eq!(kinds("\n---\n"), ["break"]);
    }

    #[test]
    fn line_index_handles_multibyte() {
        let text = "Montréal\nnext\n";
        let index = LineIndex::new(text);
        let offset = text.find("next").unwrap();
        assert_eq!(index.position(offset), (1, 0));
        // é is 2 bytes but 1 utf-16 unit.
        assert_eq!(index.position(text.find('a').unwrap()), (0, 6));
        assert_eq!(index.offset(1, 0), offset);
    }
}
