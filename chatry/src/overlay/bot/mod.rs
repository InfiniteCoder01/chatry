use super::*;

impl State {
    pub fn on_message(
        &mut self,
        display: bool,
        author: &str,
        color: Rgba<f32>,
        message: &str,
        channel: Option<&str>,
    ) {
        macro_rules! say {
            ($($arg:tt)*) => {
                if let Some(channel) = channel {
                    self.send(channel, &format!($($arg)*));
                }
            }
        }

        for part in message.split(';').map(str::trim) {
            if let Some(command) = part.strip_prefix('!') {
                let (command, args) = command.split_once(' ').unwrap_or((command, ""));
                match command {
                    "qotd" => {
                        say!("{}", self.config.qotd);
                    }
                    "readchat" => {
                        self.assets.get().readchat.play();
                    }
                    "plushie" => {
                        let name = if args.is_empty() {
                            self.assets.get().plushies.random()
                        } else {
                            args.to_lowercase()
                        };
                        if let Some(plushie) = self.assets.get().plushies.get(&name) {
                            self.world.plushies.push(world::PlushieInstance::new(
                                name,
                                vec2(
                                    rand::thread_rng().gen_range(
                                        10.0..self.size.x as f32
                                            - plushie.image.size().x as f32 * 1.0
                                            - 10.0,
                                    ),
                                    self.size.y as f32 - 10.0,
                                ),
                                vec2(rand::thread_rng().gen_range(-10.0..10.0), 0.0),
                                plushie,
                            ));
                        }
                    }
                    _ => (),
                }
            }
        }

        if display {
            self.messages.push(Message {
                username: author.to_owned(),
                user_color: color,
                text: message.to_owned(),
                timeout: std::time::Instant::now(),
            });
        }
    }
}
