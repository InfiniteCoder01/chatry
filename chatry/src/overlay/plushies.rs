use geng::prelude::{itertools::Itertools, *};

#[derive(geng::asset::Load)]
pub struct Plushies {
    pub alan: Plushie,
    pub arch: Plushie,
    pub aseprite: Plushie,
    pub asm: Plushie,
    pub badcop: Plushie,
    pub bash: Plushie,
    pub c: Plushie,
    pub cpp: Plushie,
    pub csharp: Plushie,
    pub cheburashka: Plushie,
    pub emacs: Plushie,
    pub ferris: Plushie,
    pub freebsd: Plushie,
    pub github: Plushie,
    pub gnu: Plushie,
    pub guix: Plushie,
    pub helix: Plushie,
    pub infinite: Plushie,
    pub java: Plushie,
    pub jonkero: Plushie,
    pub kuviman: Plushie,
    pub linux: Plushie,
    pub lvim: Plushie,
    pub manjaro: Plushie,
    pub nano: Plushie,
    pub nixos: Plushie,
    pub nvim: Plushie,
    pub pinmode: Plushie,
    pub programmer_jeff: Plushie,
    pub tree_sitter: Plushie,
    pub twitch: Plushie,
    pub vim: Plushie,
    pub vscode: Plushie,
}

impl Plushies {
    pub fn get(&self, name: &str) -> Option<&Plushie> {
        match name {
            "alan" => Some(&self.alan),
            "arch" | "archlinux" | "archlinux.org" => Some(&self.arch),
            "aseprite" | "pixel" => Some(&self.aseprite),
            "asm" | "assembly" => Some(&self.asm),
            "badcop" => Some(&self.badcop),
            "bash" => Some(&self.bash),
            "c" => Some(&self.c),
            "c++" | "cpp" => Some(&self.cpp),
            "c#" | "csharp" => Some(&self.csharp),
            "cheburashka" => Some(&self.cheburashka),
            "emacs" => Some(&self.emacs),
            "ferris" | "rust" | "borrowchecker" => Some(&self.ferris),
            "freebsd" => Some(&self.freebsd),
            "github" => Some(&self.github),
            "gnu" => Some(&self.gnu),
            "guix" => Some(&self.guix),
            "helix" => Some(&self.helix),
            "infinite" => Some(&self.infinite),
            "java" => Some(&self.java),
            "jonkero" => Some(&self.jonkero),
            "kuviman" => Some(&self.kuviman),
            "linux" | "tux" | "penguin" => Some(&self.linux),
            "lvim" | "lunarvim" => Some(&self.lvim),
            "manjaro" => Some(&self.manjaro),
            "nano" => Some(&self.nano),
            "nixos" => Some(&self.nixos),
            "nvim" | "neovim" => Some(&self.nvim),
            "pinmode" => Some(&self.pinmode),
            "programmer_jeff_" | "programmer_jeff" | "programmerjeff" => {
                Some(&self.programmer_jeff)
            }
            "tree_sitter" | "tree-sitter" | "treesitter" => Some(&self.tree_sitter),
            "twitch" => Some(&self.twitch),
            "vim" => Some(&self.vim),
            "vscode" => Some(&self.vscode),
            _ => None,
        }
    }

    pub fn random(&self) -> String {
        let plushies = [
            "alan",
            "arch",
            "aseprite",
            "asm",
            "badcop",
            "bash",
            "c",
            "c++",
            "c#",
            "cheburashka",
            "emacs",
            "ferris",
            "freebsd",
            "github",
            "gnu",
            "guix",
            "helix",
            "infinite",
            "java",
            "jonkero",
            "kuviman",
            "linux",
            "lvim",
            "manjaro",
            "nano",
            "nixos",
            "nvim",
            "pinmode",
            "programmer_jeff_",
            "tree_sitter",
            "twitch",
            "vim",
            "vscode",
        ];
        plushies
            .choose(&mut rand::thread_rng())
            .unwrap()
            .to_owned()
            .to_owned()
    }
}

