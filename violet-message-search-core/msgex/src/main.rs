use std::{
    collections::{HashMap, HashSet},
    fs::{self, File},
    path::Path,
};

use aho_corasick::AhoCorasick;
use indicatif::ProgressBar;
use itertools::{izip, Itertools};
use serde::{Deserialize, Serialize};
use serde_json::{from_reader, Value};
use tfidf::{TfIdf, TfIdfDefault};

#[derive(Serialize, Deserialize)]
struct SingleMessage {
    article_id: i64,
    page: i64,
    score: f64,
    msg: String,
}

fn merge_caches() {
    let paths = fs::read_dir("G:\\Dev2\\violet-message-search\\cache-raw").unwrap();
    let mut result = Vec::new();

    let bar = ProgressBar::new(paths.count() as u64);

    let paths = fs::read_dir("G:\\Dev2\\violet-message-search\\cache-raw").unwrap();
    for path in paths {
        let file = File::open(path.unwrap().path()).unwrap();
        let value: Value = simd_json::serde::from_reader(file).unwrap();

        for e in value.as_array().unwrap() {
            result.push(SingleMessage {
                article_id: e["ArticleId"].as_i64().unwrap(),
                page: e["Page"].as_i64().unwrap(),
                msg: String::from(e["MessageRaw"].as_str().unwrap()),
                score: e["Score"].as_f64().unwrap(),
            });
        }
        bar.inc(1);
    }
    bar.finish();

    fs::write("messages.json", simd_json::to_string(&result).unwrap()).unwrap();
}

fn load_messages() -> Vec<SingleMessage> {
    let file = File::open("./messages.json").unwrap();
    simd_json::serde::from_reader(file).unwrap()
}

fn load_wordcand() -> HashMap<String, i64> {
    let file = File::open("./word-cand.json").unwrap();
    simd_json::serde::from_reader(file).unwrap()
}

#[test]
fn test_tokenize_split_by_space() {
    // let mut result = String::new();
    let mut wmap: HashMap<String, usize> = HashMap::new();

    for msg in load_messages() {
        let m_s = msg.msg.split(" ");
        m_s.for_each(|x| {
            *wmap.entry(String::from(x)).or_default() += 1;
        });
    }

    // fs::write("messages", result).unwrap();

    let mut wvec: Vec<_> = wmap.iter().collect();
    wvec.sort_by(|x, y| y.1.cmp(x.1));

    fs::write("v.json", simd_json::to_string_pretty(&wvec).unwrap()).unwrap();

    // for x in wvec.iter().take(100) {
    //     println!("{:?}", x);
    // }
}

fn map_sort_by_key<K, V>(map: &HashMap<K, V>) -> Vec<(&K, &V)>
where
    K: Ord,
    V: Ord,
{
    let mut wvec: Vec<_> = map.iter().collect();
    wvec.sort_by(|x: &(&K, &V), y| y.1.cmp(x.1));
    wvec
}

// 유효한 단어들을 추출하기 위한 밑작업
// token: 단어
// search: 사용자가 검색한 횟수
// usage: 실제 대사에서 사용된 횟수
fn extract_token_search_usage() {
    let wordcand_map = load_wordcand();
    let wordcand = map_sort_by_key(&wordcand_map);

    let filtered_word: Vec<_> = wordcand
        .iter()
        .filter(|x| !x.0.contains(' '))
        .map(|x| &x.0[..])
        .collect();

    let ac = AhoCorasick::builder()
        .match_kind(aho_corasick::MatchKind::LeftmostFirst)
        .build(&filtered_word)
        .unwrap();
    let mut wordcand_cnt: HashMap<&str, i64> = HashMap::new();

    let messages = load_messages();

    let bar = ProgressBar::new(messages.len() as u64);
    for msg in messages {
        for mat in ac.find_iter(&msg.msg) {
            *wordcand_cnt
                .entry(filtered_word[mat.pattern().as_usize()])
                .or_default() += 1;
        }
        bar.inc(1);
    }
    bar.finish();

    let wordcand_cnt_vec = map_sort_by_key(&wordcand_cnt);

    // for x in wordcand.iter().take(1000) {
    //     if wordcand_cnt.contains_key(&x.0[..]) {
    //         println!("{:?} {}", x, wordcand_cnt[&x.0[..]]);
    //     }
    // }

    let mut result = String::new();

    for x in wordcand {
        // println!("{}, {}, {}", x.0, x.1, wordcand_map[&String::from(*x.0)]);
        // result.push_str(&format!(
        //     "{}, {}, {}\n",
        //     x.0,
        //     x.1,
        //     wordcand_map[&x.0[..]]
        // ));
        if wordcand_cnt.contains_key(&x.0[..]) {
            result.push_str(&format!("{}, {}, {}\n", x.0, x.1, wordcand_cnt[&x.0[..]]));
        }
    }

    fs::write("result", result).unwrap();
}

