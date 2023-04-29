use std::fs::{self, File};

use indicatif::ProgressBar;
use serde_json::{from_reader, Value};

fn main() {
    let paths = fs::read_dir("G:\\Dev2\\violet-message-search\\cache-raw").unwrap();
    let mut result = String::new();

    let bar = ProgressBar::new(paths.count() as u64);

    let paths = fs::read_dir("G:\\Dev2\\violet-message-search\\cache-raw").unwrap();
    for path in paths {
        let file = File::open(path.unwrap().path()).unwrap();
        let value: Value = simd_json::serde::from_reader(file).unwrap();

        for e in value.as_array().unwrap() {
            let x = format!(
                "[{}/{}] {} ({})\n",
                e["ArticleId"].as_i64().unwrap(),
                e["Page"].as_i64().unwrap(),
                e["MessageRaw"].as_str().unwrap(),
                e["Score"].as_f64().unwrap(),
            );

            result.push_str(&x);
        }
        bar.inc(1);
    }
    bar.finish();

    fs::write("result.txt", result).unwrap();

    println!("Hello, world!");
}
