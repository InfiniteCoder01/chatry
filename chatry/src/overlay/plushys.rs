use geng::prelude::{itertools::Itertools, *};

// * !plushy alan; !plushy badcop; !plushy bash; !plushy c; !plushy cpp; !plushy ferris; !plushy github; !plushy helix; !plushy kuviman; !plushy manjaro; !plushy nixos; !plushy nvim; !plushy pinmode; !plushy programmer_jeff; !plushy twitch; !plushy vscode
#[derive(geng::asset::Load)]
pub struct Plushys {
    pub alan: Plushy,
    pub badcop: Plushy,
    pub bash: Plushy,
    pub c: Plushy,
    pub cpp: Plushy,
    pub ferris: Plushy,
    pub github: Plushy,
    pub helix: Plushy,
    pub kuviman: Plushy,
    pub manjaro: Plushy,
    pub nixos: Plushy,
    pub nvim: Plushy,
    pub pinmode: Plushy,
    pub programmer_jeff: Plushy,
    pub twitch: Plushy,
    pub vscode: Plushy,
}

impl Plushys {
    pub fn get(&self, name: &str) -> Option<&Plushy> {
        match name {
            "alan" => Some(&self.alan),
            "badcop" => Some(&self.badcop),
            "bash" => Some(&self.bash),
            "c" => Some(&self.c),
            "c++" | "cpp" => Some(&self.cpp),
            "ferris" => Some(&self.ferris),
            "github" => Some(&self.github),
            "helix" => Some(&self.helix),
            "kuviman" => Some(&self.kuviman),
            "manjaro" => Some(&self.manjaro),
            "nixos" => Some(&self.nixos),
            "nvim" => Some(&self.nvim),
            "pinmode" => Some(&self.pinmode),
            "programmer_jeff_" | "programmer_jeff" | "programmerjeff" => {
                Some(&self.programmer_jeff)
            }
            "twitch" => Some(&self.twitch),
            "vscode" => Some(&self.vscode),
            _ => None,
        }
    }
}

// * ------------------------------- Single - Resource ------------------------------ * //
#[derive(geng::asset::Load)]
pub struct Plushy {
    pub image: ugli::Texture,
    pub structure: PlushyStructure,
}

impl Plushy {
    pub fn instance(
        &self,
        name: String,
        pos: vec2<f32>,
        vel: vec2<f32>,
        scale: f32,
    ) -> PlushyInstance {
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

        let mut instance = PlushyInstance::new(
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
pub struct PlushyStructure {
    points: Vec<vec2<i32>>,
}

impl geng::asset::Load for PlushyStructure {
    type Options = ();
    fn load(
        _manager: &geng::asset::Manager,
        path: &std::path::Path,
        _options: &Self::Options,
    ) -> geng::asset::Future<Self> {
        let path = path.to_owned();
        async move {
            ron::from_str(&file::load_string(&path).await?)
                .map_err(|err| anyhow!("failed to load plushy structure: {err}"))
        }
        .boxed_local()
    }

    const DEFAULT_EXT: Option<&'static str> = Some("ron");
}

fn _pixelate(plushy: &mut Plushy) {
    plushy.image.set_filter(ugli::Filter::Nearest);
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

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
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
    }

    pub fn add_force(&mut self, force: vec2<f32>) {
        self.acc += force;
    }
}

pub struct PlushyInstance {
    pub name: String,
    pub time: std::time::Instant,
    pub particles: Vec<Particle>,
    pub shape: Vec<vec2<f32>>,
    pub triangles: Vec<[usize; 3]>,
}

impl PlushyInstance {
    pub fn new(name: String, particles: Vec<Particle>, shape: Vec<vec2<f32>>) -> Self {
        Self {
            name,
            time: std::time::Instant::now(),
            particles,
            shape,
            triangles: Vec::new(),
        }
    }

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
        for particle in &mut self.particles {
            particle.update(dt, bounds);
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
            let spring_k = 2000.0;
            let damp_k = 0.8;
            for (&index, &point) in std::iter::zip(triangle, &shape) {
                let target = center + point.rotate(Angle::from_radians(angle));
                let delta = target - self.particles[index].pos;
                let force = delta.map(|x| x.abs().powf(1.0 / 3.0) * x.signum());
                let force = force * spring_k - self.particles[index].vel * damp_k;
                self.particles[index].add_force(force);
            }
        }
    }
}

// * ------------------------------------- World ------------------------------------ * //
#[derive(Default)]
pub struct World {
    pub plushys: Vec<PlushyInstance>,
}

impl World {
    pub fn new() -> Self {
        Self {
            plushys: Vec::new(),
        }
    }

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
        let iterations = 1;
        for _ in 0..iterations {
            for plushy in &mut self.plushys {
                plushy.update(dt / iterations as f64, bounds);
            }
        }
        self.plushys
            .retain(|plushy| plushy.time.elapsed() < std::time::Duration::from_secs(30));
    }
}
