use super::*;
use std::time::Instant;

pub mod twitch;
pub use twitch::TwitchChat;
pub mod youtube;
pub use youtube::YouTubeChat;

pub trait LiveChat {
    fn send(&mut self, stream_id: &str, message: &str);
    fn reply(&mut self, stream_id: &str, to_id: &str, author: &str, message: &str);
    fn next(&mut self) -> Option<Message>;
}

pub struct MessageContent {
    pub id: Option<String>,
    pub stream_id: String,
    pub author: String,
    pub author_color: Rgba<f32>,
    pub message: String,
    pub timeout: Instant,
}

impl MessageContent {
    pub fn new(
        id: Option<String>,
        stream_id: String,
        author: String,
        author_color: Rgba<f32>,
        message: String,
    ) -> Self {
        Self {
            id,
            stream_id,
            author,
            author_color,
            message,
            timeout: Instant::now(),
        }
    }
}

pub struct Message<'a> {
    pub channel: Option<&'a mut dyn LiveChat>,
    pub content: MessageContent,
}

impl Message<'_> {
    pub fn reply(&mut self, message: &str) {
        if let (Some(channel), Some(id)) = (&mut self.channel, &self.content.id) {
            channel.reply(&self.content.stream_id, id, &self.content.author, message);
        }
    }
}