fn extract_token_connector_by_sentence() {
    let wordcand_map = load_wordcand();
    let wordcand = map_sort_by_key(&wordcand_map);

    let filtered_word: Vec<_> = wordcand
        .iter()
        .filter(|x| !x.0.contains(' '))
        .map(|x| &x.0[..])
        .collect();

    let ac = AhoCorasick::builder()
        .match_kind(aho_corasick::MatchKind::LeftmostFirst)
        .build(&filtered_word)
        .unwrap();
    let mut conn: HashMap<&str, HashMap<&str, i64>> = HashMap::new();

    let messages = load_messages();

    let bar = ProgressBar::new(messages.len() as u64);
    for msg in messages {
        for mat1 in ac.find_iter(&msg.msg) {
            for mat2 in ac.find_iter(&msg.msg) {
                *conn
                    .entry(filtered_word[mat1.pattern().as_usize()])
                    .or_default()
                    .entry(filtered_word[mat2.pattern().as_usize()])
                    .or_default() += 1
            }
        }
        bar.inc(1);
    }
    bar.finish();

    fs::write(
        "word-conn-sen.json",
        simd_json::to_string_pretty(&conn).unwrap(),
    )
    .unwrap();
}

fn load_conn_sen() -> HashMap<String, HashMap<String, i64>> {
    let file = File::open("./word-conn-sen.json").unwrap();
    simd_json::serde::from_reader(file).unwrap()
}

fn extract_token_connector_by_page() {
    let wordcand_map = load_wordcand();
    let wordcand = map_sort_by_key(&wordcand_map);

    let filtered_word: Vec<_> = wordcand
        .iter()
        // .filter(|x| !x.0.contains(' '))
        .filter(|x| {
            !x.0.contains(" ") && x.0.chars().count() < 8 && x.0.chars().count() > 1 && *x.1 > 100
        })
        .map(|x| &x.0[..])
        .collect();

    let ac = AhoCorasick::builder()
        .match_kind(aho_corasick::MatchKind::LeftmostFirst)
        .build(&filtered_word)
        .unwrap();
    let mut conn: HashMap<&str, HashMap<&str, i64>> = HashMap::new();

    let messages = load_messages();

    let bar = ProgressBar::new(
        messages
            .iter()
            .group_by(|msg| (msg.article_id, msg.page))
            .into_iter()
            .count() as u64,
    );

    for msg in messages
        .iter()
        .group_by(|msg| (msg.article_id, msg.page))
        .into_iter()
    {
        let msg_con = msg.1.map(|x| &x.msg).join(" ");
        for mat1 in ac.find_iter(&msg_con) {
            for mat2 in ac.find_iter(&msg_con) {
                if mat1.pattern() == mat2.pattern() {
                    continue;
                }

                *conn
                    .entry(filtered_word[mat1.pattern().as_usize()])
                    .or_default()
                    .entry(filtered_word[mat2.pattern().as_usize()])
                    .or_default() += 1
            }
        }
        bar.inc(1);
    }
    bar.finish();

    // let mut result: Vec<(&str, Vec<(&&str, &i64)>)> = Vec::new();

    // conn.iter()
    //     .for_each(|x| result.push((x.0, map_sort_by_key(x.1))));

    fs::write(
        "word-conn-page3.json",
        simd_json::to_string_pretty(&conn).unwrap(),
    )
    .unwrap();
}

fn load_conn_page() -> HashMap<String, HashMap<String, i64>> {
    let file = File::open("./word-conn-page.json").unwrap();
    simd_json::serde::from_reader(file).unwrap()
}

