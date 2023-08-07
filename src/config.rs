pub use crate::math::*;
pub use anyhow::*;
pub use rand::Rng;
pub use twitchchat::{
    messages::Privmsg,
    writer::{AsyncWriter, MpscWriter},
    PrivmsgExt,
};

use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub admins: Vec<String>,
    pub qotd: String,
}

pub static OVERLAY_SPACE: Lazy<std::sync::Mutex<OverlaySpace>> =
    Lazy::new(std::sync::Mutex::default);

#[derive(Default)]
pub struct OverlaySpace {
    pub plushies: Vec<Plushie>,
    pub chat: Vec<ChatMessage>,
}

pub struct ChatMessage {
    author: String,
    content: String,
    username_color: [f32; 4],
    time: std::time::Instant,
}

impl ChatMessage {
    pub fn new(author: &str, content: &str, username_color: twitchchat::twitch::Color) -> Self {
        let username_color = [
            username_color.rgb.0 as f32 / 255.0,
            username_color.rgb.1 as f32 / 255.0,
            username_color.rgb.2 as f32 / 255.0,
            1.0,
        ];

        Self {
            author: author.to_owned(),
            content: content.to_owned(),
            username_color,
            time: std::time::Instant::now(),
        }
    }

    pub fn author(&self) -> &str {
        &self.author
    }

    pub fn content(&self) -> &str {
        &self.content
    }

    pub fn username_color(&self) -> [f32; 4] {
        self.username_color
    }

    pub fn since_sent(&self) -> u64 {
        self.time.elapsed().as_secs()
    }
}

pub struct Plushie {
    name: String,
    pub position: Vec2<f32>,
    pub velocity: Vec2<f32>,
}

impl Plushie {
    pub fn new(name: &str, position: impl Into<Vec2<f32>>) -> Self {
        Self {
            name: name.to_owned(),
            position: position.into(),
            velocity: Vec2::new(400.0, 0.0),
        }
    }

    pub fn name(&self) -> &String {
        &self.name
    }
}
