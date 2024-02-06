use super::*;

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
        dt: f64,
        scale: f32,
        bounds: vec2<f32>,
        // colliders: impl Iterator<Item = ()>,
    ) -> bool {
        self.acc += vec2(0.0, -1500.0);
        self.vel += self.acc * dt as f32;

        let motion = self.vel * dt as f32 * scale;
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
        true
    }

    pub fn add_force(&mut self, force: vec2<f32>) {
        self.acc += force;
    }

    pub fn spring(&mut self, delta: vec2<f32>) {
        let spring_k = 21000.0;
        let damp_k = 0.4;
        let force = delta.map(|x| x.abs().powf(1.0 / 3.0) * x.signum());
        let force = force * spring_k - self.vel * damp_k;
        self.add_force(force);
    }
}

pub struct PlushieInstance {
    pub name: String,
    pub scale: f32,
    pub time: std::time::Instant,
    pub alive: bool,
    pub particles: Vec<Particle>,
    pub shape: Vec<vec2<f32>>,
    pub triangles: Vec<[usize; 3]>,
}

impl PlushieInstance {
    pub fn new(name: String, offset: vec2<f32>, vel: vec2<f32>, proto: &Plushie) -> Self {
        let shape = proto
            .structure
            .points
            .iter()
            .map(|&point| {
                let point = point.map(|x| x as f32);
                vec2(point.x, proto.image.size().y as f32 - point.y) * proto.config.scale
            })
            .collect::<Vec<_>>();
        let particles = shape
            .iter()
            .map(|&point| {
                Particle::new(offset + point, vel, {
                    point / proto.config.scale / proto.image.size().map(|x| x as f32)
                })
            })
            .collect::<Vec<_>>();
        let triangles = proto.structure.triangles.clone();

        Self {
            name,
            scale: proto.config.scale,
            time: std::time::Instant::now(),
            alive: true,
            particles,
            shape,
            triangles,
        }
    }

    pub fn update(&mut self, dt: f64, bounds: vec2<f32>) {
        self.particles.par_iter_mut().for_each(|particle| {
            particle.update(
                dt, self.scale, bounds,
                // colliders
            );
        });

        for triangle in &self.triangles {
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
                self.particles[index].spring(delta / self.scale);
            }
        }

        if self.time.elapsed() > std::time::Duration::from_secs(30) {
            self.alive = false;
        }
    }

    fn draw(&self, state: &State, framebuffer: &mut ugli::Framebuffer<'_>) {
        if let Some(proto) = state.assets.get().plushies.get(&self.name) {
            state.geng.draw2d().draw2d(
                framebuffer,
                &geng::PixelPerfectCamera,
                &geng::draw2d::TexturedPolygon::with_mode(
                    self.triangles
                        .iter()
                        .flatten()
                        .map(|&index| {
                            let particle = &self.particles[index];
                            draw2d::TexturedVertex {
                                a_pos: particle.pos,
                                a_color: Rgba::WHITE,
                                a_vt: particle.uv,
                            }
                        })
                        .collect(),
                    &proto.image,
                    ugli::DrawMode::Triangles,
                ),
            );
        }
        // for particle in &self.particles {
        //     state.geng.draw2d().circle(
        //         framebuffer,
        //         &geng::PixelPerfectCamera,
        //         particle.pos,
        //         5.0,
        //         Rgba::RED,
        //     );
        // }
    }
}

#[derive(Default)]
pub struct World {
    pub plushies: Vec<PlushieInstance>,
}

impl World {
    pub fn update(&mut self, delta_time: f64, bounds: vec2<f32>) {
        let iterations = 20;
        for _ in 0..iterations {
            self.plushies.par_iter_mut().for_each(|plushie| {
                plushie.update(delta_time / iterations as f64, bounds);
            });
        }
        self.plushies.retain(|plushie| plushie.alive);
    }

    pub fn draw(&self, state: &State, framebuffer: &mut ugli::Framebuffer) {
        for plushie in &self.plushies {
            plushie.draw(state, framebuffer);
        }
    }
}