fn extract_token_connector_by_article() {
    let wordcand_map = load_wordcand();
    let wordcand = map_sort_by_key(&wordcand_map);

    let filtered_word: Vec<_> = wordcand
        .iter()
        // .filter(|x| !x.0.contains(' '))
        .filter(|x| {
            !x.0.contains(" ") && x.0.chars().count() < 8 && x.0.chars().count() > 1 && *x.1 > 100
        })
        .map(|x| &x.0[..])
        .collect();

    let ac = AhoCorasick::builder()
        .match_kind(aho_corasick::MatchKind::LeftmostFirst)
        .build(&filtered_word)
        .unwrap();
    let mut conn: HashMap<&str, HashMap<&str, i64>> = HashMap::new();

    let messages = load_messages();

    let bar = ProgressBar::new(
        messages
            .iter()
            .group_by(|msg| msg.article_id)
            .into_iter()
            .count() as u64,
    );

    for msg in messages.iter().group_by(|msg| msg.article_id).into_iter() {
        let msg_con = msg.1.map(|x| &x.msg).join(" ");
        for mat1 in ac.find_iter(&msg_con) {
            for mat2 in ac.find_iter(&msg_con) {
                if mat1.pattern() == mat2.pattern() {
                    continue;
                }

                *conn
                    .entry(filtered_word[mat1.pattern().as_usize()])
                    .or_default()
                    .entry(filtered_word[mat2.pattern().as_usize()])
                    .or_default() += 1
            }
        }
        bar.inc(1);
    }
    bar.finish();

    // let mut result: Vec<(&str, Vec<(&&str, &i64)>)> = Vec::new();

    // conn.iter()
    //     .for_each(|x| result.push((x.0, map_sort_by_key(x.1))));

    fs::write(
        "word-conn-article.json",
        simd_json::to_string_pretty(&conn).unwrap(),
    )
    .unwrap();
}

fn load_conn_article() -> HashMap<String, HashMap<String, i64>> {
    let file = File::open("./word-conn-article.json").unwrap();
    simd_json::serde::from_reader(file).unwrap()
}

#[test]
fn test_tf_idf() {
    let mut docs = Vec::new();
    let doc1 = vec![("a", 3), ("b", 2), ("c", 4)];
    let doc2 = vec![("a", 2), ("d", 5)];

    docs.push(doc1);
    docs.push(doc2);

    assert_eq!(0f64, TfIdfDefault::tfidf("a", &docs[0], docs.iter()));
    assert!(TfIdfDefault::tfidf("c", &docs[0], docs.iter()) > 0.5);
}

fn tfidf() {
    let wordcand_map = load_wordcand();
    let wordcand = map_sort_by_key(&wordcand_map);

    let filtered_word: Vec<_> = wordcand
        .iter()
        // .filter(|x| !x.0.contains(' '))
        .filter(|x| {
            !x.0.contains(" ") && x.0.chars().count() < 8 && x.0.chars().count() > 1 && *x.1 > 100
        })
        .map(|x| &x.0[..])
        .collect();

    let ac = AhoCorasick::builder()
        .match_kind(aho_corasick::MatchKind::LeftmostFirst)
        .build(&filtered_word)
        .unwrap();

    let messages: Vec<SingleMessage> = load_messages();

    let bar = ProgressBar::new(
        messages
            .iter()
            .group_by(|msg| msg.article_id)
            .into_iter()
            .count() as u64,
    );

    let mut docs: Vec<Vec<(&str, usize)>> = Vec::new();

    for msg in messages.iter().group_by(|msg| msg.article_id).into_iter() {
        let msg_con = msg.1.map(|x| &x.msg).join(" ");
        let mut doc: HashMap<&str, usize> = HashMap::new();
        for mat1 in ac.find_iter(&msg_con) {
            *doc.entry(filtered_word[mat1.pattern().as_usize()])
                .or_default() += 1;
        }
        docs.push(doc.into_iter().collect());
        bar.inc(1);
    }
    bar.finish();

    let test_var = TfIdfDefault::tfidf("오징어", &docs[0], docs.iter());
    println!("{test_var}");
}