// * ------------------------------- Single - Resource ------------------------------ * //
#[derive(geng::asset::Load)]
pub struct Plushie {
    pub image: ugli::Texture,
    pub structure: PlushieStructure,
}

impl Plushie {
    pub fn instance(
        &self,
        name: String,
        pos: vec2<f32>,
        vel: vec2<f32>,
        scale: f32,
    ) -> PlushieInstance {
        let nalg_points = self
            .structure
            .points
            .iter()
            .map(|point| {
                let point = point.map(|x| x as f32) * scale;
                nalgebra::Point2::new(point.x, point.y)
            })
            .collect::<Vec<_>>();
        let mut tri =
            baby_shark::triangulation::constrained_delaunay::ConstrainedTriangulation2::from_points(
                &nalg_points[..],
            );
        for index in 0..nalg_points.len() {
            tri.insert_constrained_edge(index, (index + 1) % nalg_points.len());
        }

        let mut instance = PlushieInstance::new(
            name,
            self.structure
                .points
                .iter()
                .map(|point| {
                    let uv = point.map(|x| x as f32) / self.image.size().map(|x| x as f32);
                    Particle::new(
                        vec2(
                            pos.x + point.x as f32 * scale,
                            pos.y - point.y as f32 * scale,
                        ),
                        vel,
                        vec2(uv.x, 1.0 - uv.y),
                    )
                })
                .collect::<Vec<_>>(),
            self.structure
                .points
                .iter()
                .map(|point| point.map(|x| x as f32) * scale * vec2(1.0, -1.0))
                .collect::<Vec<_>>(),
        );

        for triangle in tri.triangles().chunks_exact(3) {
            instance.triangles.push(triangle.try_into().unwrap())
        }

        instance
    }
}

#[derive(Serialize, Deserialize)]
pub struct PlushieStructure {
    points: Vec<vec2<i32>>,
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

fn _pixelate(plushie: &mut Plushie) {
    plushie.image.set_filter(ugli::Filter::Nearest);
}

// * ------------------------------- Single - Physics ------------------------------- * //
pub struct Particle {
    pub pos: vec2<f32>,
    pub vel: vec2<f32>,
    pub acc: vec2<f32>,
    pub uv: vec2<f32>,
}

impl Particle {
    pub fn new(pos: vec2<f32>, vel: vec2<f32>, uv: vec2<f32>) -> Self {
        Self {
            pos,
            vel,
            acc: vec2(0.0, 0.0),
            uv,
        }
    }

    pub fn update(
        &mut self,
        index: usize,
        dt: f64,
        bounds: vec2<f32>,
        colliders: &[(usize, Aabb2<f32>)],
    ) -> bool {
        for (collider_index, collider) in colliders {
            if index == *collider_index {
                continue;
            }
            if collider.contains(self.pos) {
                let directions = [
                    vec2(1.0_f32, 0.0),
                    vec2(-1.0, 0.0),
                    vec2(0.0, 1.0),
                    vec2(0.0, -1.0),
                ];
                let mut best = (directions[0], 1000.0);
                for direction in &directions {
                    let size_mask = direction.map(|x| x.max(0.0));
                    let mask = direction.map(f32::abs);
                    let distance = collider.min + collider.size() * size_mask - self.pos;
                    let distance = (distance * mask).iter().map(|x| x.abs()).sum();
                    if distance < best.1 {
                        best = (*direction, distance);
                    }
                }
                self.spring(best.0 * best.1 * 1.5);
                if best.1 > 50.0 {
                    return false;
                }
            }
        }

        self.acc += vec2(0.0, -1500.0);
        self.vel += self.acc * dt as f32;

        let motion = self.vel * dt as f32;
        self.pos += motion;

        if self.pos.x < 0.0 || self.pos.x > bounds.x {
            self.pos.x = if self.pos.x < 0.0 { 0.0 } else { bounds.x };
            self.vel.x = 0.0;
            self.vel.y *= 0.99;
        }

        if self.pos.y < 0.0 {
            self.pos.y = 0.0;
            self.vel.y *= -0.8;
            self.vel.x *= 0.99;
        }

        self.acc = vec2(0.0, 0.0);
        true
    }

