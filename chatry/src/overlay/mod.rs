use geng::prelude::*;
use plushies::*;
use std::{
    collections::VecDeque,
    time::{Duration, Instant},
};
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
    pub timeout: Instant,
}

pub struct State {
    geng: Geng,
    assets: Hot<Assets>,
    size: vec2<usize>,
    config: Config,

    runner: AsyncRunner,
    writer: Writer,
    youtube_reciever: std::sync::mpsc::Receiver<youtube_chat::item::ChatItem>,
    runtime: tokio::runtime::Runtime,

    world: World,
    messages: Vec<Message>,
    message: Option<String>,
    plushie_queue: VecDeque<PlushieInstance>,
    plushie_release_timeout: Instant,

    tty: Arc<Mutex<Vec<String>>>,
}

impl State {
    pub fn new(
        geng: &Geng,
        config: Config,
        assets: Hot<Assets>,
        runner: AsyncRunner,
        writer: Writer,
        youtube_client: crate::youtube::YoutubeClient,
        youtube_reciever: crate::youtube::YoutubeReciever,
    ) -> Self {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let (mut youtube_client, youtube_initialized) = crate::youtube::init(youtube_client);
        if youtube_initialized {
            runtime.spawn(async move {
                let mut interval = tokio::time::interval(Duration::from_millis(500));
                loop {
                    interval.tick().await;
                    youtube_client.execute().await;
                }
            });
        }

        let mut state = Self {
            geng: geng.clone(),
            assets,
            size: vec2(128, 128),
            config,

            runner,
            writer,
            youtube_reciever,
            runtime,

            world: World::default(),
            messages: Vec::new(),
            message: None,
            plushie_queue: VecDeque::new(),
            plushie_release_timeout: Instant::now(),

            tty: Arc::new(Mutex::new(Vec::new())),
        };
        state.send_everywhere("I'm online!");
        state
    }

    pub fn send(&mut self, channel: &str, message: &str) {
        smol::block_on(async {
            if let Err(err) = self
                .writer
                .encode(twitchchat::commands::privmsg(channel, message))
                .await
            {
                log::error!("Failed to send a message: {}!", err);
            }
        });
    }

    pub fn send_everywhere(&mut self, message: &str) {
        smol::block_on(async {
            for channel in self.config.channels.clone() {
                self.send(&channel, message);
            }
        });
    }

    fn enqueue_plushie(&mut self, name: String) {
        if self.plushie_queue.len() > 30 {
            return;
        }
        if let Some(plushie) = self.assets.get().plushies.get(&name) {
            self.plushie_queue.push_back(PlushieInstance::new(
                name,
                vec2(
                    rand::thread_rng().gen_range(
                        10.0..self.size.x as f32
                            - plushie.image.size().x as f32 * plushie.config.scale
                            - 10.0,
                    ),
                    self.size.y as f32 + rand::thread_rng().gen_range(-10.0..30.0),
                ),
                vec2(rand::thread_rng().gen_range(-10.0..10.0), 0.0),
                plushie,
            ));
        }
    }
}