fn count_usage_all_article() {
    let wordcand_map = load_wordcand();
    let wordcand = map_sort_by_key(&wordcand_map);

    let filtered_word: Vec<_> = wordcand
        .iter()
        // .filter(|x| !x.0.contains(' '))
        .filter(|x| {
            !x.0.contains(" ") && x.0.chars().count() < 8 && x.0.chars().count() > 1 && *x.1 > 20
        })
        .map(|x| &x.0[..])
        .collect();

    let ac = AhoCorasick::builder()
        .match_kind(aho_corasick::MatchKind::LeftmostFirst)
        .build(&filtered_word)
        .unwrap();

    let messages: Vec<SingleMessage> = load_messages();

    let bar = ProgressBar::new(
        messages
            .iter()
            .group_by(|msg| msg.article_id)
            .into_iter()
            .count() as u64,
    );

    let mut map: HashMap<&str, usize> = HashMap::new();

    for msg in messages.iter().group_by(|msg| msg.article_id).into_iter() {
        let msg_con = msg.1.map(|x| &x.msg).join(" ");
        let mut already_map: HashSet<&str> = HashSet::new();
        for mat1 in ac.find_iter(&msg_con) {
            let word = filtered_word[mat1.pattern().as_usize()];
            if already_map.get(word).is_none() {
                already_map.insert(word);
                *map.entry(word).or_default() += 1;
            }
        }
        bar.inc(1);
    }
    bar.finish();

    let result_map = map_sort_by_key(&map);

    let mut result = String::new();

    for x in result_map {
        // println!("{}, {}, {}", x.0, x.1, wordcand_map[&String::from(*x.0)]);
        // result.push_str(&format!(
        //     "{}, {}, {}\n",
        //     x.0,
        //     x.1,
        //     wordcand_map[&x.0[..]]
        // ));
        result.push_str(&format!("{} {}\n", x.0, x.1));
    }

    fs::write("count-usage.txt", result).unwrap();
}

struct MessageAnalyzerField {
    filter_count_limit: i64,
    filtered_word: Vec<String>,
    ac: AhoCorasick,
    messages: Vec<SingleMessage>,
}

impl MessageAnalyzerField {
    fn new(filter_count_limit: i64) -> Self {
        let wordcand_map = load_wordcand();
        let wordcand = map_sort_by_key(&wordcand_map);

        let filtered_word: Vec<_> = wordcand
            .iter()
            .filter(|x| {
                !x.0.contains(" ")
                    && x.0.chars().count() < 8
                    && x.0.chars().count() > 1
                    && *x.1 > filter_count_limit
            })
            .map(|x| String::from(x.0))
            .collect();

        let ac = AhoCorasick::builder()
            .match_kind(aho_corasick::MatchKind::LeftmostFirst)
            .build(&filtered_word)
            .unwrap();

        let messages: Vec<SingleMessage> = load_messages();

        MessageAnalyzerField {
            filter_count_limit,
            filtered_word,
            ac,
            messages,
        }
    }

    fn iter_by_article<F>(&self, mut func: F)
    where
        F: FnMut(String),
    {
        let bar = ProgressBar::new(
            self.messages
                .iter()
                .group_by(|msg| msg.article_id)
                .into_iter()
                .count() as u64,
        );

        for msg in self
            .messages
            .iter()
            .group_by(|msg| msg.article_id)
            .into_iter()
        {
            let msg_con = msg.1.map(|x| &x.msg).join(" ");
            func(msg_con);
            bar.inc(1);
        }

        bar.finish();
    }

    fn iter_by_article_with_articleid<F>(&self, mut func: F)
    where
        F: FnMut(String, i64),
    {
        let bar = ProgressBar::new(
            self.messages
                .iter()
                .group_by(|msg| msg.article_id)
                .into_iter()
                .count() as u64,
        );

        for msg in self
            .messages
            .iter()
            .group_by(|msg| msg.article_id)
            .into_iter()
        {
            let msg_con = msg.1.map(|x| &x.msg).join(" ");
            func(msg_con, msg.0);
            bar.inc(1);
        }

        bar.finish();
    }

    fn iter_by_word_for_str<F>(&self, target: &str, mut func: F)
    where
        F: FnMut(&str),
    {
        for mat1 in self.ac.find_iter(&target) {
            func(&self.filtered_word[mat1.pattern().as_usize()]);
        }
    }

    fn iter_by_word_for_str_atomic<F>(&self, target: &str, mut func: F)
    where
        F: FnMut(&str),
    {
        let mut already_map: HashSet<&str> = HashSet::new();
        for mat1 in self.ac.find_iter(&target) {
            let word = &self.filtered_word[mat1.pattern().as_usize()][..];
            if already_map.get(word).is_none() {
                already_map.insert(word);
                func(&word);
            }
        }
    }

    fn count_word_usage_by_article(&self) -> HashMap<String, usize> {
        let fname = format!("word-usage-article-{}.json", self.filter_count_limit);

        if Path::new(&fname).exists() {
            let file = File::open(fname).unwrap();
            return simd_json::serde::from_reader(file).unwrap();
        }

        let mut map: HashMap<String, usize> = HashMap::new();

        self.iter_by_article(|target| {
            self.iter_by_word_for_str_atomic(&target, |word| {
                let key = String::from(word);
                *map.entry(key).or_default() += 1;
            });
        });

        fs::write(fname, simd_json::to_string_pretty(&map).unwrap()).unwrap();

        map
    }

