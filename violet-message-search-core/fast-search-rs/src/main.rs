use std::path::PathBuf;

use lazy_static::lazy_static;
use message::{load_messages, search_partial_contains, search_similar, MessageResult};
use rocket::serde::json::Json;
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

    #[structopt(long, parse(from_os_str), default_value = "./merged.json")]
    data_paths: Vec<PathBuf>,
}

lazy_static! {
    static ref OPT: Opt = Opt::from_args();
}

#[get("/<query>")]
fn similar(query: &str) -> Json<Vec<MessageResult>> {
    Json(search_similar(query, 1000))
}

#[get("/<query>")]
fn contains(query: &str) -> Json<Vec<MessageResult>> {
    Json(search_partial_contains(query, 1000))
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
                .merge(("log", "off"))
                .merge(("address", OPT.host.clone()))
                .merge(("port", OPT.port)),
        )
        .mount("/similar", routes![similar])
        .mount("/contains", routes![contains])
}
