use std::path::PathBuf;

use message::load_messages;
use structopt::StructOpt;

mod binding;
mod message;

#[derive(Debug, StructOpt)]
#[structopt(name = "fast-search", about = "Fast Search for Comic Message")]
struct Opt {
    host: String,
    port: usize,
    token: Option<String>,

    #[structopt(long, parse(from_os_str), default_value = "./merged.json")]
    data_path: PathBuf,
}

fn main() {
    let opt = Opt::from_args();

    let messages = load_messages(opt.data_path);

    println!("Server opened at http://{}:{}", opt.host, opt.port);
}
