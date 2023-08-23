use crate::config::*;
use speedy2d::{color::Color, font::*, image::*, window::*, Graphics2D};
use std::{rc::Rc, time::Instant};

struct Overlay {
    plushie_protos: std::collections::HashMap<String, PlushieProto>,
    font: Font,
    bg_font: Font,
    size: UVec2,
    last_frame: std::time::Instant,
}

struct PlushieProto {
    image: speedy2d::image::ImageHandle,
    structure: PlushieStructure,
}

#[derive(Serialize, Deserialize)]
struct PlushieStructure {
    points: Vec<(i32, i32)>,
    #[serde(skip)]
    springs: Vec<(usize, usize)>,
}

// * ------------------------------------ Handler ----------------------------------- * //
pub fn run_overlay() -> Result<()> {
    let window = speedy2d::Window::new_with_options(
        "Chatry Overlay",
        WindowCreationOptions::new_windowed(WindowSize::MarginPhysicalPixels(90), None)
            .with_always_on_top(true)
            .with_decorations(false)
            .with_mouse_passthrough(true)
            .with_transparent(true),
    )
    .map_err(|err| anyhow!(err.to_string()))?;

    let font = Font::new(include_bytes!("../Assets/Roobert+NotoEmoji.ttf"))
        .map_err(|err| anyhow!(err.to_string()))?;
    let bg_font = Font::new(include_bytes!("../Assets/FontOutlinedBG.ttf"))
        .map_err(|err| anyhow!(err.to_string()))?;

    window.run_loop(Overlay {
        plushie_protos: std::collections::HashMap::new(),
        font,
        bg_font,
        size: UVec2::ZERO,
        last_frame: std::time::Instant::now(),
    });
}

impl WindowHandler for Overlay {
    fn on_start(&mut self, _helper: &mut WindowHelper<()>, info: WindowStartupInfo) {
        self.size = *info.viewport_size_pixels();
    }

    fn on_resize(&mut self, _helper: &mut WindowHelper<()>, size_pixels: UVec2) {
        self.size = size_pixels;
    }

    fn on_draw(&mut self, helper: &mut WindowHelper, graphics: &mut Graphics2D) {
        // * ------------------------------------ OnDraw ------------------------------------ * //
        graphics.clear_screen(Color::TRANSPARENT);

        if self.plushie_protos.is_empty() {
            macro_rules! load_plushie {
                ($name: literal) => {
                    PlushieProto {
                        image: graphics
                            .create_image_from_file_bytes(
                                Some(ImageFileFormat::PNG),
                                ImageSmoothingMode::Linear,
                                std::io::Cursor::new(include_bytes!(concat!(
                                    "../Assets/Plushies/",
                                    $name,
                                    ".png"
                                ))),
                            )
                            .unwrap(),
                        structure: {
                            let mut structure: PlushieStructure = ron::from_str(include_str!(
                                concat!("../Assets/Plushies/", $name, ".ron")
                            ))
                            .unwrap();
                            structure.springs.clear();
                            for index1 in 0..structure.points.len() - 1 {
                                for index2 in index1 + 1..structure.points.len() {
                                    structure.springs.push((index1, index2));
                                }
                            }
                            structure
                        },
                    }
                };
            }

            self.plushie_protos = hash_map! {
                "Ferris".to_owned() => load_plushie!("Ferris"),
                "C++".to_owned() => load_plushie!("C++"),
                "C".to_owned() => load_plushie!("C"),
                "NixOS".to_owned() => load_plushie!("NixOS"),
                "Manjaro".to_owned() => load_plushie!("Manjaro"),
                "VSCode".to_owned() => load_plushie!("VSCode"),
            };
        }

        let mut space = OVERLAY_SPACE.lock().unwrap();
        let delta_time = self.last_frame.elapsed().as_secs_f32();
        self.last_frame = Instant::now();

        for plushie in &mut space.plushies {
            let proto = &self.plushie_protos[plushie.name()];
            let frame = plushie.update(proto, self.size, delta_time);

            let particle0 = &frame[0];
            for (index, particle1) in frame[1..frame.len() - 1].iter().enumerate() {
                let particle2 = &frame[index + 2];
                graphics.draw_triangle_image_tinted_three_color(
                    [particle0.position, particle1.position, particle2.position],
                    [Color::WHITE, Color::WHITE, Color::WHITE],
                    [particle0.uv, particle1.uv, particle2.uv],
                    &proto.image,
                );
            }
        }
        space
            .plushies
            .retain(|plushie| plushie.time.elapsed().as_secs_f32() < 10.0);

        self.draw_chat(&mut space, graphics);
        self.draw_rect(graphics, IVec2::new(0, 0), self.size, 4.0, Color::RED);
        self.overlay_text(graphics, IVec2::new(10, 10), "Overlay is active 🖥️", 24.0);
        helper.request_redraw();
    }
}

