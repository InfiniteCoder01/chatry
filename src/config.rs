pub use anyhow::*;
pub use map_macro::*;
pub use rand::Rng;
pub use serde::{Deserialize, Serialize};
pub use speedy2d::dimen::*;
pub use twitchchat::{
    messages::Privmsg,
    writer::{AsyncWriter, MpscWriter},
    PrivmsgExt,
};

use once_cell::sync::Lazy;

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub admins: Vec<String>,
    pub qotd: String,
}

pub static OVERLAY_SPACE: Lazy<std::sync::Mutex<OverlaySpace>> =
    Lazy::new(std::sync::Mutex::default);

#[derive(Default)]
pub struct OverlaySpace {
    pub plushies: Vec<crate::overlay::plushie::Plushie>,
    pub chat: Vec<ChatMessage>,
}

pub struct ChatMessage {
    author: String,
    content: String,
    author_color: speedy2d::color::Color,
    time: std::time::Instant,
}

impl ChatMessage {
    pub fn new(author: &str, content: &str, author_color: twitchchat::twitch::Color) -> Self {
        let author_color = speedy2d::color::Color::from_int_rgb(
            author_color.rgb.0,
            author_color.rgb.1,
            author_color.rgb.2,
        );

        Self {
            author: author.to_owned(),
            content: content.to_owned(),
            author_color,
            time: std::time::Instant::now(),
        }
    }

    pub fn author(&self) -> &str {
        &self.author
    }

    pub fn content(&self) -> &str {
        &self.content
    }

    pub fn author_color(&self) -> speedy2d::color::Color {
        self.author_color
    }

    pub fn since_sent(&self) -> u64 {
        self.time.elapsed().as_secs()
    }
}
