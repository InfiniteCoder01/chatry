use crate::config::*;
use std::time::{Duration, Instant};

pub fn on_message(
    config: &Config,
    state: &mut State,
    writer: &mut AsyncWriter<MpscWriter>,
    pm: Privmsg,
) -> Result<()> {
    let mut space = OVERLAY_SPACE.lock().unwrap();
    let msg = pm.data();
    let author = pm.name();
    let admin = config
        .admins
        .iter()
        .map(|admin| admin.to_lowercase())
        .any(|admin| admin == author.to_lowercase());

    if msg.contains("#WhenGC2") {
        writer.reply(&pm, "Submissions to One Lone Coder Code Jam 2023 are open from August 25th 2023 at 10:00 PM.")?;
    }

    if msg.starts_with('!') {
        for msg in msg.split(';') {
            let msg = msg.trim();
            if msg.starts_with('!') {
                let (cmd, args) = parse_args(msg);
                println!("[{}] {}", author, msg);

                // * Admin commands
                if admin {
                    match cmd.as_str() {
                        "!setwyd" => {
                            if let Some(wyd) = args.get(0) {
                                state.wyd = wyd.to_owned();
                                writer.say(&pm, &format!("Ok, we are now {}!", wyd))?
                            }
                        }
                        "!party" => {
                            state.party = true;
                            writer.say(&pm, "Spam plushies!!!")?;
                        }
                        "!noparty" => {
                            state.party = false;
                            writer.say(&pm, "Back to work!")?;
                        }
                        _ => (),
                    }
                }

                // * Normal commands
                if !state.party {
                    if let Some(cooldown) = state.cooldowns.get_mut(cmd.as_str()) {
                        if !cooldown.check(author) {
                            return Ok(());
                        }
                    }
                }
                match cmd.as_str() {
                    "!wyd" => writer.say(&pm, &format!("We are {}!", state.wyd))?,
                    "!qotd" => {
                        writer.say(&pm, &format!("The question of the day: {}", config.qotd))?
                    }
                    "!plushie" => {
                        if let Some(name) = args.get(0) {
                            let name = name.to_lowercase();
                            if [
                                "ferris", "c", "c++", "nixos", "manjaro", "vscode", "github",
                                "helix", "nvim", "bash", "twitch", "alan", "kuviman", "badcop", "programmer_jeff_",
                            ]
                            .contains(&name.as_str())
                            {
                                let scales = hash_map! {
                                    "ferris" => 1.0,
                                    "c" => 0.5,
                                    "c++" => 0.5,
                                    "nixos" => 0.5,
                                    "manjaro" => 0.3,
                                    "vscode" => 0.3,
                                    "github" => 0.3,
                                    "helix" => 1.0,
                                    "nvim" => 0.3,
                                    "bash" => 0.3,
                                    "twitch" => 0.3,
                                    "alan" => 0.4,
                                    "kuviman" => 2.0,
                                    "badcop" => 0.6,
                                    "programmer_jeff_" => 2.0,
                                };
                                space.plushies.push(crate::overlay::plushie::Plushie::new(
                                    &name,
                                    scales[name.as_str()],
                                ));
                                writer.say(&pm, &format!("{} joined the party!", name))?;
                            }
                        }
                    }
                    _ => (),
                }
            }
        }
    } else {
        space.chat.push(ChatMessage::new(
            pm.display_name().unwrap_or(pm.name()),
            msg,
            if admin {
                "#FF0000".parse()?
            } else {
                pm.color().unwrap_or_default()
            },
        ));
    }
    Ok(())
}

// * ------------------------------------- Utils ------------------------------------ * //
pub fn parse_args(msg: &str) -> (String, Vec<String>) {
    let mut args = vec!["".to_owned()];
    let mut quoted = false;
    for char in msg.chars() {
        if !quoted && char == ' ' {
            args.push("".to_owned());
            continue;
        }
        if char == '\"' {
            quoted = !quoted;
            continue;
        }
        args.last_mut().unwrap().push(char);
    }
    let cmd = args.remove(0);
    (cmd, args)
}

// * ------------------------------- Command Cooldown ------------------------------- * //
pub struct CommandCooldown {
    cooldown: Duration,
    user_cooldown: Duration,
    last: Option<Instant>,
    user_last: std::collections::HashMap<String, Instant>,
}

impl CommandCooldown {
    pub fn new(cooldown: Duration, user_cooldown: Duration) -> Self {
        Self {
            cooldown,
            user_cooldown,
            last: None,
            user_last: std::collections::HashMap::new(),
        }
    }

    pub fn check(&mut self, author: &str) -> bool {
        if let Some(last) = self.last {
            if last.elapsed() < self.cooldown {
                return false;
            }
        }
        if let Some(last) = self.user_last.get(author) {
            if last.elapsed() < self.user_cooldown {
                return false;
            }
        }
        self.last = Some(Instant::now());
        self.user_last.insert(author.to_owned(), Instant::now());
        true
    }
}

// * ------------------------------------- State ------------------------------------ * //
pub struct State {
    pub wyd: String,
    pub party: bool,

    pub cooldowns: std::collections::HashMap<&'static str, CommandCooldown>,
}

impl State {
    pub fn new() -> Self {
        Self {
            wyd: "not doing anything yet".to_owned(),
            party: false,
            cooldowns: hash_map! {
                "!wyd" => CommandCooldown::new(Duration::from_secs(10), Duration::from_secs(10)),
                "!qotd" => CommandCooldown::new(Duration::from_secs(10), Duration::from_secs(10)),
                "!plushie" => CommandCooldown::new(Duration::from_secs(3), Duration::from_secs(30)),
            },
        }
    }
}

impl Default for State {
    fn default() -> Self {
        Self::new()
    }
}
