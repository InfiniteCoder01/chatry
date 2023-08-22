pub use anyhow::*;
pub use map_macro::*;
pub use rand::Rng;
pub use speedy2d::dimen::*;
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

#[derive(Clone, Debug)]
pub struct Point {
    pub position: Vec2,
    pub velocity: Vec2,
}

impl Point {
    pub fn new(position: Vec2, velocity: Vec2) -> Self {
        Self { position, velocity }
    }

    pub fn update(&mut self, delta_time: f32, borders: Vec2) {
        self.velocity.y += delta_time * 1000.0;

        let motion = self.velocity * delta_time;
        self.position += motion;

        if self.position.x < 0.0 || self.position.x > borders.x {
            self.position.x -= motion.x;
            self.velocity.x *= -1.0;
        }
        if self.position.y > borders.y {
            self.position.y -= motion.y;
            self.velocity.y *= -0.8;
        }
    }
}

pub struct Plushie {
    name: String,
    pub point: Point,
    pub squash_point: Option<Point>,
    pub scale: f32,
    pub squash: f32,
}

impl Plushie {
    pub fn new(name: &str, position: Vec2, scale: f32) -> Self {
        Self {
            name: name.to_owned(),
            point: Point::new(
                position,
                Vec2::new(rand::thread_rng().gen_range(-400.0..400.0), 0.0),
            ),
            squash_point: None,
            scale,
            squash: 1.0,
        }
    }

    pub fn update(&mut self, delta_time: f32, size: Vec2, screen_size: UVec2) {
        self.point.update(delta_time, screen_size.into_f32() - size);
        let target_squash_position = self.point.position - size * Vec2::new(0.0, 1.0);
        let squash_point = self
            .squash_point
            .get_or_insert(Point::new(target_squash_position, Vec2::ZERO));
        squash_point.update(delta_time, screen_size.into_f32() - size);
        squash_point.velocity += ((target_squash_position - squash_point.position) * 700.0
            + (self.point.velocity - squash_point.velocity) * 4.0)
            * delta_time;

        self.squash = ((self.point.position.y - squash_point.position.y) / size.y).clamp(0.1, 2.0);
    }

    pub fn name(&self) -> &String {
        &self.name
    }
}