    pub fn add_force(&mut self, force: vec2<f32>) {
        self.acc += force;
    }

    pub fn spring(&mut self, delta: vec2<f32>) {
        let spring_k = 5000.0;
        let damp_k = 1.1;
        let force = delta.map(|x| x.abs().powf(1.0 / 3.0) * x.signum());
        let force = force * spring_k - self.vel * damp_k;
        self.add_force(force);
    }
}

pub struct PlushieInstance {
    pub name: String,
    pub time: std::time::Instant,
    pub alive: bool,
    pub particles: Vec<Particle>,
    pub shape: Vec<vec2<f32>>,
    pub triangles: Vec<[usize; 3]>,
}

impl PlushieInstance {
    pub fn new(name: String, particles: Vec<Particle>, shape: Vec<vec2<f32>>) -> Self {
        Self {
            name,
            time: std::time::Instant::now(),
            alive: true,
            particles,
            shape,
            triangles: Vec::new(),
        }
    }

    pub fn update(
        &mut self,
        index: usize,
        dt: f64,
        bounds: vec2<f32>,
        colliders: &[(usize, Aabb2<f32>)],
    ) {
        for particle in &mut self.particles {
            if !particle.update(index, dt, bounds, colliders) {
                self.alive = false;
            }
        }

        for triangle in self.triangles.iter().sorted_by_key(|triangle| {
            (-triangle
                .iter()
                .map(|&index| self.particles[index].pos.y)
                .sum::<f32>()
                * 100.0) as i32
        }) {
            let shape = triangle.map(|index| self.shape[index]);

            let mut shape_center = vec2(0.0, 0.0);
            for &point in &shape {
                shape_center += point;
            }
            shape_center /= shape.len() as f32;

            let shape = shape.map(|point| point - shape_center);

            // Source: https://lisyarus.github.io/blog/physics/2023/05/10/soft-body-physics.html
            // Compute the center of mass
            let mut center = vec2(0.0, 0.0);
            for &index in triangle {
                center += self.particles[index].pos;
            }
            center /= triangle.len() as f32;

            // Compute the shape rotation angle
            let mut dot = 0.0;
            let mut cross = 0.0;
            for (&index, &point) in std::iter::zip(triangle, &shape) {
                let r = self.particles[index].pos - center;
                dot += vec2::dot(r, point);
                cross += vec2::skew(r, point);
            }
            let angle = -cross.atan2(dot);

            // Apply spring forces
            for (&index, &point) in std::iter::zip(triangle, &shape) {
                let target = center + point.rotate(Angle::from_radians(angle));
                let delta = target - self.particles[index].pos;
                self.particles[index].spring(delta);
            }
        }

        if self.time.elapsed() > std::time::Duration::from_secs(30) {
            self.alive = false;
        }
    }
}

// * ------------------------------------- World ------------------------------------ * //
#[derive(Default)]
pub struct World {
    pub plushies: Vec<PlushieInstance>,
}

impl World {
    pub fn new() -> Self {
        Self {
            plushies: Vec::new(),
        }
    }

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
        let iterations = 1;
        for _ in 0..iterations {
            let colliders = self
                .plushies
                .iter()
                .enumerate()
                .map(|(index, plushie)| {
                    let min = plushie.particles.iter().fold(bounds * 2.0, |tl, particle| {
                        vec2(tl.x.min(particle.pos.x), tl.y.min(particle.pos.y))
                    });
                    let max = plushie
                        .particles
                        .iter()
                        .fold(-bounds * 2.0, |br, particle| {
                            vec2(br.x.max(particle.pos.x), br.y.max(particle.pos.y))
                        });
                    (index, Aabb2 { min, max })
                })
                .collect_vec();
            for (index, plushie) in self.plushies.iter_mut().enumerate() {
                plushie.update(index, dt / iterations as f64, bounds, &colliders);
            }
        }
        self.plushies.retain(|plushie| plushie.alive);
    }
}
