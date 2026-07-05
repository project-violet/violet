use std::error::Error;
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

use rayon::prelude::*;
use serde::Deserialize;

use crate::message::{convert_query, FlatMessageWriter, Message};

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

    compress_raw_dir_fscm(&options, raw_paths)
}

fn compress_raw_dir_fscm(
    options: &CompressOptions,
    raw_paths: Vec<PathBuf>,
) -> Result<(), Box<dyn Error + Send + Sync>> {
    let pieces: Vec<_> = raw_paths
        .par_iter()
        .enumerate()
        .map(|(index, raw_path)| {
            let article = read_raw_article(raw_path)?;
            let mut writer = FlatMessageWriter::default();
            convert_article_into_flat_writer(article, &mut writer)
                .map_err(|err| format!("failed to convert {}: {err}", raw_path.display()))?;
            Ok::<_, Box<dyn Error + Send + Sync>>((index % options.splits, writer))
        })
        .collect();

    let mut writers: Vec<_> = (0..options.splits)
        .map(|_| FlatMessageWriter::default())
        .collect();
    for piece in pieces {
        let (split, writer) = piece?;
        writers[split].append(writer);
    }

    for (split, writer) in writers.into_iter().enumerate() {
        let path = options.output_dir.join(format!("merged-{split}.fscm"));
        let mut file = BufWriter::new(File::create(path)?);
        writer.write_to(&mut file)?;
        file.flush()?;
    }

    Ok(())
}

fn read_raw_article(raw_path: &Path) -> Result<RawArticle, Box<dyn Error + Send + Sync>> {
    let file = File::open(raw_path)?;
    simd_json::serde::from_reader(file)
        .map_err(|err| format!("failed to parse {}: {err}", raw_path.display()).into())
}

fn convert_article_into_flat_writer(
    article: RawArticle,
    writer: &mut FlatMessageWriter,
) -> Result<(), Box<dyn Error + Send + Sync>> {
    let article_id = article.article_id.parse::<u32>()?;
    let min_page = article
        .pages
        .iter()
        .map(|page| page.page)
        .min()
        .unwrap_or(0);

    for page in article.pages {
        for dialogue in page.dialogues {
            let message = convert_query(&dialogue.text);
            if message.is_empty() {
                continue;
            }

            writer.push(&Message {
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

#[cfg(test)]
mod tests {
    use std::io::Read;
    use std::time::{SystemTime, UNIX_EPOCH};

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

    #[test]
    fn fscm_compress_writes_split_flat_files() {
        let root = unique_temp_dir("fscm-compress");
        let raw_dir = root.join("raw");
        let output_dir = root.join("out");
        fs::create_dir_all(&raw_dir).unwrap();

        fs::write(
            raw_dir.join("a.json"),
            r#"{"articleId":"10","pages":[{"page":1,"dialogues":[{"text":"first","confidence":0.5,"bbox":[1.0,2.0,3.0,4.0]}]}]}"#,
        )
        .unwrap();
        fs::write(
            raw_dir.join("b.json"),
            r#"{"articleId":"20","pages":[{"page":1,"dialogues":[{"text":"second","confidence":0.7,"bbox":[5.0,6.0,7.0,8.0]}]}]}"#,
        )
        .unwrap();

        compress_raw_dir(CompressOptions {
            raw_dir,
            output_dir: output_dir.clone(),
            splits: 2,
        })
        .unwrap();

        assert_eq!(flat_message_count(&output_dir.join("merged-0.fscm")), 1);
        assert_eq!(flat_message_count(&output_dir.join("merged-1.fscm")), 1);

        fs::remove_dir_all(root).unwrap();
    }

    fn unique_temp_dir(name: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("{name}-{}-{nanos}", std::process::id()))
    }

    fn flat_message_count(path: &Path) -> u64 {
        let mut file = File::open(path).unwrap();
        let mut header = [0; 24];
        file.read_exact(&mut header).unwrap();
        assert_eq!(&header[0..8], b"FSCMMSG1");
        u64::from_le_bytes(header[16..24].try_into().unwrap())
    }
}
