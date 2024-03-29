use bidivec::*;
use raylib::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Default)]
struct PlushieStructure {
    points: Vec<(i32, i32)>,
    triangles: Vec<[usize; 3]>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
enum Point {
    #[default]
    Blank,
    Edge((i32, i32)),
    Fill,
}

fn main() {
    set_trace_log(TraceLogLevel::LOG_ERROR);
    let (mut rl, thread) = raylib::init().size(640, 480).title("PlushieEdit").build();

    let (grid, point_size) = (16, 8.0);
    let (nogui, path, step) = {
        let mut args = std::env::args().collect::<Vec<_>>();
        let nogui = if args.get(1) == Some(&"nogui".to_owned()) {
            args.remove(1);
            true
        } else {
            false
        };
        if args.len() < 2 || args.len() > 3 {
            panic!("Usage: plushiedit [nogui] PATH [step]");
        }
        (
            nogui,
            std::path::PathBuf::from(&args[1]),
            args.get(2)
                .map_or(Some(32), |step| step.parse::<usize>().ok())
                .expect("Step should be a number"),
        )
    };

    let scale = 1.5;
    let max_distance = step as f32 * 2.0;

    let image_path = path.join("image.png");
    let structure_path = path.join("structure.ron");

    let image = rl
        .load_texture(&thread, &image_path.to_string_lossy())
        .expect("Couldn't load image");
    rl.set_window_size(
        (image.width() as f32 * scale) as _,
        (image.height() as f32 * scale) as _,
    );

    let image_data = image.load_image().unwrap().get_image_data();
    let mut map = bidivec![Point::Blank; (image.width as usize).div_ceil(step) + 1, (image.height as usize).div_ceil(step) + 1];

    let pixel = |x: i32, y: i32| {
        if x < 0 || y < 0 || x >= image.width || y >= image.height {
            return false;
        }
        image_data[x as usize + y as usize * image.width as usize].a > 30
    };

    let segment = |x: usize, y: usize| {
        let size = step / 2;
        #[allow(clippy::option_map_unit_fn)]
        (-(size as i32) / 2..size as i32 / 2).any(|y1| {
            (-(size as i32) / 2..size as i32 / 2)
                .any(|x1| pixel(x as i32 * step as i32 + x1, y as i32 * step as i32 + y1))
        })
    };

    let trim = |point: Vector2, direction: Vector2| {
        let mut p = point * rvec2(step as i32, step as i32);
        for _ in 0..step {
            if pixel(p.x as _, p.y as _) {
                break;
            }
            p -= direction;
        }
        return (p.x as i32, p.y as i32);
    };

    for y in 0..map.height() {
        for x in 0..map.width() {
            if segment(x, y) {
                map[(x, y)] = Point::Fill;
            }
        }
    }

    for y in 0..map.height() {
        for x in 0..map.width() {
            if !segment(x, y) {
                if x > 0 && map[(x - 1, y)] == Point::Fill {
                    map[(x, y)] = Point::Edge(trim(rvec2(x as i32, y as i32), rvec2(1, 0)));
                } else if y > 0 && map[(x, y - 1)] == Point::Fill {
                    map[(x, y)] = Point::Edge(trim(rvec2(x as i32, y as i32), rvec2(0, 1)));
                } else if x < map.width() - 1 && map[(x + 1, y)] == Point::Fill {
                    map[(x, y)] = Point::Edge(trim(rvec2(x as i32, y as i32), rvec2(-1, 0)));
                } else if y < map.height() - 1 && map[(x, y + 1)] == Point::Fill {
                    map[(x, y)] = Point::Edge(trim(rvec2(x as i32, y as i32), rvec2(0, -1)));
                }
            }
        }
    }

    let mut structure = PlushieStructure::default();
    let mut triangulation_points = Vec::new();
    for y in 0..map.height() {
        for x in 0..map.width() {
            match map[(x, y)] {
                Point::Blank => (),
                Point::Edge(point) => structure.points.push(point),
                Point::Fill => structure
                    .points
                    .push(((x * step) as i32, (y * step) as i32)),
            }
            match map[(x, y)] {
                Point::Blank => (),
                Point::Edge(_) | Point::Fill => {
                    triangulation_points.push(((x * step) as i32, (y * step) as i32))
                }
            }
        }
    }

    structure.triangles = {
        use rtriangulate::{triangulate, TriangulationPoint};
        let points = triangulation_points
            .iter()
            .map(|point| {
                TriangulationPoint::new(
                    (point.0 as f32 / step as f32).round(),
                    (point.1 as f32 / step as f32).round(),
                )
            })
            .collect::<Vec<_>>();

        triangulate(&points)
            .unwrap()
            .iter()
            .map(|triangle| [triangle.0, triangle.1, triangle.2])
            .filter(|triangle| {
                let triangle = (
                    rvec2(
                        triangulation_points[triangle[0]].0,
                        triangulation_points[triangle[0]].1,
                    ),
                    rvec2(
                        triangulation_points[triangle[1]].0,
                        triangulation_points[triangle[1]].1,
                    ),
                    rvec2(
                        triangulation_points[triangle[2]].0,
                        triangulation_points[triangle[2]].1,
                    ),
                );
                triangle.0.distance_to(triangle.1) < max_distance
                    && triangle.1.distance_to(triangle.2) < max_distance
                    && triangle.2.distance_to(triangle.0) < max_distance
            })
            .collect()
    };

    if nogui {
        std::fs::write(&structure_path, ron::to_string(&structure).unwrap())
            .expect("Failed to write!");
        return;
    }
    while !rl.window_should_close() {
        let ctrl = rl.is_key_down(KeyboardKey::KEY_LEFT_CONTROL);
        let save_key = rl.is_key_down(KeyboardKey::KEY_S);

        let window_size = (rl.get_screen_width(), rl.get_screen_height());
        let mut d = rl.begin_drawing(&thread);
        for y in 0..window_size.1 / grid + 1 {
            for x in 0..window_size.0 / grid + 1 {
                d.draw_rectangle(
                    x * grid,
                    y * grid,
                    grid,
                    grid,
                    if (x + y) % 2 == 0 {
                        Color::WHITE
                    } else {
                        Color::LIGHTSTEELBLUE
                    },
                )
            }
        }
        d.draw_texture_ex(&image, Vector2::zero(), 0.0, scale, Color::WHITE);
        for triangle in &structure.triangles {
            d.draw_triangle_lines(
                rvec2(
                    structure.points[triangle[0]].0,
                    structure.points[triangle[0]].1,
                ) * scale,
                rvec2(
                    structure.points[triangle[1]].0,
                    structure.points[triangle[1]].1,
                ) * scale,
                rvec2(
                    structure.points[triangle[2]].0,
                    structure.points[triangle[2]].1,
                ) * scale,
                Color::BLUE,
            );
        }

        for point in &structure.points {
            d.draw_circle(
                (point.0 as f32 * scale) as _,
                (point.1 as f32 * scale) as _,
                point_size,
                Color::RED,
            );
        }

        if ctrl && save_key {
            std::fs::write(&structure_path, ron::to_string(&structure).unwrap())
                .expect("Failed to write!");
        }
    }
}
