use std::path::PathBuf;

use fast_search_rs::raw_compress::{compress_raw_dir, CompressOptions};
use structopt::StructOpt;

#[derive(Debug, StructOpt)]
#[structopt(
    name = "raw-compress",
    about = "Convert violet-search raw OCR JSON files to fast-search-rs merged JSON files"
)]
struct Opt {
    #[structopt(long, parse(from_os_str))]
    raw_dir: PathBuf,

    #[structopt(long, parse(from_os_str), default_value = ".")]
    output_dir: PathBuf,

    #[structopt(long, default_value = "3")]
    splits: usize,
}

fn main() {
    let opt = Opt::from_args();
    if let Err(err) = compress_raw_dir(CompressOptions {
        raw_dir: opt.raw_dir,
        output_dir: opt.output_dir,
        splits: opt.splits,
    }) {
        eprintln!("raw-compress failed: {err}");
        std::process::exit(1);
    }
}
