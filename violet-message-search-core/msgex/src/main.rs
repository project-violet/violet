use std::{
    collections::HashMap,
    fs::{self, File},
};

use aho_corasick::AhoCorasick;
use indicatif::ProgressBar;
use serde::{Deserialize, Serialize};
use serde_json::{from_reader, Value};

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

fn main() {}
