use crate::config::*;
use speedy2d::{color::Color, font::*, image::*, shape::Rectangle, window::*, Graphics2D};
use std::{rc::Rc, time::Instant};

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
        textures: std::collections::HashMap::new(),
        font,
        bg_font,
        size: UVec2::ZERO,
        last_frame: std::time::Instant::now(),
    });
}

struct Overlay {
    textures: std::collections::HashMap<String, speedy2d::image::ImageHandle>,
    font: Font,
    bg_font: Font,
    size: UVec2,
    last_frame: std::time::Instant,
}

impl WindowHandler for Overlay {
    fn on_start(&mut self, _helper: &mut WindowHelper<()>, info: WindowStartupInfo) {
        self.size = *info.viewport_size_pixels();
    }

    fn on_resize(&mut self, _helper: &mut WindowHelper<()>, size_pixels: UVec2) {
        self.size = size_pixels;
    }

    fn on_draw(&mut self, helper: &mut WindowHelper, graphics: &mut Graphics2D) {
        graphics.clear_screen(Color::TRANSPARENT);

        if self.textures.is_empty() {
            macro_rules! load_image {
                ($name: literal) => {
                    graphics
                        .create_image_from_file_bytes(
                            Some(ImageFileFormat::PNG),
                            ImageSmoothingMode::Linear,
                            std::io::Cursor::new(include_bytes!(concat!(
                                "../Assets/",
                                $name,
                                ".png"
                            ))),
                        )
                        .unwrap()
                };
            }

            self.textures = hash_map! {
                "Ferris".to_owned() => load_image!("Ferris"),
            };
        }

        let mut space = OVERLAY_SPACE.lock().unwrap();
        let delta_time = self.last_frame.elapsed().as_secs_f32();
        self.last_frame = Instant::now();

        for plushie in &mut space.plushies {
            let texture = &self.textures[plushie.name()];
            let size = texture.size().into_f32() * plushie.scale;
            plushie.update(delta_time, size, self.size);

            let pivot = Vec2::new(0.5, 1.0);
            let position = plushie.point.position + size * pivot;
            let size = size * Vec2::new(1.0 / plushie.squash, plushie.squash);
            graphics.draw_rectangle_image(
                Rectangle::new(position - size * pivot, position - size * pivot + size),
                texture,
            );
            // self.draw_rect(graphics, plushie.squash_point.clone().unwrap().position.into_i32(), UVec2::new(8, 8), 8.0, Color::RED);
        }
        space.plushies.retain(|plushie| {
            !(plushie.point.position.y as u32 + self.textures[plushie.name()].size().y
                > self.size.y - 10
                && plushie.point.velocity.y.abs() < 10.0)
        });

        self.draw_chat(&mut space, graphics);
        self.draw_rect(graphics, IVec2::new(0, 0), self.size, 4.0, Color::RED);
        self.overlay_text(graphics, IVec2::new(10, 10), "Overlay is active 🖥️", 24.0);
        helper.request_redraw();
    }
}

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
