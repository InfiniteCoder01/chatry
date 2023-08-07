use crate::config::*;
use glium::{glutin::surface::WindowSurface, Display, Surface};

pub struct Texture {
    size: (u32, u32),
    texture: glium::texture::SrgbTexture2d,
}

impl Texture {
    pub fn load(display: &Display<WindowSurface>, bytes: &[u8]) -> Result<Self> {
        let image = image::load(std::io::Cursor::new(&bytes), image::ImageFormat::Png)?.to_rgba8();
        let size = image.dimensions();
        let image = glium::texture::RawImage2d::from_raw_rgba_reversed(&image.into_raw(), size);
        let texture = glium::texture::SrgbTexture2d::new(display, image)?;
        Ok(Self { size, texture })
    }

    pub fn size(&self) -> Vec2<u32> {
        self.size.into()
    }
}

pub struct GraphicsObject {
    vertex_buffer: glium::VertexBuffer<Vertex>,
    indices: glium::index::NoIndices,
}

impl GraphicsObject {
    pub fn new(display: &Display<WindowSurface>) -> Result<Self> {
        let shape = vec![
            Vertex {
                vertex: [0.0, 0.0],
                uv: [0.0, 0.0],
            },
            Vertex {
                vertex: [1.0, 0.0],
                uv: [1.0, 0.0],
            },
            Vertex {
                vertex: [1.0, 1.0],
                uv: [1.0, 1.0],
            },
            Vertex {
                vertex: [0.0, 1.0],
                uv: [0.0, 1.0],
            },
        ];
        Ok(Self {
            vertex_buffer: glium::VertexBuffer::immutable(display, &shape)?,
            indices: glium::index::NoIndices(glium::index::PrimitiveType::TriangleFan),
        })
    }

    pub fn draw(
        &self,
        display: &Display<WindowSurface>,
        target: &mut glium::Frame,
        program: &glium::Program,
        texture: &Texture,
        instances: &[Instance],
    ) {
        let size = display.get_framebuffer_dimensions();
        let instance_buffer = glium::vertex::VertexBuffer::immutable(display, instances).unwrap();
        target
            .draw(
                (
                    &self.vertex_buffer,
                    instance_buffer.per_instance().unwrap(),
                ),
                self.indices,
                program,
                &uniform! {
                    image: &texture.texture,
                    object_size: [texture.size.0 as f32, texture.size.1 as f32],
                    screen_size: [size.0 as f32, size.1 as f32],
                },
                &glium::draw_parameters::DrawParameters {
                    blend: glium::Blend::alpha_blending(),
                    ..Default::default()
                },
            )
            .unwrap();
    }
}

#[derive(Clone, Copy)]
struct Vertex {
    vertex: [f32; 2],
    uv: [f32; 2],
}

implement_vertex!(Vertex, vertex, uv);

#[derive(Clone, Copy)]
pub struct Instance {
    pub position: [f32; 2],
}
implement_vertex!(Instance, position);
