use std::env;
use std::path::Path;

use itertools::Itertools;
use serde_json::Value;
use serenity::async_trait;
use serenity::framework::standard::macros::{command, group};
use serenity::framework::standard::{CommandResult, StandardFramework};
use serenity::model::channel::Message;
use serenity::model::prelude::AttachmentType;
use serenity::prelude::*;

pub(crate) mod auth;

#[group]
#[commands(rank, thumbnail)]
struct Commands;

struct Handler;

#[async_trait]
impl EventHandler for Handler {}

#[tokio::main]
async fn main() {
    let framework = StandardFramework::new()
        .configure(|c| c.prefix("~")) // set the bot's prefix to "~"
        .group(&COMMANDS_GROUP);

    // Login with a bot token from the environment
    let token = env::var("DISCORD_TOKEN").expect("token");
    let intents = GatewayIntents::non_privileged() | GatewayIntents::MESSAGE_CONTENT;
    let mut client = Client::builder(token, intents)
        .event_handler(Handler)
        .framework(framework)
        .await
        .expect("Error creating client");

    // start listening for events by starting a single shard
    if let Err(why) = client.start().await {
        println!("An error occurred while running the client: {:?}", why);
    }
}

#[command]
async fn rank(ctx: &Context, msg: &Message) -> CommandResult {
    let response = reqwest::get("https://koromo.xyz/api/top?offset=0&count=10&type=daily").await?;

    if !response.status().is_success() {
        msg.reply(ctx, "Internal Server Error 😢").await?;
        return Ok(());
    }

    let body = response.text().await?;
    let result: Value = serde_json::from_str(&body[..])?;
    let result = result["result"]
        .as_array()
        .unwrap()
        .iter()
        .map(|e| {
            let id = e.as_array().unwrap()[0].as_i64().unwrap();
            let cnt = e.as_array().unwrap()[1].as_i64().unwrap();

            format!("{id}({cnt})")
        })
        .enumerate()
        .map(|(index, e)| format!("{}. {e}", index + 1))
        .join("\n");

    msg.reply(ctx, &result[..]).await?;

    Ok(())
}

#[command]
async fn thumbnail(ctx: &Context, msg: &Message) -> CommandResult {
    send_image(ctx, msg).await;

    Ok(())
}

async fn send_image(ctx: &Context, msg: &Message) {
    let file_path = "./test.gif";

    if let Err(why) = msg
        .channel_id
        .send_files(ctx, vec![AttachmentType::Path(file_path.as_ref())], |m| m)
        .await
    {
        eprintln!("Error sending files: {:?}", why);
    }
}
