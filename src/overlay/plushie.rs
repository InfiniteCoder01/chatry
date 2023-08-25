use crate::config::*;

#[derive(Clone, Debug)]
pub(super) struct Particle {
    pub position: Vec2,
    pub velocity: Vec2,
    pub uv: Vec2,
}

impl Particle {
    fn new(position: Vec2, velocity: Vec2, uv: Vec2) -> Self {
        Self {
            position,
            velocity,
            uv,
        }
    }

    fn update(&mut self, delta_time: f32, borders: Vec2) {
        self.velocity.y += delta_time * 1000.0;

        let motion = self.velocity * delta_time;
        self.position += motion;

        if self.position.x < 0.0 || self.position.x > borders.x {
            self.position.x -= motion.x;
            self.velocity.x *= -1.0;
        }
        if self.position.y > borders.y {
            self.position.y -= motion.y;
            self.velocity.y *= -0.8;
            self.velocity.x *= 0.9;
        }
    }
}

pub(super) struct PlushieProto {
    pub(super) image: speedy2d::image::ImageHandle,
    pub(super) structure: PlushieStructure,
}

#[derive(Serialize, Deserialize)]
pub(super) struct PlushieStructure {
    points: Vec<(i32, i32)>,
    springs: Vec<(usize, usize)>,
}

enum PlushieFrame {
    Unitnitialized(Vec2, f32),
    Ininitalized(Vec<Particle>),
}

pub struct Plushie {
    name: String,
    frame: PlushieFrame,
    scale: f32,
    pub time: std::time::Instant,
}

impl Plushie {
    pub fn new(name: &str, scale: f32) -> Self {
        Self {
            name: name.to_owned(),
            frame: PlushieFrame::Unitnitialized(
                Vec2::new(rand::thread_rng().gen_range(-400.0..400.0), 0.0),
                scale * 0.7,
            ),
            scale,
            time: std::time::Instant::now(),
        }
    }

    pub(super) fn update(
        &mut self,
        proto: &PlushieProto,
        screen_size: UVec2,
        delta_time: f32,
    ) -> &Vec<Particle> {
        if let PlushieFrame::Unitnitialized(velocity, scale) = self.frame {
            let position = UVec2::new(
                rand::thread_rng()
                    .gen_range(0..screen_size.x - (proto.image.size().x as f32 * scale) as u32),
                0,
            )
            .into_f32();
            self.frame = PlushieFrame::Ininitalized(
                proto
                    .structure
                    .points
                    .iter()
                    .map(|point| {
                        Particle::new(
                            IVec2::from(point).into_f32() * scale + position,
                            velocity,
                            IVec2::from(point).into_f32() / proto.image.size().into_f32(),
                        )
                    })
                    .collect(),
            )
        }
        let frame = match &mut self.frame {
            PlushieFrame::Ininitalized(frame) => frame,
            _ => panic!("Unreachable"),
        };

        for particle in frame.iter_mut() {
            particle.update(delta_time, screen_size.into_f32());
        }

        for &(index1, index2) in &proto.structure.springs {
            let target_length = (IVec2::from(proto.structure.points[index2])
                - IVec2::from(proto.structure.points[index1]))
            .into_f32()
            .magnitude()
                * self.scale;

            let spring_k = 300.0 / target_length * 170.0;
            let damp_k = 2.0;

            let spring = frame[index2].position - frame[index1].position;
            let spring = spring - spring.normalize().unwrap_or(Vec2::ZERO) * target_length;
            let damp = frame[index2].velocity - frame[index1].velocity;
            let acceleration = spring * spring_k + damp * damp_k;
            frame[index1].velocity += acceleration / 2.0 * delta_time;

            let spring = spring * -1.0;
            let damp = frame[index1].velocity - frame[index2].velocity;
            let acceleration = spring * spring_k + damp * damp_k;
            frame[index2].velocity += acceleration / 2.0 * delta_time;
        }

        frame
    }

    pub fn name(&self) -> &String {
        &self.name
    }
}
