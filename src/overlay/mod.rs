pub mod plushie;
use crate::config::*;
use plushie::*;
use speedy2d::{color::Color, font::*, image::*, window::*, Graphics2D};
use std::{rc::Rc, time::Instant};

struct Overlay {
    plushie_protos: std::collections::HashMap<String, PlushieProto>,
    font: Font,
    bg_font: Font,
    size: UVec2,
    last_frame: std::time::Instant,
    start: std::time::Instant,
    count: u32,
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

    let font = Font::new(include_bytes!("../../Assets/Roobert+NotoEmoji.ttf"))
        .map_err(|err| anyhow!(err.to_string()))?;
    let bg_font = Font::new(include_bytes!("../../Assets/FontOutlinedBG.ttf"))
        .map_err(|err| anyhow!(err.to_string()))?;

    window.run_loop(Overlay {
        plushie_protos: std::collections::HashMap::new(),
        font,
        bg_font,
        size: UVec2::ZERO,
        last_frame: std::time::Instant::now(),
        start: std::time::Instant::now(),
        count: 0,
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
        let sequence = [
            "1", "", "2", "3", "4", "5", "", "6", "7", "8", "9", "10", "3", "11", "12", "13", "",
            "14", "3", "9", "15", "10", "16", "17",
        ];

        graphics.clear_screen(Color::TRANSPARENT);

        if self.plushie_protos.is_empty() {
            self.load(graphics)
        }

        let mut space = OVERLAY_SPACE.lock().unwrap();
        let delta_time = self.last_frame.elapsed().as_secs_f32();
        self.last_frame = Instant::now();

        if self.start.elapsed().as_secs_f32() - 5.0 > self.count as f32
            && self.count < sequence.len() as u32
        {
            if !sequence[self.count as usize].is_empty() {
                space.plushies.push(Plushie::new(
                    sequence[self.count as usize],
                    Vec2::new(30.0 + self.count as f32 * 65.0, 10.0),
                    0.45,
                ));
            }
            self.count += 1;
        }

        for plushie in &mut space.plushies {
            let proto = &self.plushie_protos[plushie.name()];
            let frame = plushie.update(proto, self.size, delta_time);

            if let Some(triangulation) = triangulation::Delaunay::new(
                &frame
                    .iter()
                    .map(|point| triangulation::Point::new(point.position.x, point.position.y))
                    .collect::<Vec<_>>(),
            ) {
                for triangle in (0..triangulation.dcel.num_triangles())
                    .map(|index| triangulation.dcel.triangle_points(index * 3))
                {
                    let (particle0, particle1, particle2) = (
                        &frame[triangle[0]],
                        &frame[triangle[1]],
                        &frame[triangle[2]],
                    );
                    graphics.draw_triangle_image_tinted_three_color(
                        [particle0.position, particle1.position, particle2.position],
                        [Color::WHITE, Color::WHITE, Color::WHITE],
                        [particle0.uv, particle1.uv, particle2.uv],
                        &proto.image,
                    );
                }
            }
        }
        // space
        //     .plushies
        //     .retain(|plushie| plushie.time.elapsed().as_secs_f32() < 10.0);

        self.draw_chat(&mut space, graphics);
        self.draw_rect(graphics, IVec2::new(0, 0), self.size, 4.0, Color::RED);
        self.overlay_text(graphics, IVec2::new(10, 10), "Overlay is active 🖥️", 24.0);
        helper.request_redraw();
    }
}

// * ------------------------------------- Utils ------------------------------------ * //
impl Overlay {
    fn load(&mut self, graphics: &mut Graphics2D) {
        macro_rules! load_plushie {
            ($name: literal) => {
                PlushieProto {
                    image: graphics
                        .create_image_from_file_bytes(
                            Some(ImageFileFormat::PNG),
                            ImageSmoothingMode::Linear,
                            std::io::Cursor::new(include_bytes!(concat!(
                                "../../Assets/Plushies/",
                                $name,
                                ".png"
                            ))),
                        )
                        .unwrap(),
                    structure: ron::from_str(include_str!(concat!(
                        "../../Assets/Plushies/",
                        $name,
                        ".ron"
                    )))
                    .unwrap(),
                }
            };
        }

        self.plushie_protos = hash_map! {
            String::from("1") => load_plushie!("Birthday/1"),
            String::from("2") => load_plushie!("Birthday/2"),
            String::from("3") => load_plushie!("Birthday/3"),
            String::from("4") => load_plushie!("Birthday/4"),
            String::from("5") => load_plushie!("Birthday/5"),
            String::from("6") => load_plushie!("Birthday/6"),
            String::from("7") => load_plushie!("Birthday/7"),
            String::from("8") => load_plushie!("Birthday/8"),
            String::from("9") => load_plushie!("Birthday/9"),
            String::from("10") => load_plushie!("Birthday/10"),
            String::from("11") => load_plushie!("Birthday/11"),
            String::from("12") => load_plushie!("Birthday/12"),
            String::from("13") => load_plushie!("Birthday/13"),
            String::from("14") => load_plushie!("Birthday/14"),
            String::from("15") => load_plushie!("Birthday/15"),
            String::from("16") => load_plushie!("Birthday/16"),
            String::from("17") => load_plushie!("Birthday/17"),
        };
    }

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
