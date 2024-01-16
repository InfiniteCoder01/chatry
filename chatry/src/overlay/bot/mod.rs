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
                            "plushie" => {
                                let name = args.to_lowercase();
                                let scale = match name.as_str() {
                                    "ferris" => 1.0,
                                    "c" => 0.5,
                                    "c++" | "cpp" => 0.5,
                                    "nixos" => 0.5,
                                    "helix" => 1.0,
                                    "pinmode" => 1.0,
                                    "alan" => 0.4,
                                    "kuviman" => 0.4,
                                    "badcop" => 0.6,
                                    "programmer_jeff_" => 2.0,
                                    _ => 0.3,
                                };
                                if let Some(plushie) = self.assets.get().plushies.get(&name) {
                                    self.world.plushies.push(plushie.instance(
                                        name,
                                        vec2(10.0, self.size.y as f32 - 10.0),
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
