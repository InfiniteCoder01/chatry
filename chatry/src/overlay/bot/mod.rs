use super::*;
use twitchchat::PrivmsgExt;

impl State {
    pub fn on_message(
        &mut self,
        author: &str,
        color: Rgba<f32>,
        message: &str,
        pm: Option<&twitchchat::messages::Privmsg>,
    ) {
        macro_rules! say {
            ($($arg:tt)*) => {
                if let Some(pm) = pm {
                    if let Err(err) = self.writer.say(&pm, &format!($($arg)*)) {
                        log::error!("Failed to send a message: {}!", err);
                    }
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
                        let scale = match name.as_str() {
                            "asm" | "assembly" => 0.5,
                            "gnu" => 0.4,
                            "ferris" | "rust" | "borrowchecker" => 0.5,
                            "helix" => 0.5,
                            "pinmode" => 0.5,
                            "alan" => 0.2,
                            "kuviman" => 0.2,
                            "badcop" => 0.3,
                            "jonkero" => 0.4,
                            "programmer_jeff_" | "programmer_jeff" | "programmerjeff" => 1.0,
                            _ => 0.25,
                        };
                        if let Some(plushie) = self.assets.get().plushies.get(&name) {
                            self.world.plushies.push(plushie.instance(
                                name,
                                vec2(
                                    rand::thread_rng().gen_range(
                                        10.0..self.size.x as f32
                                            - plushie.image.size().x as f32 * scale
                                            - 10.0,
                                    ),
                                    self.size.y as f32 - 10.0,
                                ),
                                vec2(rand::thread_rng().gen_range(-10.0..10.0), 0.0),
                                scale,
                            ));
                        }
                    }
                    _ => (),
                }
            }
        }

        self.messages.push(Message {
            username: author.to_owned(),
            user_color: color,
            text: message.to_owned(),
            timeout: std::time::Instant::now(),
        })
    }
}
