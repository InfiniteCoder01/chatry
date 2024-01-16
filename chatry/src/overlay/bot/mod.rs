use super::*;
use twitchchat::{PrivmsgExt, Status};

impl State {
    pub fn on_message(&mut self, message: Status) {
        match message {
            Status::Message(twitchchat::messages::Commands::Privmsg(pm)) => {
                macro_rules! say {
                    ($($arg:tt)*) => {
                        if let Err(err) = self.writer.say(&pm, &format!($($arg)*)) {
                            log::error!("Failed to send a message: {}!", err);
                        }
                    }
                }

                for part in pm.data().split(';').map(str::trim) {
                    if let Some(command) = part.strip_prefix('!') {
                        let (command, args) = command.split_once(' ').unwrap_or((command, ""));
                        match command {
                            "qotd" => {
                                say!("{}", self.config.qotd);
                            }
                            "plushy" => {
                                let name = args.to_lowercase();
                                let scale = match name.as_str() {
                                    "ferris" => 0.5,
                                    "c" => 0.25,
                                    "c++" | "cpp" => 0.25,
                                    "nixos" => 0.25,
                                    "helix" => 0.5,
                                    "pinmode" => 0.5,
                                    "alan" => 0.2,
                                    "kuviman" => 0.2,
                                    "badcop" => 0.3,
                                    "programmer_jeff_" | "programmer_jeff" | "programmerjeff" => {
                                        1.0
                                    }
                                    _ => 0.15,
                                };
                                if let Some(plushy) = self.assets.get().plushys.get(&name) {
                                    self.world.plushys.push(plushy.instance(
                                        name,
                                        vec2(
                                            rand::thread_rng().gen_range(
                                                10.0..self.size.x as f32
                                                    - plushy.image.size().x as f32 * scale
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
                    username: pm.display_name().unwrap_or(pm.name()).to_owned(),
                    user_color: pm.color().map_or(Rgba::MAGENTA, |color| {
                        Rgba::opaque(
                            color.rgb.0 as f32 / 255.0,
                            color.rgb.1 as f32 / 255.0,
                            color.rgb.2 as f32 / 255.0,
                        )
                    }),
                    text: pm.data().to_owned(),
                    timeout: std::time::Instant::now(),
                })
            }
            Status::Quit | Status::Eof => log::info!("Disconnected from Twitch!"),
            Status::Message(..) => (),
        }
    }
}
