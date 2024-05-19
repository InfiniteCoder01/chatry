use super::*;

pub mod orco;

impl State {
    pub fn on_message(&mut self, mut message: api::Message) {
        if let Some(cmd) = message.content.message.trim().strip_prefix("!orco") {
            self.compile_and_run(cmd);
            return;
        }

        for part in message.content.message.to_owned().split(';').map(str::trim) {
            if let Some(command) = part.strip_prefix('!') {
                let (command, args) = command.split_once(' ').unwrap_or((command, ""));
                match command {
                    "qotd" => {
                        message.reply(&self.config.qotd);
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
                            self.world
                                .enqueue_plushie(self.size.map(|x| x as _), plushie.clone());
                        }
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
                            if let Some(plushie) = assets.plushies.get(&name) {
                                self.world
                                    .enqueue_plushie(self.size.map(|x| x as _), plushie.clone());
                            }
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
                        for item in distro {
                            if let Some(plushie) = assets.plushies.get(&item) {
                                self.world
                                    .enqueue_plushie(self.size.map(|x| x as _), plushie.clone());
                            }
                        }
                    }
                    "gamedev" => {
                        let mut stack = Vec::new();
                        let assets = self.assets.get();
                        stack.extend_from_slice(&assets.plushies.pick_from_group("editors", 1));
                        stack.extend_from_slice(&assets.plushies.pick_from_group("languages", 1));
                        stack.extend_from_slice(&assets.plushies.pick_from_group("graphics", 1));
                        for item in stack {
                            if let Some(plushie) = assets.plushies.get(&item) {
                                self.world
                                    .enqueue_plushie(self.size.map(|x| x as _), plushie.clone());
                            }
                        }
                    }
                    _ => (),
                }
            }
        }

        self.messages.push(message.content);
    }
}
