use super::*;

pub mod world;
pub use world::World;

pub struct Plushies {
    pub plushies: HashMap<String, Rc<Plushie>>,
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
            for file in std::fs::read_dir(path)
                .map_err(|err| anyhow!("Failed opening plushies directory: {err}"))?
                .flatten()
            {
                let plushie = manager.load::<Plushie>(file.path()).await?;
                plushies.insert(
                    file.file_name().to_string_lossy().into_owned(),
                    Rc::new(plushie),
                );
            }
            Ok(Self { plushies })
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
}

// * ------------------------------- Single - Resource ------------------------------ * //
#[derive(geng::asset::Load)]
pub struct Plushie {
    pub image: ugli::Texture,
    pub structure: PlushieStructure,
    // pub config: Option<PlushieConfig>,
}

#[derive(Serialize, Deserialize)]
pub struct PlushieStructure {
    points: Vec<vec2<i32>>,
    triangles: Vec<[usize; 3]>,
}

impl geng::asset::Load for PlushieStructure {
    type Options = ();
    fn load(
        _manager: &geng::asset::Manager,
        path: &std::path::Path,
        _options: &Self::Options,
    ) -> geng::asset::Future<Self> {
        let path = path.to_owned();
        async move {
            ron::from_str(&file::load_string(&path).await?)
                .map_err(|err| anyhow!("failed to load plushie structure: {err}"))
        }
        .boxed_local()
    }

    const DEFAULT_EXT: Option<&'static str> = Some("ron");
}

#[derive(Serialize, Deserialize)]
pub struct PlushieConfig {}

impl geng::asset::Load for PlushieConfig {
    type Options = ();
    fn load(
        _manager: &geng::asset::Manager,
        path: &std::path::Path,
        _options: &Self::Options,
    ) -> geng::asset::Future<Self> {
        let path = path.to_owned();
        async move {
            toml::from_str(&file::load_string(&path).await?)
                .map_err(|err| anyhow!("failed to load plushie structure: {err}"))
        }
        .boxed_local()
    }

    const DEFAULT_EXT: Option<&'static str> = Some("toml");
}