    fn extract_token_connector_by_article(&self) -> HashMap<String, HashMap<String, i64>> {
        let fname = format!("word-conn-article-{}.json", self.filter_count_limit);

        if Path::new(&fname).exists() {
            let file = File::open(fname).unwrap();
            return simd_json::serde::from_reader(file).unwrap();
        }

        let mut conn: HashMap<String, HashMap<String, i64>> = HashMap::new();

        self.iter_by_article(|target| {
            self.iter_by_word_for_str_atomic(&target, |word1| {
                self.iter_by_word_for_str_atomic(&target, |word2| {
                    if word1 == word2 {
                        return;
                    }

                    *conn
                        .entry(String::from(word1))
                        .or_default()
                        .entry(String::from(word2))
                        .or_default() += 1
                });
            });
        });

        fs::write(fname, simd_json::to_string_pretty(&conn).unwrap()).unwrap();

        conn
    }

    fn build_tfidf_docs(&self) -> Vec<Vec<(String, usize)>> {
        let fname = format!("tfidf-docs.json");

        if Path::new(&fname).exists() {
            let file = File::open(fname).unwrap();
            return simd_json::serde::from_reader(file).unwrap();
        }

        let mut docs: Vec<Vec<(String, usize)>> = Vec::new();

        self.iter_by_article(|target| {
            let mut doc: HashMap<String, usize> = HashMap::new();
            self.iter_by_word_for_str(&target, |word| {
                *doc.entry(String::from(word)).or_default() += 1;
            });
            docs.push(doc.into_iter().collect());
        });

        fs::write(fname, simd_json::to_string_pretty(&docs).unwrap()).unwrap();

        docs
    }

    fn extract_article_by_most_used_from_word(&self, what: &str) -> Vec<(i64, i64)> {
        // (articleid, find count, total sentence count)
        let mut result = Vec::new();

        self.iter_by_article_with_articleid(|target, articleid| {
            let mut count = 0;
            self.iter_by_word_for_str(&target, |word| {
                if word == what {
                    count += 1;
                }
            });
            result.push((articleid, count));
        });

        result
    }
}

fn main() {
    // let conn = load_conn_article();

    // let ex = map_sort_by_key(&conn["오징어"]);

    // for e in ex.iter().filter(|x| x.0.chars().count() > 1).take(100) {
    //     println!("{:?}", e);
    // }

    // count_usage_all_article();

    let field = MessageAnalyzerField::new(20);
    /*

    let usage = field.count_word_usage_by_article();
    let conn = field.extract_token_connector_by_article();

    let article_count = field.messages.len();
    let mut result = Vec::new();

    let weight = 1.0;

    map_sort_by_key(&conn["여동생"]).iter().for_each(|x| {
        result.push((
            x.0,
            *x.1 * (weight + (article_count - usage[x.0]) as f64 * (1.0 - weight)) as i64,
        ));
    });

    result.sort_by(|x, y| y.1.cmp(&x.1));

    result.iter().take(100).for_each(|x| {
        println!("{:?}", x);
    });
    */

    let tfidf = field.build_tfidf_docs();

    let mut y = field.extract_article_by_most_used_from_word("여동생");
    y.sort_by(|x, y| y.1.cmp(&x.1));
    y.iter().take(100).for_each(|x| {
        let article_messages = field
            .messages
            .iter()
            .filter(|e| e.article_id == x.0)
            .map(|x| &x.msg)
            .join(" ");

        let mut doc: HashMap<String, usize> = HashMap::new();
        field.iter_by_word_for_str(&article_messages, |word| {
            *doc.entry(String::from(word)).or_default() += 1;
        });
        let doc: Vec<_> = doc.into_iter().collect();

        println!(
            "{:?} {} ",
            x,
            TfIdfDefault::tfidf(String::from("오빠"), &doc, tfidf.iter())
        );
    });

    // let wordcand_map = load_wordcand();
    // let wordcand = map_sort_by_key(&wordcand_map);

    // for w in wordcand.iter().filter(|x| {
    //     !x.0.contains(" ") && x.0.chars().count() < 8 && x.0.chars().count() > 1 && *x.1 > 30
    // }) {
    //     println!("{:?}", w);
    // }
    // extract_token_connector_by_article();
}
