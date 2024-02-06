#![feature(unboxed_closures, fn_traits)]
use geng::prelude::*;
use overlay::*;

pub mod overlay;
pub mod youtube;

#[derive(Serialize, Deserialize)]
pub struct Private {
    pub token: String,
}

fn main() {
    logger::init_with({
        let mut logger = logger::builder();
        logger.filter_level(log::LevelFilter::Info);
        logger
    })
    .unwrap();
    geng::setup_panic_handler();

    let private =
        toml::from_str::<Private>(include_str!("/mnt/D/Channel/Private/private.toml")).unwrap();
    let config =
        toml::from_str::<Config>(&std::fs::read_to_string("config.toml").unwrap()).unwrap();
    let user_config = twitchchat::UserConfig::builder()
        .name(&config.name)
        .token(private.token)
        .enable_all_capabilities()
        .build()
        .unwrap();
    let connector = twitchchat::connector::smol::Connector::twitch().unwrap();

    let channels = config.channels.clone();
    let (runner, writer) = smol::block_on(async move {
        let mut runner = twitchchat::runner::AsyncRunner::connect(connector, &user_config)
            .await
            .unwrap();
        for channel in channels {
            runner.join(&channel).await.unwrap();
        }

        let writer = runner.writer();
        (runner, writer)
    });

    let (youtube_sender, youtube_receiver) = std::sync::mpsc::channel();

    let youtube_client = youtube_chat::live_chat::LiveChatClientBuilder::new()
        .channel_id(config.youtube_channel.clone())
        .on_chat(youtube::MessageTransferer(youtube_sender))
        .on_error(youtube::ErrorHandler)
        .build();

    Geng::run_with(
        &geng::ContextOptions {
            window: {
                let mut options = geng::window::Options::new("Chatry Overlay");
                options.transparency = true;
                options.fullscreen = true;
                options.mouse_passthrough = true;
                options.vsync = true;
                options
            },
            fixed_delta_time: 0.03,
            ..default()
        },
        |geng| async move {
            let assets: Hot<Assets> = geng
                .asset_manager()
                .load("assets")
                .await
                .expect("Failed to load assets");

            geng.run_state(State::new(
                &geng,
                config,
                assets,
                runner,
                writer,
                youtube_client,
                youtube_receiver,
            ))
            .await;
        },
    );
}
