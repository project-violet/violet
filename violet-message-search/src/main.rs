use std::path::PathBuf;

use chrono::Local;
use lazy_static::lazy_static;
use message::{
    article_lists, load_messages, search_article, search_partial_contains,
    search_partial_contains_many, search_similar, search_similar_many, MessageResult,
};
use rocket::serde::json::Json;
use serde::Deserialize;
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

    #[structopt(long, parse(from_os_str), default_value = "./merged-0.fscm")]
    data_paths: Vec<PathBuf>,
}

#[derive(Debug, Deserialize)]
struct WorkSearchRequest {
    ids: Vec<u32>,
    query: String,
    limit: Option<usize>,
}

lazy_static! {
    static ref OPT: Opt = Opt::from_args();
}

const DEFAULT_TAKE: usize = 1000;
const MAX_TAKE: usize = 1000;

fn current_date_time() -> String {
    Local::now().format("%Y-%m-%d.%H:%M:%S").to_string()
}

fn normalize_take(limit: Option<usize>) -> usize {
    limit.unwrap_or(DEFAULT_TAKE).clamp(1, MAX_TAKE)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_take_defaults_and_clamps_requested_limit() {
        assert_eq!(normalize_take(None), 1000);
        assert_eq!(normalize_take(Some(0)), 1);
        assert_eq!(normalize_take(Some(25)), 25);
        assert_eq!(normalize_take(Some(5000)), 1000);
    }
}

#[get("/<query>?<limit>")]
fn similar(query: &str, limit: Option<usize>) -> Json<Vec<MessageResult>> {
    let take = normalize_take(limit);
    println!(
        "({}) similar: {} (take={})",
        current_date_time(),
        query,
        take
    );
    Json(search_similar(None, query, take))
}

#[get("/<query>?<limit>")]
fn contains(query: &str, limit: Option<usize>) -> Json<Vec<MessageResult>> {
    let take = normalize_take(limit);
    println!(
        "({}) contains: {} (take={})",
        current_date_time(),
        query,
        take
    );
    Json(search_partial_contains(None, query, take))
}

#[get("/<id>/<query>?<limit>")]
fn wsimilar(id: u32, query: &str, limit: Option<usize>) -> Json<Vec<MessageResult>> {
    let take = normalize_take(limit);
    println!(
        "({}) wsimilar: {} - {} (take={})",
        current_date_time(),
        id,
        query,
        take
    );
    Json(search_similar(Some(id), query, take))
}

#[post("/", format = "json", data = "<request>")]
fn wsimilar_many(request: Json<WorkSearchRequest>) -> Json<Vec<MessageResult>> {
    let take = normalize_take(request.limit);
    println!(
        "({}) wsimilar-many: {} works - {} (take={})",
        current_date_time(),
        request.ids.len(),
        request.query,
        take
    );
    Json(search_similar_many(&request.ids, &request.query, take))
}

#[get("/<id>/<query>?<limit>")]
fn wcontains(id: u32, query: &str, limit: Option<usize>) -> Json<Vec<MessageResult>> {
    let take = normalize_take(limit);
    println!(
        "({}) wcontains: {} - {} (take={})",
        current_date_time(),
        id,
        query,
        take
    );
    Json(search_partial_contains(Some(id), query, take))
}

#[post("/", format = "json", data = "<request>")]
fn wcontains_many(request: Json<WorkSearchRequest>) -> Json<Vec<MessageResult>> {
    let take = normalize_take(request.limit);
    println!(
        "({}) wcontains-many: {} works - {} (take={})",
        current_date_time(),
        request.ids.len(),
        request.query,
        take
    );
    Json(search_partial_contains_many(
        &request.ids,
        &request.query,
        take,
    ))
}

#[get("/<id>")]
fn article(id: u32) -> Json<Vec<MessageResult>> {
    println!("({}) article: {}", current_date_time(), id);
    Json(search_article(id))
}

#[get("/")]
fn lists() -> Json<Vec<u32>> {
    println!("({}) lists", current_date_time());
    Json(article_lists())
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
        .mount("/wsimilar", routes![wsimilar, wsimilar_many])
        .mount("/wcontains", routes![wcontains, wcontains_many])
        .mount("/article", routes![article])
        .mount("/lists", routes![lists])
}
