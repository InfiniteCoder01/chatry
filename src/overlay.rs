use std::collections::HashMap;
use std::time::Instant;

use crate::config::*;
use crate::gl::*;
use glium::{glutin::surface::WindowSurface, Display, Surface};
use glium_glyph::{glyph_brush::ab_glyph::FontRef, GlyphBrushBuilder};
use map_macro::*;
use winit::{event_loop::EventLoop, window::Window};

pub struct Overlay {
    window: Window,
    display: Display<WindowSurface>,
    event_loop: EventLoop<()>,
    program: glium::Program,
    textures: HashMap<String, Texture>,
    image_object: GraphicsObject,
    glyph_brush: glium_glyph::GlyphBrush<'static, FontRef<'static>>,
}

pub fn create_overlay() -> Result<Overlay> {
    // * Platform Dependent:
    use winit::platform::wayland::EventLoopBuilderExtWayland;
    let event_loop = winit::event_loop::EventLoopBuilder::new()
        .with_any_thread(true)
        .build();
    let (window, display) = glium::backend::glutin::SimpleWindowBuilder::new()
        .window_builder(
            winit::window::WindowBuilder::new()
                .with_title("Chatry Overlay")
                .with_decorations(false)
                .with_transparent(true)
                .with_fullscreen(Some(winit::window::Fullscreen::Borderless(None)))
                .with_window_level(winit::window::WindowLevel::AlwaysOnTop),
        )
        .build(&event_loop);
    window.set_cursor_hittest(false)?;

    let program = glium::Program::from_source(
        &display,
        include_str!("shaders/vert.glsl"),
        include_str!("shaders/frag.glsl"),
        None,
    )?;

    let font = FontRef::try_from_slice(include_bytes!("../Assets/Roobert+NotoEmoji.ttf")).unwrap();
    let bg_font = FontRef::try_from_slice(include_bytes!("../Assets/FontOutlinedBG.ttf")).unwrap();
    let textures = hash_map! {
        "Ferris".to_owned() => Texture::load(&display, include_bytes!("../Assets/Ferris.png"))?,
    };

    let image_object = GraphicsObject::new(&display)?;
    let mut glyph_brush = GlyphBrushBuilder::using_font(font);
    glyph_brush.add_font(bg_font);
    let glyph_brush = glyph_brush.build(&display);
    Ok(Overlay {
        window,
        display,
        event_loop,
        program,
        textures,
        image_object,
        glyph_brush,
    })
}

pub fn run_overlay(mut overlay: Overlay) {
    let mut last_frame = Instant::now();
    overlay.event_loop.run(move |ev, _, control_flow| {
        let mut space = OVERLAY_SPACE.lock().unwrap();
        match ev {
            winit::event::Event::WindowEvent { event, .. } => match event {
                winit::event::WindowEvent::CloseRequested => {
                    *control_flow = winit::event_loop::ControlFlow::Exit;
                }
                winit::event::WindowEvent::Resized(size) => {
                    overlay.display.resize((size.width, size.height))
                }
                _ => (),
            },
            winit::event::Event::RedrawRequested(_) => {
                let mut target = overlay.display.draw();
                let delta_time = last_frame.elapsed().as_secs_f32();
                last_frame = Instant::now();
                let mut image_objects = HashMap::<String, Vec<Instance>>::new();

                update(
                    &mut space,
                    &overlay.textures,
                    overlay.display.get_framebuffer_dimensions().into(),
                    delta_time,
                    &mut overlay.glyph_brush,
                    &mut image_objects,
                );

                target.clear_color(0.0, 0.0, 0.0, 0.0);
                for (texture, instances) in image_objects {
                    overlay.image_object.draw(
                        &overlay.display,
                        &mut target,
                        &overlay.program,
                        &overlay.textures[&texture],
                        &instances,
                    );
                }
                overlay
                    .glyph_brush
                    .draw_queued(&overlay.display, &mut target);
                target.finish().unwrap();
                overlay.window.request_redraw();
            }
            _ => (),
        }
    });
}

fn update(
    space: &mut OverlaySpace,
    textures: &HashMap<String, Texture>,
    screen_size: Vec2<u32>,
    delta_time: f32,
    glyph_brush: &mut glium_glyph::GlyphBrush<'_, FontRef<'_>>,
    image_objects: &mut HashMap<String, Vec<Instance>>,
) {
    for plushie in &mut space.plushies {
        plushie.velocity.y -= delta_time * 1000.0;

        let motion = plushie.velocity * delta_time;
        plushie.position += motion;

        if plushie.position.x < 0.0
            || plushie.position.x as u32 + textures[plushie.name()].size().x > screen_size.x
        {
            plushie.position.x -= motion.x;
            plushie.velocity.x *= -1.0;
        }
        if plushie.position.y < 0.0 {
            plushie.position.y -= motion.y;
            plushie.velocity.y *= -0.8;
        }

        image_objects
            .entry(plushie.name().clone())
            .or_default()
            .push(Instance {
                position: plushie.position.into(),
            });
    }
    space
        .plushies
        .retain(|plushie| !(plushie.position.y < 10.0 && plushie.velocity.y.abs() < 10.0));

    draw_chat_overlay(space, screen_size, glyph_brush);
}

fn draw_chat_overlay(
    space: &mut OverlaySpace,
    screen_size: Vec2<u32>,
    glyph_brush: &mut glium_glyph::GlyphBrush<'_, FontRef<'_>>,
) {
    let chat_size = Vec2::new(350, screen_size.y - 120);
    let chat_position = Vec2::new(screen_size.x - chat_size.x - 20, 80);
    let author_font_size = 22.0;
    let font_size = 18.0;
    let text_color = [1.0, 1.0, 1.0, 1.0];
    let background_color = [0.0, 0.0, 0.0, 1.0];

    let mut chat_text = glium_glyph::glyph_brush::Section::default();
    for message in &space.chat {
        chat_text = chat_text.add_text(
            glium_glyph::glyph_brush::Text::new(" ")
                .with_scale(font_size)
                .with_color(text_color),
        );
        chat_text = chat_text.add_text(
            glium_glyph::glyph_brush::Text::new(message.author())
                .with_scale(author_font_size)
                .with_color(message.username_color()),
        );
        chat_text = chat_text.add_text(
            glium_glyph::glyph_brush::Text::new(" ")
                .with_scale(font_size)
                .with_color(text_color),
        );
        chat_text = chat_text.add_text(
            glium_glyph::glyph_brush::Text::new(message.content())
                .with_scale(font_size)
                .with_color(text_color),
        );
        chat_text = chat_text.add_text(
            glium_glyph::glyph_brush::Text::new("\n")
                .with_scale(font_size)
                .with_color(text_color),
        );
    }

    // * Draw text
    chat_text = chat_text
        .with_bounds(chat_size.casted::<Vec2<f32>>())
        .with_screen_position((
            chat_position.x as f32,
            screen_size.y as f32 - chat_position.y as f32,
        ))
        .with_layout(
            glium_glyph::glyph_brush::Layout::default_wrap()
                .v_align(glium_glyph::glyph_brush::VerticalAlign::Bottom),
        );
    let text_fg = chat_text.clone();
    for text in &mut chat_text.text {
        text.font_id.0 += 1;
        text.extra.color = background_color;
    }
    glyph_brush.queue(chat_text);
    glyph_brush.queue(text_fg);
    space.chat.retain(|message| message.since_sent() < 10);
}
