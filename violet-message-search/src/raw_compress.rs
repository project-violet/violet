use std::error::Error;
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

use serde::Deserialize;

use crate::message::{convert_query, Message};

#[derive(Deserialize)]
pub struct RawArticle {
    #[serde(rename(deserialize = "articleId"))]
    pub article_id: String,

    pub pages: Vec<RawPage>,
}

#[derive(Deserialize)]
pub struct RawPage {
    pub page: u32,
    pub dialogues: Vec<RawDialogue>,
}

#[derive(Deserialize)]
pub struct RawDialogue {
    pub text: String,
    pub confidence: f32,
    pub bbox: [f32; 4],
}

pub fn convert_article(article: RawArticle) -> Result<Vec<Message>, Box<dyn Error + Send + Sync>> {
    let article_id = article.article_id.parse::<u32>()?;
    let min_page = article
        .pages
        .iter()
        .map(|page| page.page)
        .min()
        .unwrap_or(0);
    let mut messages = Vec::new();

    for page in article.pages {
        for dialogue in page.dialogues {
            let message = convert_query(&dialogue.text);
            if message.is_empty() {
                continue;
            }

            messages.push(Message {
                article_id,
                page: page.page - min_page,
                message,
                #[cfg(feature = "raw")]
                raw: raw_message(dialogue.text),
                correct: dialogue.confidence,
                rects: dialogue.bbox,
            });
        }
    }

    Ok(messages)
}

#[cfg(feature = "raw")]
fn raw_message(text: String) -> Option<String> {
    Some(text)
}

pub struct CompressOptions {
    pub raw_dir: PathBuf,
    pub output_dir: PathBuf,
    pub splits: usize,
}

pub fn compress_raw_dir(options: CompressOptions) -> Result<(), Box<dyn Error + Send + Sync>> {
    if options.splits == 0 {
        return Err("splits must be greater than zero".into());
    }

    fs::create_dir_all(&options.output_dir)?;

    let mut raw_paths = collect_raw_json_paths(&options.raw_dir)?;
    raw_paths.sort();

    let mut writers = Vec::with_capacity(options.splits);
    for split in 0..options.splits {
        let path = options.output_dir.join(format!("merged-{split}.json"));
        let mut writer = BufWriter::new(File::create(path)?);
        writer.write_all(b"[")?;
        writers.push(SplitWriter {
            writer,
            has_items: false,
        });
    }

    for (index, raw_path) in raw_paths.into_iter().enumerate() {
        let file = File::open(&raw_path)?;
        let article: RawArticle = simd_json::serde::from_reader(file)
            .map_err(|err| format!("failed to parse {}: {err}", raw_path.display()))?;
        let messages = convert_article(article)
            .map_err(|err| format!("failed to convert {}: {err}", raw_path.display()))?;

        let split = index % options.splits;
        for message in messages {
            writers[split].write_message(&message)?;
        }
    }

    for split_writer in &mut writers {
        split_writer.writer.write_all(b"]")?;
        split_writer.writer.flush()?;
    }

    Ok(())
}

fn collect_raw_json_paths(raw_dir: &Path) -> Result<Vec<PathBuf>, Box<dyn Error + Send + Sync>> {
    let mut paths = Vec::new();
    for entry in fs::read_dir(raw_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_file() && path.extension().is_some_and(|ext| ext == "json") {
            paths.push(path);
        }
    }
    Ok(paths)
}

struct SplitWriter {
    writer: BufWriter<File>,
    has_items: bool,
}

impl SplitWriter {
    fn write_message(&mut self, message: &Message) -> Result<(), Box<dyn Error + Send + Sync>> {
        if self.has_items {
            self.writer.write_all(b",")?;
        }
        simd_json::to_writer(&mut self.writer, message)?;
        self.has_items = true;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_with_shared_hangul_converter_and_removes_whitespace() {
        assert_eq!(convert_query("안녕 하세요!"), "dkssudgktpdy!");
    }

    #[test]
    fn converts_raw_dialogue_to_fast_search_message() {
        let raw = RawArticle {
            article_id: "1113152".to_string(),
            pages: vec![RawPage {
                page: 3,
                dialogues: vec![RawDialogue {
                    text: "와 FO 열".to_string(),
                    confidence: 0.8329,
                    bbox: [1741.0, 551.0, 1924.0, 947.0],
                }],
            }],
        };

        let messages = convert_article(raw).unwrap();

        assert_eq!(messages.len(), 1);
        assert_eq!(messages[0].article_id, 1113152);
        assert_eq!(messages[0].page, 0);
        assert_eq!(messages[0].message, "dhkFOduf");
        #[cfg(feature = "raw")]
        assert_eq!(messages[0].raw.as_deref(), Some("와 FO 열"));
        assert_eq!(messages[0].correct, 0.8329_f32);
        assert_eq!(messages[0].rects, [1741.0, 551.0, 1924.0, 947.0]);
    }

    #[test]
    fn normalizes_page_numbers_from_minimum_page_in_article() {
        let raw = RawArticle {
            article_id: "1113152".to_string(),
            pages: vec![
                RawPage {
                    page: 2,
                    dialogues: vec![RawDialogue {
                        text: "첫 장".to_string(),
                        confidence: 0.9,
                        bbox: [1.0, 2.0, 3.0, 4.0],
                    }],
                },
                RawPage {
                    page: 3,
                    dialogues: vec![RawDialogue {
                        text: "둘째 장".to_string(),
                        confidence: 0.8,
                        bbox: [5.0, 6.0, 7.0, 8.0],
                    }],
                },
            ],
        };

        let messages = convert_article(raw).unwrap();

        assert_eq!(messages[0].page, 0);
        assert_eq!(messages[1].page, 1);
    }
}
