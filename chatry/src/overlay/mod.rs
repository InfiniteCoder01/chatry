use geng::prelude::*;
use plushies::*;
use twitchchat::AsyncRunner;

pub mod bot;
pub mod plushies;

#[derive(geng::asset::Load)]
pub struct Assets {
    pub plushies: Plushies,
    pub readchat: geng::Sound,
}

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub channels: Vec<String>,
    pub youtube_channel: String,
    pub name: String,
    pub admins: Vec<String>,
    pub qotd: String,
}

// * ------------------------------------- State ------------------------------------ * //
pub type Writer = twitchchat::writer::AsyncWriter<twitchchat::writer::MpscWriter>;

#[derive(Clone, Debug)]
pub struct Message {
    pub username: String,
    pub user_color: Rgba<f32>,
    pub text: String,
    pub timeout: std::time::Instant,
}

pub struct State {
    geng: Geng,
    assets: Hot<Assets>,
    size: vec2<usize>,
    config: Config,

    runner: AsyncRunner,
    writer: Writer,
    youtube_reciever: std::sync::mpsc::Receiver<youtube_chat::item::ChatItem>,
    _runtime: tokio::runtime::Runtime,

    world: World,
    messages: Vec<Message>,
}

impl State {
    pub fn new(
        geng: &Geng,
        config: Config,
        assets: Hot<Assets>,
        runner: AsyncRunner,
        mut writer: Writer,
        youtube_client: crate::youtube::YoutubeClient,
        youtube_reciever: crate::youtube::YoutubeReciever,
    ) -> Self {
        smol::block_on(async {
            for channel in &config.channels {
                writer
                    .encode(twitchchat::commands::privmsg(&channel, "I'm awake!"))
                    .await
                    .unwrap();
            }
        });

        let runtime = tokio::runtime::Runtime::new().unwrap();
        let (mut youtube_client, youtube_initialized) = crate::youtube::init(youtube_client);
        if youtube_initialized {
            runtime.spawn(async move {
                let mut interval = tokio::time::interval(std::time::Duration::from_millis(500));
                loop {
                    interval.tick().await;
                    youtube_client.execute().await;
                }
            });
        }

        Self {
            geng: geng.clone(),
            assets,
            size: vec2(128, 128),
            config,

            runner,
            writer,
            youtube_reciever,
            _runtime: runtime,

            world: World::default(),
            messages: Vec::new(),
        }
    }
}

impl geng::State for State {
    fn draw(&mut self, framebuffer: &mut ugli::Framebuffer) {
        ugli::clear(framebuffer, Some(Rgba::TRANSPARENT_BLACK), None, None);
        self.size = framebuffer.size();

        // * World
        for plushie in &self.world.plushies {
            if let Some(proto) = self.assets.get().plushies.get(&plushie.name) {
                self.geng.draw2d().draw2d(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &geng::draw2d::TexturedPolygon::with_mode(
                        plushie
                            .triangles
                            .iter()
                            .flatten()
                            .map(|&index| {
                                let particle = &plushie.particles[index];
                                draw2d::TexturedVertex {
                                    a_pos: particle.pos,
                                    a_color: Rgba::WHITE,
                                    a_vt: particle.uv,
                                }
                            })
                            .collect(),
                        &proto.image,
                        ugli::DrawMode::Triangles,
                    ),
                );
            }
        }

        // * Chat
        let padding = 10.0;
        let size = 20.0;
        let outline = 2.0 / size;
        let width = 350.0;

        let mut y = framebuffer.size().y as f32 / 4.0;
        y += padding;
        for message in self.messages.iter().rev() {
            let align = vec2(geng::TextAlign::LEFT, geng::TextAlign::TOP);
            let x = framebuffer.size().x as f32 - width - padding;

            if let (Some(full), Some(uname)) = (
                self.geng
                    .default_font()
                    .measure(&format!("{}: {}", message.username, message.text), align),
                self.geng.default_font().measure(&message.username, align),
            ) {
                y += full.height() * size + padding;

                self.geng.default_font().draw_with_outline(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &message.username,
                    align,
                    mat3::translate(vec2(x, y)) * mat3::scale_uniform(size),
                    message.user_color,
                    outline,
                    Rgba::BLACK,
                );
                self.geng.default_font().draw_with_outline(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &message.text,
                    align,
                    mat3::translate(vec2(x + uname.width() * size + padding, y))
                        * mat3::scale_uniform(size),
                    Rgba::WHITE,
                    outline,
                    Rgba::BLACK,
                );
            }
        }
    }

    fn update(&mut self, _delta_time: f64) {
        // * Twitch IRC
        if let Some(message) = self.runner.next_message().now_or_never() {
            match message {
                Ok(twitchchat::Status::Message(twitchchat::messages::Commands::Privmsg(pm))) => {
                    self.on_message(
                        pm.display_name().unwrap_or(pm.name()),
                        pm.color().map_or(Rgba::MAGENTA, |color| {
                            Rgba::opaque(
                                color.rgb.0 as f32 / 255.0,
                                color.rgb.1 as f32 / 255.0,
                                color.rgb.2 as f32 / 255.0,
                            )
                        }),
                        pm.data(),
                        Some(&pm),
                    )
                }
                Err(err) => log::error!("Failed to recieve a message: {}!", err),
                _ => (),
            }
        }

        // * Youtube IRC
        if let Ok(message) = self
            .youtube_reciever
            .recv_timeout(std::time::Duration::from_millis(10))
        {
            let mut msg = String::new();
            for item in message.message {
                match item {
                    youtube_chat::item::MessageItem::Text(text) => msg.push_str(&text),
                    youtube_chat::item::MessageItem::Emoji(emoji) => {
                        msg.push_str(&emoji.emoji_text.unwrap_or(String::new()))
                    }
                }
            }
            self.on_message(
                &message.author.name.unwrap_or("<anonymous>".to_owned()),
                Rgba::RED,
                &msg,
                None,
            );
        }

        // * Messages
        self.messages
            .retain(|message| message.timeout.elapsed() < std::time::Duration::from_secs(30));
    }

    fn fixed_update(&mut self, delta_time: f64) {
        self.world.update(delta_time, self.size.map(|x| x as _));
    }

    fn handle_event(&mut self, _event: geng::Event) {
        // if let geng::Event::KeyPress { key } = event {
        //     match key {
        //         geng::Key::ShiftRight => self.world.plushies.push(
        //             self.assets
        //                 .get()
        //                 .plushies
        //                 .ferris
        //                 .instance(vec2(10.0, self.size.y as f32 - 10.0), 0.7),
        //         ),
        //         _ => (),
        //     }
        // }
    }
}
