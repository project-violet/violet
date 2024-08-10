use std::path::PathBuf;

use chrono::Local;
use lazy_static::lazy_static;
use message::{load_messages, search_partial_contains, search_similar, MessageResult};
use rocket::serde::json::Json;
use structopt::StructOpt;

mod binding;
mod cache;
mod displant;
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

fn current_date_time() -> String {
    Local::now().format("%Y-%m-%d.%H:%M:%S").to_string()
}

#[get("/<query>")]
fn similar(query: &str) -> Json<Vec<MessageResult>> {
    println!("({}) similar: {}", current_date_time(), query);
    Json(search_similar(None, query, 1000))
}

#[get("/<query>")]
fn contains(query: &str) -> Json<Vec<MessageResult>> {
    println!("({}) contains: {}", current_date_time(), query);
    Json(search_partial_contains(None, query, 1000))
}

#[get("/<id>/<query>")]
fn wsimilar(id: usize, query: &str) -> Json<Vec<MessageResult>> {
    println!("({}) wsimilar: {} - {}", current_date_time(), id, query);
    Json(search_similar(Some(id), query, 1000))
}

#[get("/<id>/<query>")]
fn wcontains(id: usize, query: &str) -> Json<Vec<MessageResult>> {
    println!("({}) wcontains: {} - {}", current_date_time(), id, query);
    Json(search_partial_contains(Some(id), query, 1000))
}

#[launch]
fn rocket() -> _ {
    OPT.data_paths
        .iter()
        .for_each(|path| load_messages(path.clone()));

    println!("fscm has launched from http://{}:{}", OPT.host, OPT.port);

    rocket::build()
        .configure(
            // https://api.rocket.rs/v0.4/rocket/config/
            rocket::Config::figment()
                .merge(("log_level", "off"))
                .merge(("address", OPT.host.clone()))
                .merge(("port", OPT.port)),
        )
        .mount("/similar", routes![similar])
        .mount("/contains", routes![contains])
        .mount("/wsimilar", routes![wsimilar])
        .mount("/wcontains", routes![wcontains])
}
