use geng::prelude::*;
use plushies::*;
use twitchchat::AsyncRunner;

pub mod bot;
pub mod plushies;

#[derive(geng::asset::Load)]
pub struct Assets {
    pub plushies: Plushies,
}

#[derive(Serialize, Deserialize)]
pub struct Config {
    pub channel: String,
    pub name: String,
    pub admins: Vec<String>,
    pub qotd: String,
}

// * ------------------------------------- State ------------------------------------ * //
pub type Writer = twitchchat::writer::AsyncWriter<twitchchat::writer::MpscWriter>;

#[derive(Clone, Debug)]
pub struct Message {
    pub username: String,
    pub user_color: Rgba<f32>,
    pub text: String,
    pub timeout: std::time::Instant,
}

pub struct State {
    geng: Geng,
    assets: Hot<Assets>,
    size: vec2<usize>,
    world: World,
    config: Config,
    runner: AsyncRunner,
    writer: Writer,

    messages: Vec<Message>,
}

impl State {
    pub fn new(
        geng: &Geng,
        config: Config,
        assets: Hot<Assets>,
        runner: AsyncRunner,
        mut writer: Writer,
    ) -> Self {
        // smol::block_on(async {
        //     writer
        //         .encode(twitchchat::commands::privmsg(&config.channel, "I'm awake!"))
        //         .await
        //         .unwrap();
        // });

        Self {
            geng: geng.clone(),
            assets,
            size: vec2(128, 128),
            world: World::default(),
            config,
            runner,
            writer,

            messages: Vec::new(),
        }
    }
}

impl geng::State for State {
    fn draw(&mut self, framebuffer: &mut ugli::Framebuffer) {
        ugli::clear(framebuffer, Some(Rgba::TRANSPARENT_BLACK), None, None);
        self.size = framebuffer.size();

        // self.geng.draw2d().draw2d(
        //     framebuffer,
        //     &geng::PixelPerfectCamera,
        //     &geng::draw2d::TexturedQuad::unit(&self.assets.get().plushies.ferris.image)
        //         .transform(mat3::translate(vec2(100.0, 100.0)) * mat3::scale_uniform(100.0)),
        // );

        // * World
        for plushie in &self.world.plushies {
            if let Some(proto) = self.assets.get().plushies.get(&plushie.name) {
                self.geng.draw2d().draw2d(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &geng::draw2d::TexturedPolygon::with_mode(
                        plushie
                            .triangles
                            .iter()
                            .flatten()
                            .map(|&index| {
                                let particle = &plushie.particles[index];
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
        }

        // * Chat
        let padding = 10.0;
        let size = 20.0;
        let outline = 2.0 / size;
        let width = 256.0;

        let mut y = framebuffer.size().y as f32 / 4.0;
        y += padding;
        for message in self.messages.iter().rev() {
            let align = vec2(geng::TextAlign::LEFT, geng::TextAlign::TOP);
            let x = framebuffer.size().x as f32 - width - padding;

            if let (Some(full), Some(uname)) = (
                self.geng
                    .default_font()
                    .measure(&format!("{}: {}", message.username, message.text), align),
                self.geng.default_font().measure(&message.username, align),
            ) {
                y += full.height() * size + padding;

                self.geng.default_font().draw_with_outline(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &message.username,
                    align,
                    mat3::translate(vec2(x, y)) * mat3::scale_uniform(size),
                    message.user_color,
                    outline,
                    Rgba::BLACK,
                );
                self.geng.default_font().draw_with_outline(
                    framebuffer,
                    &geng::PixelPerfectCamera,
                    &message.text,
                    align,
                    mat3::translate(vec2(x + uname.width() * size + padding, y))
                        * mat3::scale_uniform(size),
                    Rgba::WHITE,
                    outline,
                    Rgba::BLACK,
                );
            }
        }
    }

    fn update(&mut self, _delta_time: f64) {
        // * Twitch IRC
        if let Some(message) = self.runner.next_message().now_or_never() {
            match message {
                Ok(message) => self.on_message(message),
                Err(err) => log::error!("Failed to recieve a message: {}!", err),
            }
        }

        // * Messages
        self.messages
            .retain(|message| message.timeout.elapsed() < std::time::Duration::from_secs(30));
    }

    fn fixed_update(&mut self, delta_time: f64) {
        self.world.update(delta_time, self.size.map(|x| x as _));
    }

    fn handle_event(&mut self, _event: geng::Event) {
        // if let geng::Event::KeyPress { key } = event {
        //     match key {
        //         geng::Key::ShiftRight => self.world.plushies.push(
        //             self.assets
        //                 .get()
        //                 .plushies
        //                 .ferris
        //                 .instance(vec2(10.0, self.size.y as f32 - 10.0), 0.7),
        //         ),
        //         _ => (),
        //     }
        // }
    }
}
