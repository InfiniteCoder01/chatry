use map_macro::hash_map;

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

    if msg.starts_with('!') {
        let (cmd, args) = parse_args(msg);
        println!("[{}] {}", author, msg);

        // * Admin commands
        if admin {
            match cmd.as_str() {
                "!setwyd" => {
                    if let Some(wyd) = args.get(0) {
                        state.wyd = wyd.to_owned();
                        writer.say(
                            &pm,
                            &format!("Ok, we are now {}! Type !progress for progress!", wyd),
                        )?
                    }
                }
                "!setprogress" => {
                    if let Some(progress) = args.get(0) {
                        state.progress = progress.to_owned();
                        writer.say(&pm, &format!("Ok, we are now at '{}'!", progress))?
                    }
                }
                "!setstate" => {
                    if let (Some(wyd), Some(progress)) = (args.get(0), args.get(1)) {
                        state.wyd = wyd.to_owned();
                        state.progress = progress.to_owned();
                        writer.say(&pm, &format!("Ok, we are now {} at '{}'!", wyd, progress))?
                    }
                }
                "!party" => {
                    state.party = true;
                    writer.say(&pm, "Let's spam!!!")?;
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
            "!progress" => writer.say(&pm, &format!("We are at '{}'!", state.progress))?,
            "!qotd" => writer.say(&pm, &format!("The question of the day: {}", config.qotd))?,
            "!ferris" => {
                space.plushies.push(Plushie::new(
                    "Ferris",
                    Vec2::new(rand::thread_rng().gen_range(0..1920 - 230), 1080),
                ));
                writer.say(&pm, "Ferris joined the party!")?;
            }
            _ => (),
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
    pub progress: String,
    pub party: bool,

    pub cooldowns: std::collections::HashMap<&'static str, CommandCooldown>,
}

impl State {
    pub fn new() -> Self {
        Self {
            wyd: "not doing anything yet".to_owned(),
            progress: "choosing what to do".to_owned(),
            party: false,
            cooldowns: hash_map! {
                "!wyd" => CommandCooldown::new(Duration::from_secs(10), Duration::from_secs(10)),
                "!progress" => CommandCooldown::new(Duration::from_secs(10), Duration::from_secs(10)),
                "!qotd" => CommandCooldown::new(Duration::from_secs(10), Duration::from_secs(10)),
                "!ferris" => CommandCooldown::new(Duration::from_secs(3), Duration::from_secs(30)),
            },
        }
    }
}

impl Default for State {
    fn default() -> Self {
        Self::new()
    }
}
