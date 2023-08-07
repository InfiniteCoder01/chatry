pub mod bot;
pub mod config;
pub mod gl;
pub mod math;
pub mod overlay;

#[macro_use]
extern crate glium;

use config::*;

use twitchchat::{
    messages::Commands,
    runner::{AsyncRunner, Status},
    UserConfig,
};

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct Private {
    pub channel: String,
    pub name: String,
    pub token: String,
}

fn main() -> Result<()> {
    let private = toml::from_str::<Private>(include_str!("../private.toml"))?;
    let config = toml::from_str::<Config>(&std::fs::read_to_string("config.toml")?)?;
    let user_config = UserConfig::builder()
        .name(&private.name)
        .token(&private.token)
        .enable_all_capabilities()
        .build()?;
    let connector = twitchchat::connector::smol::Connector::twitch()?;

    smol::block_on(async move {
        smol::spawn(async move {
            match overlay::create_overlay() {
                Result::Ok(overlay) => overlay::run_overlay(overlay),
                Err(err) => println!("Overlay not initialized: '{}'", err),
            }
        })
        .detach();

        let mut runner = AsyncRunner::connect(connector, &user_config).await?;
        runner.join(&private.channel).await?;
        let mut writer = runner.writer();
        let mut state = bot::State::new();

        loop {
            match runner.next_message().await? {
                Status::Message(Commands::Privmsg(pm)) => {
                    bot::on_message(&config, &mut state, &mut writer, pm)?
                }
                Status::Quit | Status::Eof => break,
                Status::Message(..) => continue,
            }
        }

        Ok(())
    })
}