// * ------------------------------------- Utils ------------------------------------ * //
impl Overlay {
    fn draw_chat(&self, space: &mut OverlaySpace, graphics: &mut Graphics2D) {
        let text_color = Color::WHITE;
        let font_size = 21.0;

        let chat_size = IVec2::new(350, self.size.y as i32 - 120);
        let mut position = IVec2::new(
            self.size.x as i32 - chat_size.x - 20,
            self.size.y as i32 - 80,
        );
        for message in &space.chat {
            let author = format!("{}: ", message.author());
            let author = self.layout_text(&author, font_size, TextOptions::new());
            let text = self.layout_text(
                message.content(),
                font_size,
                TextOptions::new().with_wrap_to_width(
                    chat_size.x as f32 - author.1.size().x,
                    TextAlignment::Left,
                ),
            );

            let message_position = position + IVec2::new_x(author.1.size().x as _);
            self.draw_text(graphics, position, message.author_color(), &author);
            self.draw_text(graphics, message_position, text_color, &text);
            position.y -= text.1.size().y as i32 + 5;
        }
        space.chat.retain(|message| message.since_sent() < 10);
    }

    fn layout_text(
        &self,
        text: &str,
        size: f32,
        options: TextOptions,
    ) -> (Rc<FormattedTextBlock>, Rc<FormattedTextBlock>) {
        (
            self.bg_font.layout_text(text, size, TextOptions::new()),
            self.font.layout_text(text, size, options),
        )
    }

    fn draw_text(
        &self,
        graphics: &mut Graphics2D,
        position: IVec2,
        color: Color,
        text: &(Rc<FormattedTextBlock>, Rc<FormattedTextBlock>),
    ) {
        graphics.draw_text(position.into_f32(), Color::BLACK, &text.0);
        graphics.draw_text(position.into_f32(), color, &text.1);
    }

    fn overlay_text(&self, graphics: &mut Graphics2D, position: IVec2, text: &str, size: f32) {
        self.draw_text(
            graphics,
            position,
            Color::WHITE,
            &self.layout_text(text, size, TextOptions::new()),
        );
    }

    fn draw_rect(
        &self,
        graphics: &mut Graphics2D,
        position: IVec2,
        size: UVec2,
        thickness: f32,
        color: Color,
    ) {
        graphics.draw_line(
            position.into_f32(),
            position.into_f32() + Vector2::new(size.x, 0).into_f32(),
            thickness,
            color,
        );
        graphics.draw_line(
            position.into_f32() + Vector2::new(size.x, 0).into_f32(),
            position.into_f32() + Vector2::new(size.x, size.y).into_f32(),
            thickness,
            color,
        );
        graphics.draw_line(
            position.into_f32() + Vector2::new(size.x, size.y).into_f32(),
            position.into_f32() + Vector2::new(0, size.y).into_f32(),
            thickness,
            color,
        );
        graphics.draw_line(
            position.into_f32() + Vector2::new(0, size.y).into_f32(),
            position.into_f32(),
            thickness,
            color,
        );
    }
}

// * ------------------------------------ Plushie ----------------------------------- * //
#[derive(Clone, Debug)]
struct Particle {
    position: Vec2,
    velocity: Vec2,
    uv: Vec2,
}

impl Particle {
    pub fn new(position: Vec2, velocity: Vec2, uv: Vec2) -> Self {
        Self {
            position,
            velocity,
            uv,
        }
    }

    pub fn update(&mut self, delta_time: f32, borders: Vec2) {
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
                scale * 0.1,
            ),
            scale,
            time: std::time::Instant::now(),
        }
    }

    fn update(
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
            let spring_k = 300.0; // 100.0
            let damp_k = 2.0; // 1.0

            let target_length = (IVec2::from(proto.structure.points[index2])
                - IVec2::from(proto.structure.points[index1]))
            .into_f32()
            .magnitude()
                * self.scale;
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
