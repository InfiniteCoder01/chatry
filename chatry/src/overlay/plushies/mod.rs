use super::*;

pub mod world;
pub use world::{PlushieInstance, World};

#[derive(Debug)]
pub struct Plushies {
    pub plushies: HashMap<String, Rc<Plushie>>,
    pub groups: HashMap<String, Vec<String>>,
}

impl geng::asset::Load for Plushies {
    type Options = ();

    fn load(
        manager: &geng::asset::Manager,
        path: &std::path::Path,
        _options: &Self::Options,
    ) -> geng::asset::Future<Self> {
        let path = path.to_owned();
        let manager = manager.to_owned();
        async move {
            let mut plushies = HashMap::new();
            let mut groups = HashMap::<String, Vec<String>>::new();
            let files = std::fs::read_dir(path)
                .map_err(|err| anyhow!("Failed opening plushies directory: {err}"))?
                .flatten()
                .collect::<Vec<_>>();
            
            for (index, file) in files.iter().enumerate() {
                println!(
                    "Loading plushie '{}' ({}/{})",
                    file.file_name().to_string_lossy(),
                    index + 1,
                    files.len()
                );
                let plushie = manager.load::<Plushie>(file.path()).await?;
                let plushie = Rc::new(plushie);
                let name = file.file_name().to_string_lossy().into_owned();
                let mut names = plushie.config.aliases.clone();
                names.push(name.clone());
                for name in names {
                    if name.contains('-') {
                        plushies.insert(name.replace('-', "_"), plushie.clone());
                        plushies.insert(name.replace('-', " "), plushie.clone());
                        plushies.insert(name.replace('-', ""), plushie.clone());
                    }
                    plushies.insert(name, plushie.clone());
                }
                for group in &plushie.config.groups {
                    groups
                        .entry(group.to_owned())
                        .or_default()
                        .push(name.clone());
                }
            }

            println!("Available groups:");
            for (group, plushies) in &groups {
                println!("{}: {}", group, plushies.join(" "));
            }

            Ok(Self { plushies, groups })
        }
        .boxed_local()
    }

    const DEFAULT_EXT: Option<&'static str> = None;
}

impl Plushies {
    pub fn get(&self, name: &str) -> Option<&Rc<Plushie>> {
        self.plushies.get(name)
    }

    pub fn random(&self) -> String {
        self.plushies
            .iter()
            .choose(&mut rand::thread_rng())
            .unwrap()
            .0
            .to_owned()
    }

    pub fn pick_from_group(&self, group: &str, amount: usize) -> Vec<String> {
        self.groups[group]
            .choose_multiple(&mut rand::thread_rng(), amount)
            .cloned()
            .collect()
    }
}

// * ------------------------------- Single - Resource ------------------------------ * //
pub struct Plushie {
    pub image: ugli::Texture,
    pub structure: PlushieStructure,
    pub config: PlushieConfig,
}

impl Debug for Plushie {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Plushie")
            .field("structure", &self.structure)
            .field("config", &self.config)
            .finish()
    }
}

impl geng::asset::Load for Plushie {
    type Options = ();

    fn load(
        manager: &geng::asset::Manager,
        path: &std::path::Path,
        _options: &Self::Options,
    ) -> geng::asset::Future<Self> {
        let path = path.to_owned();
        let manager = manager.to_owned();
        async move {
            Ok(Self {
                image: manager.load(path.join("image.png")).await?,
                structure: ron::from_str(&file::load_string(path.join("structure.ron")).await?)
                    .map_err(|err| anyhow!("failed to load plushie structure: {err}"))?,
                config: file::load_string(&path.join("config.toml"))
                    .await
                    .map_or_else(
                        |_| Ok(default()),
                        |file| {
                            toml::from_str(&file)
                                .map_err(|err| anyhow!("failed to load plushie structure: {err}"))
                        },
                    )?,
            })
        }
        .boxed_local()
    }

    const DEFAULT_EXT: Option<&'static str> = None;
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PlushieStructure {
    points: Vec<vec2<i32>>,
    triangles: Vec<[usize; 3]>,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct PlushieConfig {
    #[serde(default = "default_scale")]
    pub scale: f32,
    #[serde(default = "Vec::new")]
    pub aliases: Vec<String>,
    #[serde(default = "Vec::new")]
    pub groups: Vec<String>,
}

fn default() -> PlushieConfig {
    PlushieConfig {
        scale: default_scale(),
        aliases: Vec::new(),
        groups: Vec::new(),
    }
}

fn default_scale() -> f32 {
    0.3
}
