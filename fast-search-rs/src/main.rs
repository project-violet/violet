use std::path::PathBuf;

use lazy_static::lazy_static;
use message::load_messages;
use structopt::StructOpt;

mod binding;
mod message;

#[macro_use]
extern crate rocket;

#[derive(Debug, StructOpt)]
#[structopt(name = "fast-search", about = "Fast Search for Comic Message")]
struct Opt {
    host: String,
    port: usize,
    token: Option<String>,

    #[structopt(long, parse(from_os_str), default_value = "./merged.json")]
    data_paths: Vec<PathBuf>,
}

lazy_static! {
    static ref OPT: Opt = Opt::from_args();
}

#[get("/<name>/<age>")]
fn hello(name: &str, age: u8) -> String {
    format!("Hello, {} year old named {}!", age, name)
}

#[launch]
fn rocket() -> _ {
    OPT.data_paths
        .iter()
        .for_each(|path| load_messages(path.clone()));

    rocket::build()
        .configure(
            // https://api.rocket.rs/v0.4/rocket/config/
            rocket::Config::figment()
                .merge(("address", OPT.host.clone()))
                .merge(("port", OPT.port)),
        )
        .mount("/hello", routes![hello])
}
