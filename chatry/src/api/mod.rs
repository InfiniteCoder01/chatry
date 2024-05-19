use super::*;
use std::time::Instant;

pub mod twitch;
pub use twitch::TwitchChat;

pub trait LiveChat {
    fn send(&mut self, channel: &str, message: &str);
    fn reply(&mut self, channel: &str, to_id: &str, author: &str, message: &str);
    fn next(&mut self) -> Option<Message>;
}

pub struct MessageContent {
    pub id: Option<String>,
    pub channel_id: String,
    pub author: String,
    pub author_color: Rgba<f32>,
    pub message: String,
    pub timeout: Instant,
}

impl MessageContent {
    pub fn new(
        id: Option<String>,
        channel_id: String,
        author: String,
        author_color: Rgba<f32>,
        message: String,
    ) -> Self {
        Self {
            id,
            channel_id,
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
            channel.reply(&self.content.channel_id, id, &self.content.author, message);
        }
    }
}

// impl LiveChat for () {
//     fn send(&mut self, channel: &str, message: &str) {
//         todo!()
//     }
//
//     fn reply(&mut self, channel: &str, to_id: &str, message: &str) {
//         todo!()
//     }
//
//     fn next(&mut self) -> Option<Message> {
//         todo!()
//     }
// }
