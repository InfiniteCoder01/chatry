use self::api::LiveChat;
use super::*;
use plushies::*;
use std::{
    collections::VecDeque,
    time::{Duration, Instant},
};

pub mod chatbot;
pub mod plushies;

#[derive(geng::asset::Load)]
pub struct Assets {
    pub plushies: Plushies,
    pub readchat: geng::Sound,
    #[load(path = "FiraMonoNerdFontMono-Regular.otf")]
    pub font: geng::Font,
}

pub struct State {
    geng: Geng,
    assets: Hot<Assets>,
    size: vec2<usize>,
    config: &'static Config,
    message_timeout: Duration,

    runtime: Rc<tokio::runtime::Runtime>,
    twitch_chat: Rc<RefCell<api::TwitchChat>>,
    twitch_streamer: api::TwitchChat,

    world: World,
    messages: Vec<api::MessageContent>,
    message: Option<String>,

    tty: Arc<Mutex<Vec<String>>>,
}

impl State {
    pub fn new(geng: &Geng, private: Private, config: Config, assets: Hot<Assets>) -> Self {
        let config = Box::leak(Box::new(config));
        let runtime = Rc::new(tokio::runtime::Runtime::new().unwrap());
        let mut twitch_chat = crate::api::TwitchChat::new(runtime.clone(), &private.token, config);
        let twitch_streamer =
            crate::api::TwitchChat::new(runtime.clone(), &private.streamer_token, config);
        twitch_chat.send(config.channels.first().unwrap(), "I'm online!");

        Self {
            geng: geng.clone(),
            assets,
            size: vec2(128, 128),

            runtime,
            twitch_chat: Rc::new(RefCell::new(twitch_chat)),
            twitch_streamer,

            config,
            message_timeout: Duration::from_secs(30),
            messages: Vec::new(),
            world: World::new(),
            message: None,

            tty: Arc::new(Mutex::new(Vec::new())),
        }
    }
}

