#![feature(unboxed_closures, fn_traits)]
use geng::prelude::*;
use overlay::*;

pub mod api;
pub mod overlay;

#[derive(Serialize, Deserialize)]
pub struct Private {
    pub token: String,
    pub streamer_token: String,
}

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub channels: Vec<String>,
    pub youtube_channel: String,
    pub name: String,
    pub admins: Vec<String>,
    pub qotd: String,
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
        toml::from_str::<Private>(include_str!("/mnt/D/Channel/Private/chatry.toml")).unwrap();
    let config =
        toml::from_str::<Config>(&std::fs::read_to_string("config.toml").unwrap()).unwrap();

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
            keyring::set_global_service_name("Chatry");

            let assets: Hot<Assets> = geng
                .asset_manager()
                .load("assets")
                .await
                .expect("Failed to load assets");

            geng.run_state(State::new(&geng, private, config, assets))
                .await;
        },
    );
}
