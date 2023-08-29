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
            self.load(graphics)
        }

        let mut space = OVERLAY_SPACE.lock().unwrap();
        let delta_time = self.last_frame.elapsed().as_secs_f32();
        self.last_frame = Instant::now();

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
            "Ferris".to_owned() => load_plushie!("Ferris"),
            "C++".to_owned() => load_plushie!("C++"),
            "C".to_owned() => load_plushie!("C"),
            "NixOS".to_owned() => load_plushie!("NixOS"),
            "Manjaro".to_owned() => load_plushie!("Manjaro"),
            "VSCode".to_owned() => load_plushie!("VSCode"),
            "GitHub".to_owned() => load_plushie!("GitHub"),
            "Helix".to_owned() => load_plushie!("Helix"),
            "NVim".to_owned() => load_plushie!("NVim"),
            "Bash".to_owned() => load_plushie!("Bash"),
            "Twitch".to_owned() => load_plushie!("Twitch"),
            "Alan".to_owned() => load_plushie!("Bear"),
        }; // * !party; !plushie Ferris; !plushie C++; !plushie C; !plushie NixOS; !plushie Manjaro; !plushie VSCode; !plushie GitHub; !plushie Helix; !plushie NVim; !plushie Bash; !plushie Twitch
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