impl geng::State for State {
    fn draw(&mut self, framebuffer: &mut ugli::Framebuffer) {
        ugli::clear(framebuffer, Some(Rgba::TRANSPARENT_BLACK), None, None);
        self.size = framebuffer.size();
        self.world.draw(&self, framebuffer);

        // * UI
        let spacing = 5.0;
        let panel_width = 600.0;
        let panel_x = framebuffer.size().x as f32 - panel_width - spacing;
        let text_size = 30.0;
        let outline = 2.0 / text_size;
        let border = 5.0;

        // * Chat
        {
            let spacing = 10.0;
            let mut y = framebuffer.size().y as f32 / 4.0 + spacing;
            for message in self.messages.iter().rev() {
                let align = vec2(geng::TextAlign::LEFT, geng::TextAlign::TOP);
                let uname_width = self
                    .assets
                    .get()
                    .font
                    .measure(&message.author, align)
                    .map_or(0.0, |rect| rect.width() * text_size);
                let wrapped_message = textwrap::fill(
                    &message.message,
                    ((panel_width - uname_width - spacing) / text_size * 1.8) as usize,
                );
                let message_rect = self
                    .assets
                    .get()
                    .font
                    .measure(&format!("{}: {}", message.author, wrapped_message), align)
                    .map_or(Aabb2::ZERO, |rect| rect.map(|point| point * text_size));
                let alpha = (self.message_timeout
                    - message.timeout.elapsed().min(self.message_timeout))
                .as_secs_f32()
                .min(1.0);

                y += message_rect.height() + spacing * 2.0;

                self.geng.draw2d().draw2d(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &draw2d::Polygon::new(
                        vec![
                            vec2(panel_x - border, y + message_rect.min.y - border),
                            vec2(
                                panel_x + panel_width - spacing + border,
                                y + message_rect.min.y - border,
                            ),
                            vec2(
                                panel_x + panel_width - spacing + border,
                                y + message_rect.max.y + border,
                            ),
                            vec2(panel_x - border, y + message_rect.max.y + border),
                        ],
                        Rgba::new(0.0, 0.0, 0.0, 0.4 * alpha),
                    ),
                );

                self.assets.get().font.draw_with_outline(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &message.author,
                    align,
                    mat3::translate(vec2(panel_x, y)) * mat3::scale_uniform(text_size),
                    Rgba::new(
                        message.author_color.r,
                        message.author_color.g,
                        message.author_color.b,
                        message.author_color.a * alpha,
                    ),
                    outline,
                    Rgba::new(0.0, 0.0, 0.0, alpha),
                );
                self.assets.get().font.draw_with_outline(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &wrapped_message,
                    align,
                    mat3::translate(vec2(panel_x + uname_width + spacing, y))
                        * mat3::scale_uniform(text_size),
                    Rgba::new(1.0, 1.0, 1.0, alpha),
                    outline,
                    Rgba::new(0.0, 0.0, 0.0, alpha),
                );
            }
        }

        // * Shell
        {
            let text_size = 20.0;
            let outline = 2.0 / text_size;
            let y = 40.0 + spacing;
            let align = vec2(geng::TextAlign::LEFT, geng::TextAlign::BOTTOM);

            let tty = self.tty.lock().unwrap().join("\n");
            if let Some(tty_rect) = self
                .assets
                .get()
                .font
                .measure(&tty, vec2(geng::TextAlign::LEFT, geng::TextAlign::BOTTOM))
                .map(|rect| rect.map(|point| point * text_size))
            {
                self.geng.draw2d().draw2d(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &draw2d::Polygon::new(
                        vec![
                            vec2(panel_x - border, y + tty_rect.min.y - border),
                            vec2(
                                panel_x + panel_width - spacing + border,
                                y + tty_rect.min.y - border,
                            ),
                            vec2(
                                panel_x + panel_width - spacing + border,
                                y + tty_rect.max.y + border,
                            ),
                            vec2(panel_x - border, y + tty_rect.max.y + border),
                        ],
                        Rgba::new(0.0, 0.0, 0.0, 0.4),
                    ),
                );
            }

            self.assets.get().font.draw_with_outline(
                framebuffer,
                &geng::PixelPerfectCamera,
                &tty,
                align,
                mat3::translate(vec2(panel_x, y)) * mat3::scale_uniform(text_size),
                Rgba::WHITE,
                outline,
                Rgba::BLACK,
            );
        }

        // * Typing a message
        if let Some(message) = &self.message {
            self.assets.get().font.draw_with_outline(
                framebuffer,
                &geng::Camera2d {
                    center: vec2(0.0, 0.0),
                    rotation: Angle::ZERO,
                    fov: 15.0,
                },
                &textwrap::fill(
                    &(message.to_owned() + "█"),
                    (framebuffer.size().x - panel_width as usize * 2) / 25,
                ),
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
        while let Some(message) = self.twitch_chat.clone().borrow_mut().next() {
            self.on_message(message);
        }
        while self.twitch_streamer.next().is_some() {}
        // if let Some(message) = self.runner.next_message().now_or_never() {
        //     match message {
        //         Ok(twitchchat::Status::Message(twitchchat::messages::Commands::Privmsg(pm))) => {
        //             self.on_message(
        //                 true,
        //                 pm.display_name().unwrap_or(pm.name()),
        //                 pm.color().map_or(Rgba::MAGENTA, |color| {
        //                     Rgba::opaque(
        //                         color.rgb.0 as f32 / 255.0,
        //                         color.rgb.1 as f32 / 255.0,
        //                         color.rgb.2 as f32 / 255.0,
        //                     )
        //                 }),
        //                 pm.data(),
        //                 Some(pm.channel()),
        //             )
        //         }
        //         Err(err) => log::error!("Failed to recieve a message: {}!", err),
        //         _ => (),
        //     }
        // }
        //
        // // * Youtube IRC
        // if let Ok(message) = self
        //     .youtube_reciever
        //     .recv_timeout(Duration::from_millis(10))
        // {
        //     let mut msg = String::new();
        //     for item in message.message {
        //         match item {
        //             youtube_chat::item::MessageItem::Text(text) => msg.push_str(&text),
        //             youtube_chat::item::MessageItem::Emoji(emoji) => {
        //                 msg.push_str(&emoji.emoji_text.unwrap_or(String::new()))
        //             }
        //         }
        //     }
        //     self.on_message(
        //         true,
        //         &message.author.name.unwrap_or("<anonymous>".to_owned()),
        //         Rgba::RED,
        //         &msg,
        //         None,
        //     );
        // }

        // * Messages
        self.messages
            .retain(|message| message.timeout.elapsed() < self.message_timeout);

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
                        self.twitch_streamer
                            .send(self.config.channels.first().unwrap(), &message);
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
