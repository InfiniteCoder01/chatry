pub mod bot;
pub mod config;
pub mod overlay;

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

    smol::spawn(async move {
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
    }).detach();

    if let Err(err) = overlay::run_overlay() {
        println!("Overlay not initialized: '{}'", err);
    }

    Ok(())
}
