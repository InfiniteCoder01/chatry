use super::*;
use geng::prelude::future::FutureExt;

pub struct TwitchChat {
    runtime: Arc<tokio::runtime::Runtime>,
    config: &'static Config,
    pub client: tmi::Client,
    queue: std::collections::VecDeque<api::MessageContent>,
}

impl TwitchChat {
    pub fn new(runtime: Arc<tokio::runtime::Runtime>, token: &str, config: &'static Config) -> Self {
        let client = runtime.block_on(async {
            let mut client = tmi::Client::builder()
                .credentials(tmi::Credentials::new(&config.name, token))
                .connect()
                .await
                .expect("Failed to connect to twitch IRC");
            client
                .join_all(&config.channels)
                .await
                .expect("Could not join all the channels!");
            client
        });
        Self {
            runtime,
            config,
            client,
            queue: std::collections::VecDeque::new(),
        }
    }
}

impl LiveChat for TwitchChat {
    fn send(&mut self, stream_id: &str, message: &str) {
        self.runtime.block_on(async {
            if let Err(err) = self.client.privmsg(stream_id, message).send().await {
                log::error!("Failed to send message: {}", err);
            }
        });
        self.queue.push_back(api::MessageContent::new(
            None,
            stream_id.to_string(),
            self.config.name.clone(),
            Rgba::opaque(0.5, 0.0, 0.0),
            message.to_owned(),
        ));
    }

    fn reply(&mut self, stream_id: &str, to_id: &str, author: &str, message: &str) {
        self.runtime.block_on(async {
            if let Err(err) = self
                .client
                .privmsg(stream_id, message)
                .reply_to(to_id)
                .send()
                .await
            {
                log::error!("Failed to send reply: {}", err);
            }
        });
        self.queue.push_back(api::MessageContent::new(
            None,
            stream_id.to_string(),
            self.config.name.clone(),
            Rgba::opaque(0.5, 0.0, 0.0),
            format!("@{} {}", author, message),
        ));
    }

    fn next(&mut self) -> Option<Message> {
        if let Some(msg) = self.queue.pop_front() {
            return Some(Message {
                channel: Some(self),
                content: msg,
            });
        }
        self.runtime.clone().block_on(async {
            let msg = match self.client.recv().now_or_never() {
                Some(Ok(msg)) => msg,
                Some(Err(err)) => {
                    log::error!("Failed to receive message: {}", err);
                    return None;
                }
                None => return None,
            };
            let msg = match msg.as_typed() {
                Ok(msg) => msg,
                Err(err) => {
                    log::error!("Failed to parse message: {}", err);
                    return None;
                }
            };
            match msg {
                tmi::Message::Privmsg(msg) => Some(Message {
                    channel: Some(self),
                    content: MessageContent::new(
                        Some(msg.message_id().to_owned()),
                        msg.channel().to_owned(),
                        msg.sender().name().into_owned(),
                        msg.color()
                            .and_then(|color| Rgba::try_from(color).ok())
                            .unwrap_or(Rgba::GRAY),
                        msg.text().replace('\u{e0000}', ""),
                    ),
                }),
                tmi::Message::Reconnect => {
                    if let Err(err) = self.client.reconnect().await {
                        log::error!("Failed to reconnect: {}", err);
                    }
                    if let Err(err) = self.client.join_all(&self.config.channels).await {
                        log::error!("Failed to rejoin all channels: {}", err);
                    }
                    None
                }
                tmi::Message::Ping(ping) => {
                    if let Err(err) = self.client.pong(&ping).await {
                        log::error!("Failed to pong: {}", err);
                    }
                    None
                }
                _ => None,
            }
        })
    }
}
