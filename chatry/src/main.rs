use geng::prelude::*;
use overlay::*;

pub mod overlay;

#[derive(Serialize, Deserialize)]
pub struct Private {
    pub token: String,
}

fn main() {
    logger::init();
    geng::setup_panic_handler();

    let private = toml::from_str::<Private>(include_str!("../../private.toml")).unwrap();
    let config =
        toml::from_str::<Config>(&std::fs::read_to_string("config.toml").unwrap()).unwrap();
    let user_config = twitchchat::UserConfig::builder()
        .name(&config.name)
        .token(private.token)
        .enable_all_capabilities()
        .build()
        .unwrap();
    let connector = twitchchat::connector::smol::Connector::twitch().unwrap();

    let channel = config.channel.clone();
    let (runner, writer) = smol::block_on(async move {
        let mut runner = twitchchat::runner::AsyncRunner::connect(connector, &user_config)
            .await
            .unwrap();
        runner.join(&channel).await.unwrap();

        let writer = runner.writer();
        (runner, writer)
    });

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
            fixed_delta_time: 0.01,
            ..default()
        },
        |geng| async move {
            let assets: Hot<Assets> = geng
                .asset_manager()
                .load("assets")
                .await
                .expect("Failed to load assets");

            geng.run_state(State::new(&geng, config, assets, runner, writer))
                .await;
        },
    );
}
