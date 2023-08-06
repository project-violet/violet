use std::env;

use serenity::async_trait;
use serenity::framework::standard::macros::{command, group};
use serenity::framework::standard::{CommandResult, StandardFramework};
use serenity::model::channel::Message;
use serenity::model::prelude::AttachmentType;
use serenity::prelude::*;

use crate::violet::request_rank;

pub(crate) mod violet;

#[group]
#[commands(rank, thumbnail)]
struct Commands;

struct Handler;

#[async_trait]
impl EventHandler for Handler {
    async fn message(&self, _ctx: Context, msg: Message) {
        let name = msg.author.name;
        let id = msg.author.id;
        let content = msg.content;
        tracing::info!("[Command] {name}({id}): {content:?}");
    }
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

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
    let Ok(result) = request_rank().await else {
        msg.reply(ctx, "Internal Server Error 😢").await?;
        return Ok(());
    };

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
