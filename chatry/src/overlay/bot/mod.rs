use super::*;

pub mod shell;

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

        if let Some(cmd) = message.trim().strip_prefix("!sh") {
            self.shell_cmd(cmd);
            return;
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
                        self.enqueue_plushie(name);
                    }
                    "pick" => {
                        let name = if args.is_empty() {
                            self.assets
                                .get()
                                .plushies
                                .groups
                                .iter()
                                .choose(&mut rand::thread_rng())
                                .unwrap()
                                .0
                                .to_owned()
                        } else {
                            args.to_lowercase()
                        };
                        let assets = self.assets.get();
                        if let Some(group) = assets.plushies.groups.get(&name) {
                            let name = group.choose(&mut rand::thread_rng()).unwrap().to_owned();
                            drop(assets);
                            self.enqueue_plushie(name);
                        }
                    }
                    "distro" => {
                        let mut distro = Vec::new();
                        let assets = self.assets.get();
                        distro.extend_from_slice(&assets.plushies.pick_from_group("distros", 1));
                        if distro[0] != "nix" {
                            distro.extend_from_slice(&assets.plushies.pick_from_group(
                                "package-managers",
                                rand::thread_rng().gen_range(1..2),
                            ));
                        }
                        distro.extend_from_slice(&assets.plushies.pick_from_group("des", 1));
                        distro.extend_from_slice(&assets.plushies.pick_from_group("terminals", 1));
                        distro.extend_from_slice(&assets.plushies.pick_from_group("shells", 1));
                        distro.extend_from_slice(&assets.plushies.pick_from_group("editors", 1));
                        distro.extend_from_slice(
                            &assets.plushies.pick_from_group(
                                "applications",
                                rand::thread_rng().gen_range(0..2),
                            ),
                        );
                        drop(assets);
                        for item in distro {
                            self.enqueue_plushie(item);
                        }
                    }
                    "gamedev" => {
                        let mut stack = Vec::new();
                        let assets = self.assets.get();
                        stack.extend_from_slice(&assets.plushies.pick_from_group("editors", 1));
                        stack.extend_from_slice(&assets.plushies.pick_from_group("languages", 1));
                        stack.extend_from_slice(&assets.plushies.pick_from_group("graphics", 1));
                        drop(assets);
                        for item in stack {
                            self.enqueue_plushie(item);
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
                timeout: std::time::Instant::now() + std::time::Duration::from_secs(30),
            });
        }
    }
}