impl geng::State for State {
    fn draw(&mut self, framebuffer: &mut ugli::Framebuffer) {
        ugli::clear(framebuffer, Some(Rgba::TRANSPARENT_BLACK), None, None);
        self.size = framebuffer.size();
        self.world.draw(self, framebuffer);

        // * UI
        let padding = 5.0;
        let panel_width = 400.0;
        let panel_x = framebuffer.size().x as f32 - panel_width - padding;
        let text_size = 20.0;
        let outline = 2.0 / text_size;

        // * Chat
        {
            let message_padding = 10.0;
            let mut y = framebuffer.size().y as f32 / 4.0 + padding;
            for message in self.messages.iter().rev() {
                let align = vec2(geng::TextAlign::LEFT, geng::TextAlign::TOP);

                if let (Some(full), Some(uname)) = (
                    self.geng
                        .default_font()
                        .measure(&format!("{}: {}", message.username, message.text), align),
                    self.geng.default_font().measure(&message.username, align),
                ) {
                    y += full.height() * text_size + message_padding;

                    self.geng.default_font().draw_with_outline(
                        framebuffer,
                        &geng::PixelPerfectCamera,
                        &message.username,
                        align,
                        mat3::translate(vec2(panel_x, y)) * mat3::scale_uniform(text_size),
                        message.user_color,
                        outline,
                        Rgba::BLACK,
                    );
                    self.geng.default_font().draw_with_outline(
                        framebuffer,
                        &geng::PixelPerfectCamera,
                        &message.text,
                        align,
                        mat3::translate(vec2(panel_x + uname.width() * text_size + padding, y))
                            * mat3::scale_uniform(text_size),
                        Rgba::WHITE,
                        outline,
                        Rgba::BLACK,
                    );
                }
            }
        }

        // * Shell
        {
            let text_size = 20.0;
            let outline = 1.0 / text_size;
            let mut y = 40.0 + padding;
            for line in self.tty.lock().unwrap().iter().rev() {
                let align = vec2(geng::TextAlign::LEFT, geng::TextAlign::TOP);

                if let Some(line_size) = self.geng.default_font().measure(line, align) {
                    y += line_size.height() * text_size + padding;

                    self.geng.default_font().draw_with_outline(
                        framebuffer,
                        &geng::PixelPerfectCamera,
                        line,
                        align,
                        mat3::translate(vec2(panel_x, y)) * mat3::scale_uniform(text_size),
                        Rgba::WHITE,
                        outline,
                        Rgba::BLACK,
                    );
                }
            }
        }

        // * Typing a message
        if let Some(message) = &self.message {
            self.geng.default_font().draw_with_outline(
                framebuffer,
                &geng::Camera2d {
                    center: vec2(0.0, 0.0),
                    rotation: Angle::ZERO,
                    fov: 15.0,
                },
                &(message.to_owned() + "█"),
                vec2::splat(geng::TextAlign::CENTER),
                mat3::identity(),
                Rgba::WHITE,
                outline,
                Rgba::BLACK,
            );
        }
    }

    fn update(&mut self, _delta_time: f64) {
        // * Twitch IRC
        if let Some(message) = self.runner.next_message().now_or_never() {
            match message {
                Ok(twitchchat::Status::Message(twitchchat::messages::Commands::Privmsg(pm))) => {
                    self.on_message(
                        true,
                        pm.display_name().unwrap_or(pm.name()),
                        pm.color().map_or(Rgba::MAGENTA, |color| {
                            Rgba::opaque(
                                color.rgb.0 as f32 / 255.0,
                                color.rgb.1 as f32 / 255.0,
                                color.rgb.2 as f32 / 255.0,
                            )
                        }),
                        pm.data(),
                        Some(pm.channel()),
                    )
                }
                Err(err) => log::error!("Failed to recieve a message: {}!", err),
                _ => (),
            }
        }

        // * Youtube IRC
        if let Ok(message) = self
            .youtube_reciever
            .recv_timeout(Duration::from_millis(10))
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
                true,
                &message.author.name.unwrap_or("<anonymous>".to_owned()),
                Rgba::RED,
                &msg,
                None,
            );
        }

        // * Messages
        self.messages
            .retain(|message| message.timeout.elapsed() < Duration::from_secs(30));

        // * Plushie Queue
        if self.plushie_release_timeout.elapsed() > Duration::from_millis(500)
            && self.world.plushies.len() < 15
        {
            if let Some(mut plushie) = self.plushie_queue.pop_front() {
                plushie.time = Instant::now();
                self.world.plushies.push(plushie);
                self.plushie_release_timeout = Instant::now();
            }
        }

        // * Shell
        let mut tty = self.tty.lock().unwrap();
        let shell_lines = 10;
        let extra = tty.len().max(shell_lines) - shell_lines;
        tty.drain(0..extra);
    }

    fn fixed_update(&mut self, delta_time: f64) {
        self.world.update(delta_time, self.size.map(|x| x as _));
    }

    fn handle_event(&mut self, event: geng::Event) {
        if let Some(message) = &mut self.message {
            match event {
                geng::Event::EditText(text) => *message = text,
                geng::Event::KeyPress { key } => match key {
                    geng::Key::Enter => {
                        let message = self.message.take().unwrap();
                        self.send_everywhere(&message);
                        self.on_message(
                            true,
                            "Self",
                            Rgba::GRAY,
                            &message,
                            Some(&self.config.channels[0].clone()),
                        );
                    }
                    geng::Key::Escape => self.message = None,
                    _ => (),
                },
                geng::Event::Focused(false) => {
                    self.message = None;
                    self.geng.window().stop_text_edit();
                }
                _ => {}
            }
        } else if matches!(event, geng::Event::KeyPress { key: geng::Key::T }) {
            self.message = Some(String::new());
            self.geng.window().start_text_edit("");
        }
    }
}
