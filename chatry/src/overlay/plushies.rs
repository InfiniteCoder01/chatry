use geng::prelude::*;

#[derive(geng::asset::Load)]
pub struct Plushies {
    pub ferris: Plushie,
    pub c: Plushie,
    pub cpp: Plushie,
    pub bash: Plushie,
    pub manjaro: Plushie,
}

impl Plushies {
    pub fn get(&self, name: &str) -> Option<&Plushie> {
        match name {
            "ferris" => Some(&self.ferris),
            "c" => Some(&self.c),
            "c++" | "cpp" => Some(&self.cpp),
            "bash" => Some(&self.bash),
            "manjaro" => Some(&self.manjaro),
            _ => None,
        }
    }
}

// * ------------------------------- Single - Resource ------------------------------ * //
#[derive(geng::asset::Load)]
pub struct Plushie {
    pub image: ugli::Texture,
    pub structure: PlushieStructure,
}

impl Plushie {
    pub fn instance(&self, name: String, pos: vec2<f32>, scale: f32) -> PlushieInstance {
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
                        vec2(uv.x, 1.0 - uv.y),
                    )
                })
                .collect::<Vec<_>>(),
        );

        for triangle in tri.triangles().chunks_exact(3) {
            for (i, a_id) in triangle.iter().copied().enumerate() {
                let b_id = triangle[(i + 1) % triangle.len()];
                let (a_id, b_id) = if a_id < b_id {
                    (a_id, b_id)
                } else {
                    (b_id, a_id)
                };
                let particle_a = &instance.particles[a_id];
                let particle_b = &instance.particles[b_id];
                let dist_vec = particle_a.pos - particle_b.pos;
                instance
                    .springs
                    .push(Spring::new(a_id, b_id, dist_vec.len()));
            }
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

fn pixelate(plushie: &mut Plushie) {
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
    pub fn new(pos: vec2<f32>, uv: vec2<f32>) -> Self {
        Self {
            pos,
            vel: vec2(0.0, 0.0),
            acc: vec2(0.0, 0.0),
            uv,
        }
    }

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
        self.add_force(vec2(0.0, -150.0));
        self.vel += self.acc * dt as f32;

        let motion = self.vel * dt as f32;
        self.pos += motion;

        if self.pos.x < 0.0 || self.pos.x > bounds.x {
            self.pos.x = if self.pos.x < 0.0 { 0.0 } else { bounds.x };
            self.vel.x = 0.0;
            // self.vel.y *= 0.99;
        }

        if self.pos.y < 0.0 {
            self.pos.y = 0.0;
            self.vel.y *= -0.8;
            // self.vel.x *= 0.99;
        }

        self.acc = vec2(0.0, 0.0);
    }

    pub fn add_force(&mut self, force: vec2<f32>) {
        self.acc += force;
    }
}

pub struct Spring {
    particle1: usize,
    particle2: usize,
    rest_distance: f32,
}

impl Spring {
    pub fn new(particle1: usize, particle2: usize, rest_distance: f32) -> Self {
        Self {
            particle1,
            particle2,
            rest_distance,
        }
    }

    pub fn update(&mut self, particles: &mut [Particle]) {
        let delta = particles[self.particle2].pos - particles[self.particle1].pos;
        let spring = delta.len();

        let force = spring - self.rest_distance;
        // let force = force.powi(6) * force.signum();

        let spring_force = (delta / spring) * force;

        let spring_k = 25.0e6 / self.rest_distance.powi(2);
        let damp_k = 0.1;

        let damp = particles[self.particle2].vel - particles[self.particle1].vel;
        particles[self.particle1].add_force(spring_force * spring_k + damp * damp_k);

        let spring_force = spring_force * -1.0;
        let damp = particles[self.particle1].vel - particles[self.particle2].vel;
        particles[self.particle2].add_force(spring_force * spring_k + damp * damp_k);
    }
}

pub struct PlushieInstance {
    pub name: String,
    pub particles: Vec<Particle>,
    pub springs: Vec<Spring>,
    pub triangles: Vec<[usize; 3]>,
}

impl PlushieInstance {
    pub fn new(name: String, particles: Vec<Particle>) -> Self {
        Self {
            name,
            particles,
            springs: Vec::new(),
            triangles: Vec::new(),
        }
    }

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
        for particle in &mut self.particles {
            particle.update(dt, bounds);
        }
        for spring in &mut self.springs {
            spring.update(&mut self.particles);
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
        let iterations = 30;
        for _ in 0..iterations {
            for plushie in &mut self.plushies {
                plushie.update(dt / iterations as f64, bounds);
            }
        }
    }
}
